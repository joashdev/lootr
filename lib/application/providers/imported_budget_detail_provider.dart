import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/mappers.dart';
import '../../data/repositories/composite_budget_repo.dart';
import 'accounts_provider.dart';
import 'budget_projection.dart';
import 'budgets_tab_provider.dart';
import 'categories_provider.dart';
import 'repo_providers.dart';

class ImportedBudgetRequest {
  const ImportedBudgetRequest({
    required this.id,
    required this.year,
    required this.month,
  });

  final String id;
  final int year;
  final int month;

  @override
  bool operator ==(Object other) =>
      other is ImportedBudgetRequest &&
      other.id == id &&
      other.year == year &&
      other.month == month;

  @override
  int get hashCode => Object.hash(id, year, month);
}

final importedBudgetDetailProvider =
    StreamProvider.family<BudgetDetailProjection?, ImportedBudgetRequest>((
      ref,
      request,
    ) {
      final repo = ref.watch(compositeBudgetRepoProvider);
      final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
      final categories =
          ref.watch(categoriesProvider).asData?.value ?? const [];
      final accountNames = {for (final row in accounts) row.id: row.name};
      final categoryNames = {for (final row in categories) row.id: row.name};
      return repo
          .watchByIdAt(request.id, DateTime(request.year, request.month))
          .map((snapshot) {
            if (snapshot == null) return null;
            return BudgetDetailProjection(
              overview: compositeBudgetOverview(snapshot),
              transactions: [
                for (final match in snapshot.evaluation.matches)
                  BudgetTransactionProjection(
                    transaction: match.transaction.toEntity(),
                    inclusionReason: _inclusionReason(
                      match,
                      accountNames,
                      categoryNames,
                    ),
                  ),
              ],
              compositeScope: _scopeProjection(
                snapshot.scope,
                accountNames,
                categoryNames,
              ),
              unresolvedMembers: [
                for (final member in snapshot.scope.members)
                  if (member.isUnresolved)
                    UnresolvedBudgetMemberProjection(
                      kind: member.kind,
                      membership: member.membership,
                      sourceReference:
                          member.sourceReference ?? 'Unknown imported member',
                      reviewState: member.reviewState,
                    ),
              ],
              overlaps: [
                for (final overlap in snapshot.overlaps)
                  BudgetOverlapProjection(
                    budgetId: overlap.budgetId,
                    budgetName: overlap.budgetName,
                    sharedTransactionCount: overlap.sharedTransactionCount,
                  ),
              ],
              history: [
                for (final period in snapshot.history)
                  BudgetHistoryProjection(
                    startsAt: period.startsAt,
                    endsAt: period.endsAt,
                  ),
              ],
            );
          });
    });

String _inclusionReason(
  BudgetTransactionMatch match,
  Map<String, String> accountNames,
  Map<String, String> categoryNames,
) {
  final transaction = match.transaction;
  final account = accountNames[transaction.accountId] ?? transaction.accountId;
  final category = transaction.categoryId == null
      ? 'Uncategorized'
      : categoryNames[transaction.categoryId] ?? transaction.categoryId!;
  return switch (match.reason) {
    BudgetInclusionReason.accountAndCategory =>
      'Included because account “$account” and category “$category” are in scope.',
    BudgetInclusionReason.account =>
      'Included because account “$account” is in scope.',
    BudgetInclusionReason.category =>
      'Included because category “$category” is in scope.',
    BudgetInclusionReason.allMatching =>
      'Included because it matches the budget’s complete scope.',
    BudgetInclusionReason.explicitlyAttached =>
      'Included because this transaction is explicitly attached.',
  };
}

CompositeBudgetScopeProjection _scopeProjection(
  CompositeBudgetScope scope,
  Map<String, String> accountNames,
  Map<String, String> categoryNames,
) {
  List<String> members(String kind, String membership) => [
    for (final member in scope.members)
      if (member.kind == kind &&
          member.membership == membership &&
          member.resolvedId != null)
        switch (kind) {
          'account' => accountNames[member.resolvedId] ?? member.resolvedId!,
          'category' => categoryNames[member.resolvedId] ?? member.resolvedId!,
          _ => member.resolvedId!,
        },
  ];
  return CompositeBudgetScopeProjection(
    membershipMode: scope.membershipMode,
    direction: scope.directionFilter,
    periodType: scope.periodType,
    includedAccounts: members('account', 'include'),
    excludedAccounts: members('account', 'exclude'),
    includedCategories: members('category', 'include'),
    excludedCategories: members('category', 'exclude'),
    includedTransactions: members('transaction', 'include'),
    excludedTransactions: members('transaction', 'exclude'),
  );
}

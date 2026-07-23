import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/composite_budget_repo.dart';
import '../../data/repositories/transaction_repo.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/value_objects/exact_money.dart';
import 'repo_providers.dart';

class CompositeBudgetFormDraft {
  const CompositeBudgetFormDraft({
    this.id,
    this.ownerUserId,
    this.householdId,
    required this.name,
    required this.limit,
    required this.periodType,
    required this.directionFilter,
    required this.membershipMode,
    this.periodStart,
    this.periodEnd,
    this.cycleRule,
    this.includedAccountIds = const {},
    this.excludedAccountIds = const {},
    this.includedCategoryIds = const {},
    this.excludedCategoryIds = const {},
    this.includedTransactionIds = const {},
    this.excludedTransactionIds = const {},
  });

  final String? id;
  final String? ownerUserId;
  final String? householdId;
  final String name;
  final ExactMoney limit;
  final String periodType;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String? cycleRule;
  final String directionFilter;
  final String membershipMode;
  final Set<String> includedAccountIds;
  final Set<String> excludedAccountIds;
  final Set<String> includedCategoryIds;
  final Set<String> excludedCategoryIds;
  final Set<String> includedTransactionIds;
  final Set<String> excludedTransactionIds;
}

class CompositeBudgetController {
  CompositeBudgetController(this.ref);

  final Ref ref;

  Future<CompositeBudgetFormDraft?> load(String id) async {
    final draft = await ref.read(compositeBudgetRepoProvider).getDraft(id);
    if (draft == null) return null;
    return CompositeBudgetFormDraft(
      id: draft.id,
      ownerUserId: draft.ownerUserId,
      householdId: draft.householdId,
      name: draft.name,
      limit: draft.limit,
      periodType: draft.periodType,
      periodStart: draft.periodStart,
      periodEnd: draft.periodEnd,
      cycleRule: draft.cycleRule,
      directionFilter: draft.directionFilter,
      membershipMode: draft.membershipMode,
      includedAccountIds: draft.includedAccountIds,
      excludedAccountIds: draft.excludedAccountIds,
      includedCategoryIds: draft.includedCategoryIds,
      excludedCategoryIds: draft.excludedCategoryIds,
      includedTransactionIds: draft.includedTransactionIds,
      excludedTransactionIds: draft.excludedTransactionIds,
    );
  }

  Future<String> save(CompositeBudgetFormDraft form) async {
    final ownerId =
        form.ownerUserId ??
        (await ref.read(userRepoProvider).getCurrentUser())?.id;
    if (ownerId == null) {
      throw StateError('Create a user profile before adding budgets.');
    }
    final id = form.id ?? _newId();
    final draft = CompositeBudgetDraft(
      id: id,
      ownerUserId: ownerId,
      householdId: form.householdId,
      name: form.name,
      limit: form.limit,
      periodType: form.periodType,
      periodStart: form.periodStart,
      periodEnd: form.periodEnd,
      cycleRule: form.cycleRule,
      directionFilter: form.directionFilter,
      membershipMode: form.membershipMode,
      includedAccountIds: form.includedAccountIds,
      excludedAccountIds: form.excludedAccountIds,
      includedCategoryIds: form.includedCategoryIds,
      excludedCategoryIds: form.excludedCategoryIds,
      includedTransactionIds: form.includedTransactionIds,
      excludedTransactionIds: form.excludedTransactionIds,
    );
    final repo = ref.read(compositeBudgetRepoProvider);
    form.id == null ? await repo.create(draft) : await repo.update(draft);
    return id;
  }

  String _newId() {
    final random = Random.secure();
    final suffix = List.generate(
      20,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return 'budget-$suffix';
  }
}

final compositeBudgetControllerProvider = Provider<CompositeBudgetController>(
  CompositeBudgetController.new,
);

/// Transaction choices for composite-budget membership editing.
///
/// This intentionally does not compose with the Transactions tab's period,
/// ledger query, search, or filters. Explicit membership is durable budget
/// state, so the editor must continue to expose members even when the ledger
/// happens to be showing a different slice.
final compositeBudgetTransactionOptionsProvider =
    StreamProvider<List<Transaction>>((ref) {
      final repo = ref.watch(transactionRepoProvider);
      return repo.watchFiltered(const TransactionRepoFilters()).map((rows) {
        final transactions = rows.map((row) => row.toEntity()).toList();
        transactions.sort(
          (left, right) => right.occurredAt.compareTo(left.occurredAt),
        );
        return transactions;
      });
    });

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/mappers.dart';
import 'budget_projection.dart';
import 'budgets_tab_provider.dart';
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
                    inclusionReason: match.reasonLabel,
                  ),
              ],
              compositeReview: snapshot.review,
            );
          });
    });

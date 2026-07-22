import '../../data/repositories/composite_budget_repo.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/value_objects/exact_money.dart';

class BudgetOverview {
  const BudgetOverview({
    required this.id,
    required this.name,
    required this.budgeted,
    required this.spent,
    required this.startsAt,
    required this.endsAt,
    required this.isImported,
    required this.isReadOnly,
    required this.needsReview,
    required this.missingReferenceCount,
    this.categoryId,
    this.legacyBudget,
  });

  final String id;
  final String name;
  final ExactMoney budgeted;
  final ExactMoney spent;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isImported;
  final bool isReadOnly;
  final bool needsReview;
  final int missingReferenceCount;
  final String? categoryId;
  final Budget? legacyBudget;

  String get currencyCode => budgeted.currencyCode;
  double get progress =>
      budgeted.isZero ? 0 : spent.toDouble() / budgeted.toDouble();
  ExactMoney get remaining => budgeted - spent;
}

class BudgetSummaryPartition {
  const BudgetSummaryPartition({
    required this.currencyCode,
    required this.budgeted,
    required this.spent,
  });

  final String currencyCode;
  final ExactMoney budgeted;
  final ExactMoney spent;

  double get progress =>
      budgeted.isZero ? 0 : spent.toDouble() / budgeted.toDouble();
}

class BudgetTransactionProjection {
  const BudgetTransactionProjection({
    required this.transaction,
    required this.inclusionReason,
  });

  final Transaction transaction;
  final String inclusionReason;
}

class BudgetDetailProjection {
  const BudgetDetailProjection({
    required this.overview,
    required this.transactions,
    this.compositeReview,
  });

  final BudgetOverview overview;
  final List<BudgetTransactionProjection> transactions;
  final CompositeBudgetReviewSummary? compositeReview;

  Budget? get editableLegacyBudget => overview.legacyBudget;
}

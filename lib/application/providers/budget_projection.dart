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
    this.isComposite = false,
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
  final bool isComposite;
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
    this.compositeScope,
    this.unresolvedMembers = const [],
    this.overlaps = const [],
    this.history = const [],
  });

  final BudgetOverview overview;
  final List<BudgetTransactionProjection> transactions;
  final CompositeBudgetScopeProjection? compositeScope;
  final List<UnresolvedBudgetMemberProjection> unresolvedMembers;
  final List<BudgetOverlapProjection> overlaps;
  final List<BudgetHistoryProjection> history;

  Budget? get editableLegacyBudget => overview.legacyBudget;
}

class CompositeBudgetScopeProjection {
  const CompositeBudgetScopeProjection({
    required this.membershipMode,
    required this.direction,
    required this.periodType,
    required this.includedAccounts,
    required this.excludedAccounts,
    required this.includedCategories,
    required this.excludedCategories,
    required this.includedTransactions,
    required this.excludedTransactions,
  });

  final String membershipMode;
  final String direction;
  final String periodType;
  final List<String> includedAccounts;
  final List<String> excludedAccounts;
  final List<String> includedCategories;
  final List<String> excludedCategories;
  final List<String> includedTransactions;
  final List<String> excludedTransactions;
}

class UnresolvedBudgetMemberProjection {
  const UnresolvedBudgetMemberProjection({
    required this.kind,
    required this.membership,
    required this.sourceReference,
    required this.reviewState,
  });

  final String kind;
  final String membership;
  final String sourceReference;
  final String reviewState;
}

class BudgetOverlapProjection {
  const BudgetOverlapProjection({
    required this.budgetId,
    required this.budgetName,
    required this.sharedTransactionCount,
  });

  final String budgetId;
  final String budgetName;
  final int sharedTransactionCount;
}

class BudgetHistoryProjection {
  const BudgetHistoryProjection({required this.startsAt, required this.endsAt});

  final DateTime startsAt;
  final DateTime endsAt;
}

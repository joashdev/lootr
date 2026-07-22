import 'package:drift/drift.dart' hide isNull;

import '../../domain/value_objects/exact_money.dart';
import '../database/app_database.dart';
import 'exact_money_codec.dart';

/// A half-open historical interval: [startsAt] is included and [endsAt] is
/// excluded.
class BudgetPeriodWindow {
  const BudgetPeriodWindow({
    required this.startsAt,
    required this.endsAt,
    this.id,
  });

  final String? id;
  final DateTime startsAt;
  final DateTime endsAt;

  bool contains(DateTime value) =>
      !value.isBefore(startsAt) && value.isBefore(endsAt);
}

enum BudgetInclusionReason {
  accountAndCategory,
  account,
  category,
  allMatching,
  explicitlyAttached,
}

class BudgetTransactionMatch {
  const BudgetTransactionMatch({
    required this.transaction,
    required this.amount,
    required this.reason,
  });

  final TransactionData transaction;
  final ExactMoney amount;
  final BudgetInclusionReason reason;

  String get reasonLabel => switch (reason) {
    BudgetInclusionReason.accountAndCategory => 'Included account and category',
    BudgetInclusionReason.account => 'Included account',
    BudgetInclusionReason.category => 'Included category',
    BudgetInclusionReason.allMatching => 'Matches budget scope',
    BudgetInclusionReason.explicitlyAttached => 'Explicitly attached',
  };
}

class CompositeBudgetEvaluation {
  const CompositeBudgetEvaluation({
    required this.budget,
    required this.period,
    required this.limit,
    required this.expenseTotal,
    required this.incomeTotal,
    required this.matches,
  });

  final BudgetDefinitionData budget;
  final BudgetPeriodWindow period;
  final ExactMoney limit;
  final ExactMoney expenseTotal;
  final ExactMoney incomeTotal;
  final List<BudgetTransactionMatch> matches;

  ExactMoney get includedTotal => expenseTotal + incomeTotal;
  ExactMoney get trackedTotal => switch (budget.directionFilter) {
    'expense' => expenseTotal,
    'income' => incomeTotal,
    _ => includedTotal,
  };
  ExactMoney get remaining => limit - includedTotal;
}

class CompositeBudgetReviewSummary {
  const CompositeBudgetReviewSummary({
    required this.accountReferences,
    required this.categoryReferences,
    required this.transactionReferences,
    required this.reviewRequiredCount,
  });

  final int accountReferences;
  final int categoryReferences;
  final int transactionReferences;
  final int reviewRequiredCount;

  int get missingReferenceCount =>
      accountReferences + categoryReferences + transactionReferences;
  bool get needsReview => missingReferenceCount > 0 || reviewRequiredCount > 0;
}

class CompositeBudgetSnapshot {
  const CompositeBudgetSnapshot({
    required this.evaluation,
    required this.review,
  });

  final CompositeBudgetEvaluation evaluation;
  final CompositeBudgetReviewSummary review;
}

/// Query service for V1 composite budgets.
///
/// Membership is evaluated in memory after a bounded database query so the
/// exact coefficient/scale representation remains authoritative throughout.
class CompositeBudgetRepo {
  CompositeBudgetRepo(this._db);

  final AppDatabase _db;

  Future<BudgetDefinitionData?> getById(String id) {
    return (_db.select(_db.budgetDefinitions)
          ..where((row) => row.id.equals(id) & row.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
  }

  /// Watches all definitions whose resolved period contains [anchor].
  ///
  /// The trigger includes every table that can change evaluation or review
  /// state. Imported budgets therefore become visible immediately after the
  /// migration publication transaction commits, never while it is partial.
  Stream<List<CompositeBudgetSnapshot>> watchForPeriod(DateTime anchor) {
    return _changeTrigger().asyncMap((_) async {
      final definitions =
          await (_db.select(_db.budgetDefinitions)
                ..where((row) => row.deletedAt.isNull())
                ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
              .get();
      final snapshots = <CompositeBudgetSnapshot>[];
      for (final definition in definitions) {
        BudgetPeriodWindow period;
        try {
          period = await resolvePeriod(definition.id, anchor);
        } on StateError {
          // An unmaterialized custom cycle has no safe period to display.
          // Its preserved definition remains queryable for migration review.
          continue;
        }
        if (!period.contains(anchor)) continue;
        snapshots.add(
          CompositeBudgetSnapshot(
            evaluation: await evaluate(definition.id, period: period),
            review: await reviewSummary(definition.id),
          ),
        );
      }
      return snapshots;
    });
  }

  Stream<CompositeBudgetSnapshot?> watchByIdAt(
    String budgetId,
    DateTime anchor,
  ) {
    return watchForPeriod(anchor).map((snapshots) {
      for (final snapshot in snapshots) {
        if (snapshot.evaluation.budget.id == budgetId) return snapshot;
      }
      return null;
    });
  }

  Future<CompositeBudgetReviewSummary> reviewSummary(String budgetId) async {
    final results = await Future.wait([
      (_db.select(
        _db.budgetAccountMemberships,
      )..where((row) => row.budgetId.equals(budgetId))).get(),
      (_db.select(
        _db.budgetCategoryMemberships,
      )..where((row) => row.budgetId.equals(budgetId))).get(),
      (_db.select(
        _db.budgetTransactionMemberships,
      )..where((row) => row.budgetId.equals(budgetId))).get(),
    ]);
    final accounts = results[0] as List<BudgetAccountMembershipData>;
    final categories = results[1] as List<BudgetCategoryMembershipData>;
    final transactions = results[2] as List<BudgetTransactionMembershipData>;
    return CompositeBudgetReviewSummary(
      accountReferences: accounts
          .where((row) => row.sourceReference != null && row.accountId == null)
          .length,
      categoryReferences: categories
          .where((row) => row.sourceReference != null && row.categoryId == null)
          .length,
      transactionReferences: transactions
          .where(
            (row) => row.sourceReference != null && row.transactionId == null,
          )
          .length,
      reviewRequiredCount: [
        ...accounts.map((row) => row.reviewState),
        ...categories.map((row) => row.reviewState),
        ...transactions.map((row) => row.reviewState),
      ].where((state) => state != 'ready').length,
    );
  }

  Stream<int> _changeTrigger() {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _db.budgetDefinitions,
            _db.budgetPeriods,
            _db.budgetAccountMemberships,
            _db.budgetCategoryMemberships,
            _db.budgetTransactionMemberships,
            _db.transactions,
            _db.accounts,
          },
        )
        .watch()
        .map((_) => 1);
  }

  Future<List<BudgetPeriodWindow>> listHistoricalPeriods(
    String budgetId,
  ) async {
    final budget = await _requireBudget(budgetId);
    final materialized =
        await (_db.select(_db.budgetPeriods)
              ..where((row) => row.budgetId.equals(budgetId))
              ..orderBy([(row) => OrderingTerm.desc(row.startsAt)]))
            .get();
    if (materialized.isNotEmpty) {
      return [
        for (final period in materialized)
          BudgetPeriodWindow(
            id: period.id,
            startsAt: period.startsAt,
            endsAt: period.endsAt,
          ),
      ];
    }
    if (budget.periodType == 'date_range' &&
        budget.periodStart != null &&
        budget.periodEnd != null) {
      return [
        BudgetPeriodWindow(
          startsAt: budget.periodStart!,
          endsAt: budget.periodEnd!,
        ),
      ];
    }
    return const [];
  }

  /// Resolves an imported/materialized period first, then the reusable budget
  /// definition. Custom cycles intentionally require materialized bounds;
  /// this avoids guessing at an imported source recurrence rule.
  Future<BudgetPeriodWindow> resolvePeriod(
    String budgetId,
    DateTime anchor,
  ) async {
    final budget = await _requireBudget(budgetId);
    final materialized =
        await (_db.select(_db.budgetPeriods)
              ..where(
                (row) =>
                    row.budgetId.equals(budgetId) &
                    row.startsAt.isSmallerOrEqualValue(anchor) &
                    row.endsAt.isBiggerThanValue(anchor),
              )
              ..limit(1))
            .getSingleOrNull();
    if (materialized != null) {
      return BudgetPeriodWindow(
        id: materialized.id,
        startsAt: materialized.startsAt,
        endsAt: materialized.endsAt,
      );
    }
    switch (budget.periodType) {
      case 'monthly':
        return BudgetPeriodWindow(
          startsAt: DateTime(anchor.year, anchor.month),
          endsAt: anchor.month == 12
              ? DateTime(anchor.year + 1)
              : DateTime(anchor.year, anchor.month + 1),
        );
      case 'date_range':
        final start = budget.periodStart;
        final end = budget.periodEnd;
        if (start == null || end == null) {
          throw StateError('Date-range budget is missing its bounds');
        }
        return BudgetPeriodWindow(startsAt: start, endsAt: end);
      case 'custom_cycle':
        throw StateError(
          'Custom-cycle budget requires a materialized historical period',
        );
      default:
        throw StateError('Unsupported budget period type');
    }
  }

  Future<CompositeBudgetEvaluation> evaluate(
    String budgetId, {
    required BudgetPeriodWindow period,
  }) async {
    if (!period.endsAt.isAfter(period.startsAt)) {
      throw ArgumentError('Budget period end must be after its start');
    }
    final budget = await _requireBudget(budgetId);
    final results = await Future.wait([
      (_db.select(
        _db.budgetAccountMemberships,
      )..where((row) => row.budgetId.equals(budgetId))).get(),
      (_db.select(
        _db.budgetCategoryMemberships,
      )..where((row) => row.budgetId.equals(budgetId))).get(),
      (_db.select(
        _db.budgetTransactionMemberships,
      )..where((row) => row.budgetId.equals(budgetId))).get(),
      (_db.select(_db.transactions)..where(
            (row) =>
                row.deletedAt.isNull() &
                row.occurredAt.isBiggerOrEqualValue(period.startsAt) &
                row.occurredAt.isSmallerThanValue(period.endsAt),
          ))
          .get(),
      (_db.select(_db.accounts)..where((row) => row.deletedAt.isNull())).get(),
    ]);
    final accountMemberships = results[0] as List<BudgetAccountMembershipData>;
    final categoryMemberships =
        results[1] as List<BudgetCategoryMembershipData>;
    final transactionMemberships =
        results[2] as List<BudgetTransactionMembershipData>;
    final transactions = results[3] as List<TransactionData>;
    final accounts = results[4] as List<AccountData>;

    final includedAccounts = _memberIds(
      accountMemberships,
      include: true,
      idOf: (row) => row.accountId,
      membershipOf: (row) => row.membership,
    );
    final excludedAccounts = _memberIds(
      accountMemberships,
      include: false,
      idOf: (row) => row.accountId,
      membershipOf: (row) => row.membership,
    );
    final includedCategories = _memberIds(
      categoryMemberships,
      include: true,
      idOf: (row) => row.categoryId,
      membershipOf: (row) => row.membership,
    );
    final excludedCategories = _memberIds(
      categoryMemberships,
      include: false,
      idOf: (row) => row.categoryId,
      membershipOf: (row) => row.membership,
    );
    final includedTransactions = _memberIds(
      transactionMemberships,
      include: true,
      idOf: (row) => row.transactionId,
      membershipOf: (row) => row.membership,
    );
    final excludedTransactions = _memberIds(
      transactionMemberships,
      include: false,
      idOf: (row) => row.transactionId,
      membershipOf: (row) => row.membership,
    );
    final accountById = {for (final account in accounts) account.id: account};

    final matches = <BudgetTransactionMatch>[];
    for (final transaction in transactions) {
      if (!_directionMatches(budget.directionFilter, transaction)) continue;
      if (excludedTransactions.contains(transaction.id) ||
          excludedAccounts.contains(transaction.accountId) ||
          (transaction.categoryId != null &&
              excludedCategories.contains(transaction.categoryId))) {
        continue;
      }

      final explicit = includedTransactions.contains(transaction.id);
      final accountMatches =
          includedAccounts.isEmpty ||
          includedAccounts.contains(transaction.accountId);
      final categoryMatches =
          includedCategories.isEmpty ||
          (transaction.categoryId != null &&
              includedCategories.contains(transaction.categoryId));
      final normalMatch = accountMatches && categoryMatches;
      final include = budget.membershipMode == 'explicit_only'
          ? explicit
          : normalMatch || explicit;
      if (!include) continue;

      final account = accountById[transaction.accountId];
      if (account == null) continue;
      final amount = ExactMoneyCodec.transactionAmount(transaction, account);
      if (amount.currencyCode != budget.currencyCode) continue;

      final reason = explicit && !normalMatch
          ? BudgetInclusionReason.explicitlyAttached
          : _normalReason(
              hasAccountIncludes: includedAccounts.isNotEmpty,
              hasCategoryIncludes: includedCategories.isNotEmpty,
              explicitOnly: budget.membershipMode == 'explicit_only',
            );
      matches.add(
        BudgetTransactionMatch(
          transaction: transaction,
          amount: amount,
          reason: reason,
        ),
      );
    }
    matches.sort(
      (left, right) =>
          left.transaction.occurredAt.compareTo(right.transaction.occurredAt),
    );

    final zero = ExactMoney(
      coefficient: BigInt.zero,
      scale: budget.amountScale,
      currencyCode: budget.currencyCode,
    );
    var expenses = zero;
    var income = zero;
    for (final match in matches) {
      if (match.transaction.transactionDirection == 'expense') {
        expenses += match.amount;
      } else {
        income += match.amount;
      }
    }
    return CompositeBudgetEvaluation(
      budget: budget,
      period: period,
      limit: ExactMoney(
        coefficient: BigInt.parse(budget.amountAtoms),
        scale: budget.amountScale,
        currencyCode: budget.currencyCode,
      ),
      expenseTotal: expenses,
      incomeTotal: income,
      matches: List.unmodifiable(matches),
    );
  }

  Future<BudgetDefinitionData> _requireBudget(String id) async {
    final budget = await getById(id);
    if (budget == null) throw StateError('Budget not found');
    return budget;
  }

  static Set<String> _memberIds<T>(
    List<T> rows, {
    required bool include,
    required String? Function(T row) idOf,
    required String Function(T row) membershipOf,
  }) {
    final expected = include ? 'include' : 'exclude';
    return {
      for (final row in rows)
        if (membershipOf(row) == expected && idOf(row) != null) idOf(row)!,
    };
  }

  static bool _directionMatches(
    String directionFilter,
    TransactionData transaction,
  ) {
    return directionFilter == 'both' ||
        directionFilter == transaction.transactionDirection;
  }

  static BudgetInclusionReason _normalReason({
    required bool hasAccountIncludes,
    required bool hasCategoryIncludes,
    required bool explicitOnly,
  }) {
    if (explicitOnly) return BudgetInclusionReason.explicitlyAttached;
    if (hasAccountIncludes && hasCategoryIncludes) {
      return BudgetInclusionReason.accountAndCategory;
    }
    if (hasAccountIncludes) return BudgetInclusionReason.account;
    if (hasCategoryIncludes) return BudgetInclusionReason.category;
    return BudgetInclusionReason.allMatching;
  }
}

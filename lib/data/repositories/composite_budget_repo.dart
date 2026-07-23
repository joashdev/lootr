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

class CompositeBudgetMemberReference {
  const CompositeBudgetMemberReference({
    required this.kind,
    required this.membership,
    required this.reviewState,
    this.resolvedId,
    this.sourceReference,
  });

  final String kind;
  final String membership;
  final String reviewState;
  final String? resolvedId;
  final String? sourceReference;

  bool get isUnresolved => resolvedId == null;
}

class CompositeBudgetScope {
  const CompositeBudgetScope({
    required this.membershipMode,
    required this.directionFilter,
    required this.periodType,
    required this.members,
  });

  final String membershipMode;
  final String directionFilter;
  final String periodType;
  final List<CompositeBudgetMemberReference> members;
}

class CompositeBudgetOverlap {
  const CompositeBudgetOverlap({
    required this.budgetId,
    required this.budgetName,
    required this.sharedTransactionCount,
  });

  final String budgetId;
  final String budgetName;
  final int sharedTransactionCount;
}

class CompositeBudgetSnapshot {
  const CompositeBudgetSnapshot({
    required this.evaluation,
    required this.review,
    required this.scope,
    required this.history,
    required this.overlaps,
  });

  final CompositeBudgetEvaluation evaluation;
  final CompositeBudgetReviewSummary review;
  final CompositeBudgetScope scope;
  final List<BudgetPeriodWindow> history;
  final List<CompositeBudgetOverlap> overlaps;
}

class CompositeBudgetDraft {
  const CompositeBudgetDraft({
    required this.id,
    required this.ownerUserId,
    required this.name,
    required this.limit,
    required this.periodType,
    required this.directionFilter,
    required this.membershipMode,
    this.householdId,
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

  final String id;
  final String ownerUserId;
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

  Future<CompositeBudgetDraft?> getDraft(String id) async {
    final definition = await getById(id);
    if (definition == null) return null;
    final accounts = await (_db.select(
      _db.budgetAccountMemberships,
    )..where((row) => row.budgetId.equals(id))).get();
    final categories = await (_db.select(
      _db.budgetCategoryMemberships,
    )..where((row) => row.budgetId.equals(id))).get();
    final transactions = await (_db.select(
      _db.budgetTransactionMemberships,
    )..where((row) => row.budgetId.equals(id))).get();
    Set<String> members<T>(
      List<T> rows,
      String membership,
      String? Function(T) idOf,
      String Function(T) membershipOf,
    ) => {
      for (final row in rows)
        if (membershipOf(row) == membership && idOf(row) != null) idOf(row)!,
    };
    return CompositeBudgetDraft(
      id: definition.id,
      ownerUserId: definition.ownerUserId,
      householdId: definition.householdId,
      name: definition.name ?? '',
      limit: ExactMoney(
        coefficient: BigInt.parse(definition.amountAtoms),
        scale: definition.amountScale,
        currencyCode: definition.currencyCode,
      ),
      periodType: definition.periodType,
      periodStart: definition.periodStart,
      periodEnd: definition.periodEnd,
      cycleRule: definition.cycleRule,
      directionFilter: definition.directionFilter,
      membershipMode: definition.membershipMode,
      includedAccountIds: members(
        accounts,
        'include',
        (row) => row.accountId,
        (row) => row.membership,
      ),
      excludedAccountIds: members(
        accounts,
        'exclude',
        (row) => row.accountId,
        (row) => row.membership,
      ),
      includedCategoryIds: members(
        categories,
        'include',
        (row) => row.categoryId,
        (row) => row.membership,
      ),
      excludedCategoryIds: members(
        categories,
        'exclude',
        (row) => row.categoryId,
        (row) => row.membership,
      ),
      includedTransactionIds: members(
        transactions,
        'include',
        (row) => row.transactionId,
        (row) => row.membership,
      ),
      excludedTransactionIds: members(
        transactions,
        'exclude',
        (row) => row.transactionId,
        (row) => row.membership,
      ),
    );
  }

  Future<String> create(CompositeBudgetDraft draft) async {
    await _validateDraft(draft);
    await _db.transaction(() async {
      await _db
          .into(_db.budgetDefinitions)
          .insert(
            BudgetDefinitionsCompanion.insert(
              id: draft.id,
              ownerUserId: draft.ownerUserId,
              householdId: Value(draft.householdId),
              name: Value(draft.name.trim()),
              amountAtoms: draft.limit.coefficient.toString(),
              amountScale: draft.limit.scale,
              currencyCode: draft.limit.currencyCode,
              periodType: Value(draft.periodType),
              periodStart: Value(draft.periodStart),
              periodEnd: Value(draft.periodEnd),
              cycleRule: Value(draft.cycleRule),
              directionFilter: Value(draft.directionFilter),
              membershipMode: Value(draft.membershipMode),
              reviewState: const Value('ready'),
              isReadOnly: const Value(false),
            ),
          );
      await _replaceMemberships(draft);
      await _replaceMaterializedPeriod(draft);
    });
    return draft.id;
  }

  Future<void> update(CompositeBudgetDraft draft) async {
    final existing = await _requireBudget(draft.id);
    if (existing.isReadOnly) {
      throw StateError('Imported read-only budgets cannot be edited');
    }
    await _validateDraft(draft);
    await _db.transaction(() async {
      await (_db.update(
        _db.budgetDefinitions,
      )..where((row) => row.id.equals(draft.id))).write(
        BudgetDefinitionsCompanion(
          name: Value(draft.name.trim()),
          amountAtoms: Value(draft.limit.coefficient.toString()),
          amountScale: Value(draft.limit.scale),
          currencyCode: Value(draft.limit.currencyCode),
          periodType: Value(draft.periodType),
          periodStart: Value(draft.periodStart),
          periodEnd: Value(draft.periodEnd),
          cycleRule: Value(draft.cycleRule),
          directionFilter: Value(draft.directionFilter),
          membershipMode: Value(draft.membershipMode),
          reviewState: const Value('ready'),
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _replaceMemberships(draft);
      await _replaceMaterializedPeriod(draft);
    });
  }

  Future<void> softDelete(String id) async {
    final existing = await _requireBudget(id);
    if (existing.isReadOnly) {
      throw StateError('Imported read-only budgets cannot be deleted');
    }
    await (_db.update(
      _db.budgetDefinitions,
    )..where((row) => row.id.equals(id))).write(
      BudgetDefinitionsCompanion(
        deletedAt: Value(DateTime.now()),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ),
    );
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
        snapshots.add(await _snapshot(definition, period));
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

  Future<CompositeBudgetSnapshot> _snapshot(
    BudgetDefinitionData definition,
    BudgetPeriodWindow period,
  ) async {
    final evaluation = await evaluate(definition.id, period: period);
    final results = await Future.wait([
      reviewSummary(definition.id),
      scope(definition.id),
      listHistoricalPeriods(definition.id),
      _overlaps(evaluation),
    ]);
    return CompositeBudgetSnapshot(
      evaluation: evaluation,
      review: results[0] as CompositeBudgetReviewSummary,
      scope: results[1] as CompositeBudgetScope,
      history: results[2] as List<BudgetPeriodWindow>,
      overlaps: results[3] as List<CompositeBudgetOverlap>,
    );
  }

  Future<CompositeBudgetScope> scope(String budgetId) async {
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
    ]);
    final members = <CompositeBudgetMemberReference>[
      for (final row in results[0] as List<BudgetAccountMembershipData>)
        CompositeBudgetMemberReference(
          kind: 'account',
          membership: row.membership,
          reviewState: row.reviewState,
          resolvedId: row.accountId,
          sourceReference: row.sourceReference,
        ),
      for (final row in results[1] as List<BudgetCategoryMembershipData>)
        CompositeBudgetMemberReference(
          kind: 'category',
          membership: row.membership,
          reviewState: row.reviewState,
          resolvedId: row.categoryId,
          sourceReference: row.sourceReference,
        ),
      for (final row in results[2] as List<BudgetTransactionMembershipData>)
        CompositeBudgetMemberReference(
          kind: 'transaction',
          membership: row.membership,
          reviewState: row.reviewState,
          resolvedId: row.transactionId,
          sourceReference: row.sourceReference,
        ),
    ];
    return CompositeBudgetScope(
      membershipMode: budget.membershipMode,
      directionFilter: budget.directionFilter,
      periodType: budget.periodType,
      members: List.unmodifiable(members),
    );
  }

  Future<List<CompositeBudgetOverlap>> _overlaps(
    CompositeBudgetEvaluation evaluation,
  ) async {
    final transactionIds = {
      for (final match in evaluation.matches) match.transaction.id,
    };
    if (transactionIds.isEmpty) return const [];
    final definitions =
        await (_db.select(_db.budgetDefinitions)..where(
              (row) =>
                  row.id.equals(evaluation.budget.id).not() &
                  row.deletedAt.isNull(),
            ))
            .get();
    final overlaps = <CompositeBudgetOverlap>[];
    for (final definition in definitions) {
      BudgetPeriodWindow otherPeriod;
      try {
        otherPeriod = await resolvePeriod(
          definition.id,
          evaluation.period.startsAt,
        );
      } on StateError {
        continue;
      }
      final other = await evaluate(definition.id, period: otherPeriod);
      final count = other.matches
          .where((match) => transactionIds.contains(match.transaction.id))
          .length;
      if (count == 0) continue;
      overlaps.add(
        CompositeBudgetOverlap(
          budgetId: definition.id,
          budgetName: definition.name?.trim().isNotEmpty == true
              ? definition.name!.trim()
              : 'Imported budget',
          sharedTransactionCount: count,
        ),
      );
    }
    overlaps.sort((left, right) => left.budgetName.compareTo(right.budgetName));
    return List.unmodifiable(overlaps);
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

  Future<void> _validateDraft(CompositeBudgetDraft draft) async {
    if (draft.name.trim().isEmpty) {
      throw ArgumentError('Budget name is required');
    }
    if (draft.limit.coefficient <= BigInt.zero) {
      throw ArgumentError('Budget amount must be greater than zero');
    }
    if (!const {
      'monthly',
      'date_range',
      'custom_cycle',
    }.contains(draft.periodType)) {
      throw ArgumentError('Unsupported budget period type');
    }
    if (draft.periodType != 'monthly') {
      if (draft.periodStart == null ||
          draft.periodEnd == null ||
          !draft.periodEnd!.isAfter(draft.periodStart!)) {
        throw ArgumentError('A valid start and end date are required');
      }
    }
    if (!const {'expense', 'income', 'both'}.contains(draft.directionFilter)) {
      throw ArgumentError('Unsupported direction filter');
    }
    if (!const {
      'all_matching',
      'explicit_only',
    }.contains(draft.membershipMode)) {
      throw ArgumentError('Unsupported membership mode');
    }
    _ensureDisjoint(
      draft.includedAccountIds,
      draft.excludedAccountIds,
      'account',
    );
    _ensureDisjoint(
      draft.includedCategoryIds,
      draft.excludedCategoryIds,
      'category',
    );
    _ensureDisjoint(
      draft.includedTransactionIds,
      draft.excludedTransactionIds,
      'transaction',
    );

    final accountIds = {
      ...draft.includedAccountIds,
      ...draft.excludedAccountIds,
    }.toList();
    final accounts = accountIds.isEmpty
        ? const <AccountData>[]
        : await (_db.select(_db.accounts)..where(
                (row) =>
                    row.id.isIn(accountIds) &
                    row.deletedAt.isNull() &
                    row.isArchived.equals(false),
              ))
              .get();
    if (accounts.length != accountIds.length) {
      throw ArgumentError('One or more selected accounts are unavailable');
    }
    if (accounts.any(
      (account) =>
          draft.includedAccountIds.contains(account.id) &&
          account.currencyCode != draft.limit.currencyCode,
    )) {
      throw ArgumentError(
        'Every included account must use ${draft.limit.currencyCode}',
      );
    }

    final categoryIds = {
      ...draft.includedCategoryIds,
      ...draft.excludedCategoryIds,
    }.toList();
    final categories = categoryIds.isEmpty
        ? const <CategoryData>[]
        : await (_db.select(_db.categories)..where(
                (row) => row.id.isIn(categoryIds) & row.deletedAt.isNull(),
              ))
              .get();
    if (categories.length != categoryIds.length) {
      throw ArgumentError('One or more selected categories are unavailable');
    }

    final transactionIds = {
      ...draft.includedTransactionIds,
      ...draft.excludedTransactionIds,
    }.toList();
    if (transactionIds.isNotEmpty) {
      final transactions =
          await (_db.select(_db.transactions)..where(
                (row) => row.id.isIn(transactionIds) & row.deletedAt.isNull(),
              ))
              .get();
      if (transactions.length != transactionIds.length) {
        throw ArgumentError(
          'One or more selected transactions are unavailable',
        );
      }
    }
  }

  static void _ensureDisjoint(
    Set<String> included,
    Set<String> excluded,
    String label,
  ) {
    if (included.intersection(excluded).isNotEmpty) {
      throw ArgumentError('A $label cannot be both included and excluded');
    }
  }

  Future<void> _replaceMemberships(CompositeBudgetDraft draft) async {
    await (_db.delete(
      _db.budgetAccountMemberships,
    )..where((row) => row.budgetId.equals(draft.id))).go();
    await (_db.delete(
      _db.budgetCategoryMemberships,
    )..where((row) => row.budgetId.equals(draft.id))).go();
    await (_db.delete(
      _db.budgetTransactionMemberships,
    )..where((row) => row.budgetId.equals(draft.id))).go();

    for (final membership in [
      for (final id in draft.includedAccountIds) (id, 'include'),
      for (final id in draft.excludedAccountIds) (id, 'exclude'),
    ]) {
      await _db
          .into(_db.budgetAccountMemberships)
          .insert(
            BudgetAccountMembershipsCompanion.insert(
              id: '${draft.id}-account-${membership.$2}-${membership.$1}',
              budgetId: draft.id,
              accountId: Value(membership.$1),
              membership: Value(membership.$2),
            ),
          );
    }
    for (final membership in [
      for (final id in draft.includedCategoryIds) (id, 'include'),
      for (final id in draft.excludedCategoryIds) (id, 'exclude'),
    ]) {
      await _db
          .into(_db.budgetCategoryMemberships)
          .insert(
            BudgetCategoryMembershipsCompanion.insert(
              id: '${draft.id}-category-${membership.$2}-${membership.$1}',
              budgetId: draft.id,
              categoryId: Value(membership.$1),
              membership: Value(membership.$2),
            ),
          );
    }
    for (final membership in [
      for (final id in draft.includedTransactionIds) (id, 'include'),
      for (final id in draft.excludedTransactionIds) (id, 'exclude'),
    ]) {
      await _db
          .into(_db.budgetTransactionMemberships)
          .insert(
            BudgetTransactionMembershipsCompanion.insert(
              id: '${draft.id}-transaction-${membership.$2}-${membership.$1}',
              budgetId: draft.id,
              transactionId: Value(membership.$1),
              membership: Value(membership.$2),
              reasonCode: const Value('user_selected'),
            ),
          );
    }
  }

  Future<void> _replaceMaterializedPeriod(CompositeBudgetDraft draft) async {
    await (_db.delete(
      _db.budgetPeriods,
    )..where((row) => row.budgetId.equals(draft.id))).go();
    if (draft.periodType != 'custom_cycle') return;
    await _db
        .into(_db.budgetPeriods)
        .insert(
          BudgetPeriodsCompanion.insert(
            id: '${draft.id}-period-${draft.periodStart!.microsecondsSinceEpoch}',
            budgetId: draft.id,
            startsAt: draft.periodStart!,
            endsAt: draft.periodEnd!,
            amountAtoms: draft.limit.coefficient.toString(),
            amountScale: draft.limit.scale,
            currencyCode: draft.limit.currencyCode,
          ),
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

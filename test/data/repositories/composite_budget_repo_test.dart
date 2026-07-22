import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/composite_budget_repo.dart';

void main() {
  late AppDatabase db;
  late CompositeBudgetRepo repo;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = CompositeBudgetRepo(db);
    await db.users.insertOne(UsersCompanion.insert(id: 'user'));
    for (final category in ['food', 'travel', 'excluded']) {
      await db.categories.insertOne(
        CategoriesCompanion.insert(
          id: category,
          name: category,
          categoryGroup: 'expense',
        ),
      );
    }
    await _account(db, 'cash', 'USD', 4);
    await _account(db, 'bank', 'USD', 4);
    await _account(db, 'other-currency', 'JPY', 2);
  });

  tearDown(() => db.close());

  test(
    'evaluates composite includes, excludes, explicit additions, and reasons',
    () async {
      await _budget(
        db,
        id: 'budget',
        membershipMode: 'all_matching',
        direction: 'expense',
      );
      await db.budgetAccountMemberships.insertOne(
        BudgetAccountMembershipsCompanion.insert(
          id: 'include-cash',
          budgetId: 'budget',
          accountId: const Value('cash'),
        ),
      );
      await db.budgetAccountMemberships.insertOne(
        BudgetAccountMembershipsCompanion.insert(
          id: 'exclude-bank',
          budgetId: 'budget',
          accountId: const Value('bank'),
          membership: const Value('exclude'),
        ),
      );
      await db.budgetCategoryMemberships.insertOne(
        BudgetCategoryMembershipsCompanion.insert(
          id: 'include-food',
          budgetId: 'budget',
          categoryId: const Value('food'),
        ),
      );
      await db.budgetCategoryMemberships.insertOne(
        BudgetCategoryMembershipsCompanion.insert(
          id: 'exclude-category',
          budgetId: 'budget',
          categoryId: const Value('excluded'),
          membership: const Value('exclude'),
        ),
      );

      await _transaction(
        db,
        id: 'normal',
        account: 'cash',
        category: 'food',
        atoms: '12345',
      );
      await _transaction(
        db,
        id: 'explicit',
        account: 'cash',
        category: 'travel',
        atoms: '5',
        scale: 4,
      );
      await db.budgetTransactionMemberships.insertOne(
        BudgetTransactionMembershipsCompanion.insert(
          id: 'explicit-link',
          budgetId: 'budget',
          transactionId: const Value('explicit'),
        ),
      );
      await _transaction(
        db,
        id: 'exclude-wins',
        account: 'bank',
        category: 'food',
        atoms: '9000',
      );
      await db.budgetTransactionMemberships.insertOne(
        BudgetTransactionMembershipsCompanion.insert(
          id: 'exclude-wins-link',
          budgetId: 'budget',
          transactionId: const Value('exclude-wins'),
        ),
      );
      await _transaction(
        db,
        id: 'wrong-direction',
        account: 'cash',
        category: 'food',
        atoms: '7000',
        direction: 'income',
      );

      final result = await repo.evaluate(
        'budget',
        period: BudgetPeriodWindow(
          startsAt: DateTime(2026, 7),
          endsAt: DateTime(2026, 8),
        ),
      );

      expect(result.matches.map((match) => match.transaction.id), [
        'normal',
        'explicit',
      ]);
      expect(result.matches.map((match) => match.reason), [
        BudgetInclusionReason.accountAndCategory,
        BudgetInclusionReason.explicitlyAttached,
      ]);
      expect(result.expenseTotal.toDecimalString(), '1.2350');
      expect(result.incomeTotal.toDecimalString(), '0.0000');
      expect(result.matches.last.reasonLabel, 'Explicitly attached');
    },
  );

  test(
    'explicit-only still applies period, direction, currency, and excludes',
    () async {
      await _budget(
        db,
        id: 'budget',
        membershipMode: 'explicit_only',
        direction: 'both',
      );
      for (final entry in [
        ('in-scope', 'cash', 'USD', DateTime(2026, 7, 3)),
        ('outside', 'cash', 'USD', DateTime(2026, 8, 3)),
        ('wrong-currency', 'other-currency', 'JPY', DateTime(2026, 7, 3)),
      ]) {
        await _transaction(
          db,
          id: entry.$1,
          account: entry.$2,
          category: 'food',
          atoms: '1',
          currency: entry.$3,
          occurredAt: entry.$4,
        );
        await db.budgetTransactionMemberships.insertOne(
          BudgetTransactionMembershipsCompanion.insert(
            id: 'link-${entry.$1}',
            budgetId: 'budget',
            transactionId: Value(entry.$1),
          ),
        );
      }
      await db.budgetTransactionMemberships.insertOne(
        BudgetTransactionMembershipsCompanion.insert(
          id: 'exclude',
          budgetId: 'budget',
          transactionId: const Value('in-scope'),
          membership: const Value('exclude'),
        ),
      );

      final result = await repo.evaluate(
        'budget',
        period: BudgetPeriodWindow(
          startsAt: DateTime(2026, 7),
          endsAt: DateTime(2026, 8),
        ),
      );
      expect(result.matches, isEmpty);
    },
  );

  test(
    'resolves monthly, date-range, and materialized custom history',
    () async {
      await _budget(db, id: 'monthly');
      await _budget(
        db,
        id: 'range',
        periodType: 'date_range',
        start: DateTime(2026, 1, 7),
        end: DateTime(2026, 2, 11),
      );
      await _budget(db, id: 'cycle', periodType: 'custom_cycle');
      await db.budgetPeriods.insertOne(
        BudgetPeriodsCompanion.insert(
          id: 'cycle-period',
          budgetId: 'cycle',
          startsAt: DateTime(2026, 6, 15),
          endsAt: DateTime(2026, 7, 15),
          amountAtoms: '100000',
          amountScale: 4,
          currencyCode: 'USD',
        ),
      );

      final monthly = await repo.resolvePeriod(
        'monthly',
        DateTime(2026, 12, 9),
      );
      final range = await repo.resolvePeriod('range', DateTime(2030));
      final cycle = await repo.resolvePeriod('cycle', DateTime(2026, 7, 1));
      final history = await repo.listHistoricalPeriods('cycle');

      expect(monthly.startsAt, DateTime(2026, 12));
      expect(monthly.endsAt, DateTime(2027));
      expect(range.startsAt, DateTime(2026, 1, 7));
      expect(range.endsAt, DateTime(2026, 2, 11));
      expect(cycle.id, 'cycle-period');
      expect(history.single.id, 'cycle-period');
    },
  );

  test(
    'watchForPeriod reacts and reports preserved missing references',
    () async {
      await _budget(db, id: 'watched');
      await db.budgetAccountMemberships.insertOne(
        BudgetAccountMembershipsCompanion.insert(
          id: 'missing-account',
          budgetId: 'watched',
          sourceReference: const Value('redacted-reference'),
          reviewState: const Value('missing_reference'),
        ),
      );

      final snapshots = await repo.watchForPeriod(DateTime(2026, 7, 2)).first;
      expect(snapshots.single.evaluation.budget.id, 'watched');
      expect(snapshots.single.review.accountReferences, 1);
      expect(snapshots.single.review.missingReferenceCount, 1);
    },
  );
}

Future<void> _account(
  AppDatabase db,
  String id,
  String currency,
  int precision,
) {
  return db.accounts.insertOne(
    AccountsCompanion.insert(
      id: id,
      ownerUserId: 'user',
      name: id,
      accountType: 'cash',
      currencyCode: Value(currency),
      balanceAtoms: const Value('0'),
      currencyPrecision: Value(precision),
    ),
  );
}

Future<void> _budget(
  AppDatabase db, {
  required String id,
  String membershipMode = 'all_matching',
  String direction = 'expense',
  String periodType = 'monthly',
  DateTime? start,
  DateTime? end,
}) {
  return db.budgetDefinitions.insertOne(
    BudgetDefinitionsCompanion.insert(
      id: id,
      ownerUserId: 'user',
      amountAtoms: '100000',
      amountScale: 4,
      currencyCode: 'USD',
      periodType: Value(periodType),
      periodStart: Value(start),
      periodEnd: Value(end),
      membershipMode: Value(membershipMode),
      directionFilter: Value(direction),
    ),
  );
}

Future<void> _transaction(
  AppDatabase db, {
  required String id,
  required String account,
  required String category,
  required String atoms,
  int scale = 4,
  String currency = 'USD',
  String direction = 'expense',
  DateTime? occurredAt,
}) {
  return db.transactions.insertOne(
    TransactionsCompanion.insert(
      id: id,
      accountId: account,
      amount: 0,
      amountAtoms: Value(atoms),
      amountScale: Value(scale),
      currencyCode: Value(currency),
      categoryId: Value(category),
      transactionDirection: direction,
      transactionMode: 'one_time',
      occurredAt: occurredAt ?? DateTime(2026, 7, 2),
    ),
  );
}

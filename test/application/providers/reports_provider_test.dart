import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/reports_provider.dart';
import 'package:lootr/data/database/app_database.dart';

Future<T> readAsyncValue<T>(
  ProviderContainer container,
  dynamic provider,
) async {
  final initial = container.read(provider) as AsyncValue<T>;
  if (initial.hasValue) {
    return initial.requireValue;
  }

  final completer = Completer<T>();
  late final ProviderSubscription<AsyncValue<T>> sub;
  sub = container.listen(provider, (prev, next) {
    if (!completer.isCompleted && next.hasValue) {
      completer.complete(next.requireValue);
    }
  });

  try {
    return await completer.future.timeout(const Duration(seconds: 5));
  } finally {
    sub.close();
  }
}

void main() {
  late AppDatabase db;

  // Fixed "now" so aggregation windows are deterministic.
  final now = DateTime(2026, 6, 15, 12);

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) => db),
        reportsClockProvider.overrideWithValue(now),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() async {
    db = AppDatabase.inMemory();

    await db.users.insertOne(
      UsersCompanion.insert(id: 'usr-1', currencyCode: const Value('PHP')),
    );

    await db.categories.insertOne(
      CategoriesCompanion.insert(
        id: 'cat-food',
        name: 'Food',
        categoryGroup: 'expense',
        color: const Value('#FF0000'),
      ),
    );
    await db.categories.insertOne(
      CategoriesCompanion.insert(
        id: 'cat-transport',
        name: 'Transport',
        categoryGroup: 'expense',
      ),
    );

    await db.accounts.insertOne(
      AccountsCompanion.insert(
        id: 'acc-cash',
        ownerUserId: 'usr-1',
        name: 'Cash',
        accountType: 'cash',
        balance: const Value(1000),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertTxn({
    required String id,
    required double amount,
    required String direction,
    required DateTime occurredAt,
    String accountId = 'acc-cash',
    String? categoryId,
    DateTime? deletedAt,
  }) {
    return db.transactions.insertOne(
      TransactionsCompanion.insert(
        id: id,
        accountId: accountId,
        amount: amount,
        transactionDirection: direction,
        transactionMode: 'one_time',
        occurredAt: occurredAt,
        categoryId: Value(categoryId),
        deletedAt: Value(deletedAt),
      ),
    );
  }

  group('categorySpendingReportProvider', () {
    test(
      'groups current-month expenses by category with percentages, '
      'ignoring income, other months, and deleted rows',
      () async {
        await insertTxn(
          id: 'txn-food-1',
          amount: 300,
          direction: 'expense',
          occurredAt: DateTime(2026, 6, 3),
          categoryId: 'cat-food',
        );
        await insertTxn(
          id: 'txn-food-2',
          amount: 150,
          direction: 'expense',
          occurredAt: DateTime(2026, 6, 10),
          categoryId: 'cat-food',
        );
        await insertTxn(
          id: 'txn-transport',
          amount: 50,
          direction: 'expense',
          occurredAt: DateTime(2026, 6, 12),
          categoryId: 'cat-transport',
        );
        await insertTxn(
          id: 'txn-uncategorized',
          amount: 100,
          direction: 'expense',
          occurredAt: DateTime(2026, 6, 8),
        );
        // Should all be excluded:
        await insertTxn(
          id: 'txn-income',
          amount: 5000,
          direction: 'income',
          occurredAt: DateTime(2026, 6, 5),
          categoryId: 'cat-food',
        );
        await insertTxn(
          id: 'txn-last-month',
          amount: 999,
          direction: 'expense',
          occurredAt: DateTime(2026, 5, 20),
          categoryId: 'cat-food',
        );
        await insertTxn(
          id: 'txn-deleted',
          amount: 888,
          direction: 'expense',
          occurredAt: DateTime(2026, 6, 9),
          categoryId: 'cat-food',
          deletedAt: DateTime(2026, 6, 10),
        );

        final container = makeContainer();
        final report = await readAsyncValue<CategorySpendingReport>(
          container,
          categorySpendingReportProvider,
        );

        expect(report.currencyCode, 'PHP');
        expect(report.total, 600);
        expect(report.isEmpty, isFalse);
        expect(report.slices.map((s) => s.name), [
          'Food',
          'Uncategorized',
          'Transport',
        ]);

        final food = report.slices.first;
        expect(food.amount, 450);
        expect(food.percentage, closeTo(0.75, 0.0001));

        final uncategorized = report.slices[1];
        expect(uncategorized.categoryId, isNull);
        expect(uncategorized.amount, 100);

        expect(report.slices[2].percentage, closeTo(50 / 600, 0.0001));
      },
    );

    test('is empty when there are no expenses in the current month', () async {
      await insertTxn(
        id: 'txn-income-only',
        amount: 1000,
        direction: 'income',
        occurredAt: DateTime(2026, 6, 2),
      );

      final container = makeContainer();
      final report = await readAsyncValue<CategorySpendingReport>(
        container,
        categorySpendingReportProvider,
      );

      expect(report.isEmpty, isTrue);
      expect(report.total, 0);
    });
  });

  group('monthlyFlowReportProvider', () {
    test('buckets income and expense into six months, oldest first', () async {
      // Current month (June 2026).
      await insertTxn(
        id: 'txn-jun-income',
        amount: 2000,
        direction: 'income',
        occurredAt: DateTime(2026, 6, 1),
      );
      await insertTxn(
        id: 'txn-jun-expense',
        amount: 700,
        direction: 'expense',
        occurredAt: DateTime(2026, 6, 10),
        categoryId: 'cat-food',
      );
      // Oldest month in the window (January 2026).
      await insertTxn(
        id: 'txn-jan-expense',
        amount: 400,
        direction: 'expense',
        occurredAt: DateTime(2026, 1, 20),
        categoryId: 'cat-food',
      );
      // Outside the six-month window — excluded.
      await insertTxn(
        id: 'txn-dec-expense',
        amount: 999,
        direction: 'expense',
        occurredAt: DateTime(2025, 12, 25),
        categoryId: 'cat-food',
      );
      final container = makeContainer();
      final report = await readAsyncValue<MonthlyFlowReport>(
        container,
        monthlyFlowReportProvider,
      );

      expect(report.months, hasLength(6));
      expect(
        report.months.map((m) => '${m.year}-${m.month}'),
        ['2026-1', '2026-2', '2026-3', '2026-4', '2026-5', '2026-6'],
      );

      final january = report.months.first;
      expect(january.income, 0);
      expect(january.expense, 400);
      expect(january.net, -400);

      final june = report.months.last;
      expect(june.income, 2000);
      expect(june.expense, 700);
      expect(june.net, 1300);

      expect(report.totalIncome, 2000);
      expect(report.totalExpense, 1100);
      expect(report.totalNet, 900);
      expect(report.isEmpty, isFalse);
    });

    test('is empty with no income or expense activity', () async {
      final container = makeContainer();
      final report = await readAsyncValue<MonthlyFlowReport>(
        container,
        monthlyFlowReportProvider,
      );

      expect(report.isEmpty, isTrue);
      expect(report.months, hasLength(6));
    });
  });

  group('netWorthReportProvider', () {
    test(
      'computes net worth from assets minus liabilities and reconstructs '
      'the 90-day series backwards from current balances',
      () async {
        await db.accounts.insertOne(
          AccountsCompanion.insert(
            id: 'acc-cc',
            ownerUserId: 'usr-1',
            name: 'Credit Card',
            accountType: 'credit_card',
            balance: const Value(-200),
          ),
        );

        // Recent income raised net worth by 500 ten days ago.
        await insertTxn(
          id: 'txn-income',
          amount: 500,
          direction: 'income',
          occurredAt: now.subtract(const Duration(days: 10)),
        );
        // Expense lowered it by 100 five days ago.
        await insertTxn(
          id: 'txn-expense',
          amount: 100,
          direction: 'expense',
          occurredAt: now.subtract(const Duration(days: 5)),
          categoryId: 'cat-food',
        );

        final container = makeContainer();
        final report = await readAsyncValue<NetWorthReport>(
          container,
          netWorthReportProvider,
        );

        // 1000 cash - |−200| liability.
        expect(report.current, 800);
        expect(report.hasAccounts, isTrue);
        expect(report.series, hasLength(90));
        // Before both transactions: 800 - (500 - 100) = 400.
        expect(report.series.first, 400);
        // Series ends at the current net worth.
        expect(report.series.last, 800);
        expect(report.changePercent, closeTo(100, 0.0001));
      },
    );

    test('is empty when there are no visible accounts', () async {
      await (db.update(db.accounts)).write(
        const AccountsCompanion(isArchived: Value(true)),
      );

      final container = makeContainer();
      final report = await readAsyncValue<NetWorthReport>(
        container,
        netWorthReportProvider,
      );

      expect(report.hasAccounts, isFalse);
      expect(report.isEmpty, isTrue);
      expect(report.current, 0);
    });
  });

  group('budgetPerformanceReportProvider', () {
    test(
      'reports spent vs budgeted per current-month budget, '
      'sorted by most-consumed first',
      () async {
        await db.budgets.insertOne(
          BudgetsCompanion.insert(
            id: 'bud-food',
            ownerUserId: 'usr-1',
            categoryId: 'cat-food',
            amount: 500,
            month: 6,
            year: 2026,
          ),
        );
        await db.budgets.insertOne(
          BudgetsCompanion.insert(
            id: 'bud-transport',
            ownerUserId: 'usr-1',
            categoryId: 'cat-transport',
            amount: 200,
            month: 6,
            year: 2026,
          ),
        );
        // Different month — excluded.
        await db.budgets.insertOne(
          BudgetsCompanion.insert(
            id: 'bud-may',
            ownerUserId: 'usr-1',
            categoryId: 'cat-food',
            amount: 999,
            month: 5,
            year: 2026,
          ),
        );

        await insertTxn(
          id: 'txn-food',
          amount: 100,
          direction: 'expense',
          occurredAt: DateTime(2026, 6, 5),
          categoryId: 'cat-food',
        );
        await insertTxn(
          id: 'txn-transport',
          amount: 180,
          direction: 'expense',
          occurredAt: DateTime(2026, 6, 7),
          categoryId: 'cat-transport',
        );

        final container = makeContainer();
        final report = await readAsyncValue<BudgetPerformanceReport>(
          container,
          budgetPerformanceReportProvider,
        );

        expect(report.rows, hasLength(2));
        // Transport at 90% consumed sorts ahead of Food at 20%.
        expect(report.rows.map((r) => r.budgetId), [
          'bud-transport',
          'bud-food',
        ]);
        expect(report.rows.first.spent, 180);
        expect(report.rows.first.progress, closeTo(0.9, 0.0001));
        expect(report.rows.last.spent, 100);

        expect(report.totalBudgeted, 700);
        expect(report.totalSpent, 280);
        expect(report.progress, closeTo(0.4, 0.0001));
        expect(report.isEmpty, isFalse);
      },
    );

    test('is empty when the month has no budgets', () async {
      final container = makeContainer();
      final report = await readAsyncValue<BudgetPerformanceReport>(
        container,
        budgetPerformanceReportProvider,
      );

      expect(report.isEmpty, isTrue);
      expect(report.totalBudgeted, 0);
    });
  });
}

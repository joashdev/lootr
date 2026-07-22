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
    String? amountAtoms,
    int? amountScale,
    String? currencyCode,
    DateTime? deletedAt,
  }) {
    return db.transactions.insertOne(
      TransactionsCompanion.insert(
        id: id,
        accountId: accountId,
        amount: amount,
        amountAtoms: Value(amountAtoms),
        amountScale: Value(amountScale),
        currencyCode: Value(currencyCode),
        transactionDirection: direction,
        transactionMode: 'one_time',
        occurredAt: occurredAt,
        categoryId: Value(categoryId),
        deletedAt: Value(deletedAt),
      ),
    );
  }

  group('categorySpendingReportProvider', () {
    test('groups current-month expenses by category with percentages, '
        'ignoring income, other months, and deleted rows', () async {
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
      final reports = await readAsyncValue<List<CategorySpendingReport>>(
        container,
        categorySpendingReportProvider,
      );
      final report = reports.single;

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
    });

    test('is empty when there are no expenses in the current month', () async {
      await insertTxn(
        id: 'txn-income-only',
        amount: 1000,
        direction: 'income',
        occurredAt: DateTime(2026, 6, 2),
      );

      final container = makeContainer();
      final reports = await readAsyncValue<List<CategorySpendingReport>>(
        container,
        categorySpendingReportProvider,
      );

      expect(reports, isEmpty);
    });

    test(
      'returns separate exact totals for every transaction currency',
      () async {
        await db.accounts.insertOne(
          AccountsCompanion.insert(
            id: 'acc-btc',
            ownerUserId: 'usr-1',
            name: 'Digital',
            accountType: 'bank',
            currencyCode: const Value('BTC'),
            currencyPrecision: const Value(12),
            balanceAtoms: const Value('0'),
          ),
        );
        await insertTxn(
          id: 'txn-php',
          amount: 1,
          amountAtoms: '100',
          amountScale: 2,
          currencyCode: 'PHP',
          direction: 'expense',
          occurredAt: DateTime(2026, 6, 4),
          categoryId: 'cat-food',
        );
        await insertTxn(
          id: 'txn-btc',
          accountId: 'acc-btc',
          amount: 0.000000000001,
          amountAtoms: '1',
          amountScale: 12,
          currencyCode: 'BTC',
          direction: 'expense',
          occurredAt: DateTime(2026, 6, 5),
          categoryId: 'cat-food',
        );

        final container = makeContainer();
        final reports = await readAsyncValue<List<CategorySpendingReport>>(
          container,
          categorySpendingReportProvider,
        );

        expect(reports.map((report) => report.currencyCode), ['BTC', 'PHP']);
        expect(reports.first.total, 0.000000000001);
        expect(reports.last.total, 1);
      },
    );
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
      final reports = await readAsyncValue<List<MonthlyFlowReport>>(
        container,
        monthlyFlowReportProvider,
      );
      final report = reports.single;

      expect(report.months, hasLength(6));
      expect(report.months.map((m) => '${m.year}-${m.month}'), [
        '2026-1',
        '2026-2',
        '2026-3',
        '2026-4',
        '2026-5',
        '2026-6',
      ]);

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
      final reports = await readAsyncValue<List<MonthlyFlowReport>>(
        container,
        monthlyFlowReportProvider,
      );

      expect(reports, isEmpty);
    });

    test('partitions monthly flow by currency', () async {
      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-btc-flow',
          ownerUserId: 'usr-1',
          name: 'Digital',
          accountType: 'bank',
          currencyCode: const Value('BTC'),
          currencyPrecision: const Value(12),
          balanceAtoms: const Value('0'),
        ),
      );
      await insertTxn(
        id: 'txn-php-flow',
        amount: 1,
        amountAtoms: '100',
        amountScale: 2,
        currencyCode: 'PHP',
        direction: 'income',
        occurredAt: DateTime(2026, 6, 2),
      );
      await insertTxn(
        id: 'txn-btc-flow',
        accountId: 'acc-btc-flow',
        amount: 0.000000000001,
        amountAtoms: '1',
        amountScale: 12,
        currencyCode: 'BTC',
        direction: 'expense',
        occurredAt: DateTime(2026, 6, 3),
      );

      final reports = await readAsyncValue<List<MonthlyFlowReport>>(
        makeContainer(),
        monthlyFlowReportProvider,
      );

      expect(reports.map((report) => report.currencyCode), ['BTC', 'PHP']);
      expect(reports.first.totalExpense, 0.000000000001);
      expect(reports.last.totalIncome, 1);
    });
  });

  group('netWorthReportProvider', () {
    test('computes net worth from assets minus liabilities and reconstructs '
        'the 90-day series backwards from current balances', () async {
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
      final reports = await readAsyncValue<List<NetWorthReport>>(
        container,
        netWorthReportProvider,
      );
      final report = reports.single;

      // 1000 cash - |−200| liability.
      expect(report.current, 800);
      expect(report.hasAccounts, isTrue);
      expect(report.series, hasLength(90));
      // Before both transactions: 800 - (500 - 100) = 400.
      expect(report.series.first, 400);
      // Series ends at the current net worth.
      expect(report.series.last, 800);
      expect(report.changePercent, closeTo(100, 0.0001));
    });

    test('is empty when there are no visible accounts', () async {
      await (db.update(
        db.accounts,
      )).write(const AccountsCompanion(isArchived: Value(true)));

      final container = makeContainer();
      final reports = await readAsyncValue<List<NetWorthReport>>(
        container,
        netWorthReportProvider,
      );

      expect(reports, isEmpty);
    });

    test('returns one net-worth series per account currency', () async {
      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-btc-net-worth',
          ownerUserId: 'usr-1',
          name: 'Digital',
          accountType: 'bank',
          balance: const Value(0.000000000001),
          balanceAtoms: const Value('1'),
          currencyCode: const Value('BTC'),
          currencyPrecision: const Value(12),
        ),
      );

      final reports = await readAsyncValue<List<NetWorthReport>>(
        makeContainer(),
        netWorthReportProvider,
      );

      expect(reports.map((report) => report.currencyCode), ['BTC', 'PHP']);
      expect(reports.first.current, 0.000000000001);
      expect(reports.last.current, 1000);
    });
  });

  group('budgetPerformanceReportProvider', () {
    test('reports spent vs budgeted per current-month budget, '
        'sorted by most-consumed first', () async {
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
      final reports = await readAsyncValue<List<BudgetPerformanceReport>>(
        container,
        budgetPerformanceReportProvider,
      );
      final report = reports.single;

      expect(report.rows, hasLength(2));
      // Transport at 90% consumed sorts ahead of Food at 20%.
      expect(report.rows.map((r) => r.budgetId), ['bud-transport', 'bud-food']);
      expect(report.rows.first.spent, 180);
      expect(report.rows.first.progress, closeTo(0.9, 0.0001));
      expect(report.rows.last.spent, 100);

      expect(report.totalBudgeted, 700);
      expect(report.totalSpent, 280);
      expect(report.progress, closeTo(0.4, 0.0001));
      expect(report.isEmpty, isFalse);
    });

    test('is empty when the month has no budgets', () async {
      final container = makeContainer();
      final reports = await readAsyncValue<List<BudgetPerformanceReport>>(
        container,
        budgetPerformanceReportProvider,
      );

      expect(reports, isEmpty);
    });

    test('partitions budget performance by budget currency', () async {
      await db.budgets.insertAll([
        BudgetsCompanion.insert(
          id: 'bud-btc',
          ownerUserId: 'usr-1',
          categoryId: 'cat-food',
          amount: 0.000000000002,
          amountAtoms: const Value('2'),
          amountScale: const Value(12),
          currencyCode: const Value('BTC'),
          month: 6,
          year: 2026,
        ),
        BudgetsCompanion.insert(
          id: 'bud-php',
          ownerUserId: 'usr-1',
          categoryId: 'cat-transport',
          amount: 2,
          amountAtoms: const Value('200'),
          amountScale: const Value(2),
          currencyCode: const Value('PHP'),
          month: 6,
          year: 2026,
        ),
      ]);

      final reports = await readAsyncValue<List<BudgetPerformanceReport>>(
        makeContainer(),
        budgetPerformanceReportProvider,
      );

      expect(reports.map((report) => report.currencyCode), ['BTC', 'PHP']);
      expect(reports.first.totalBudgeted, 0.000000000002);
      expect(reports.last.totalBudgeted, 2);
    });

    test(
      'includes imported composite budgets as read-only report rows',
      () async {
        await db.accounts.insertOne(
          AccountsCompanion.insert(
            id: 'acc-usd-report',
            ownerUserId: 'usr-1',
            name: 'Imported account',
            accountType: 'bank',
            currencyCode: const Value('USD'),
            currencyPrecision: const Value(4),
            balanceAtoms: const Value('0'),
          ),
        );
        await db.budgetDefinitions.insertOne(
          BudgetDefinitionsCompanion.insert(
            id: 'imported-report-budget',
            ownerUserId: 'usr-1',
            name: const Value('Imported composite'),
            amountAtoms: '100000',
            amountScale: 4,
            currencyCode: 'USD',
            membershipMode: const Value('explicit_only'),
            isReadOnly: const Value(true),
          ),
        );
        await db.transactions.insertOne(
          TransactionsCompanion.insert(
            id: 'imported-report-transaction',
            accountId: 'acc-usd-report',
            amount: 0,
            amountAtoms: const Value('12345'),
            amountScale: const Value(4),
            currencyCode: const Value('USD'),
            transactionDirection: 'expense',
            transactionMode: 'one_time',
            occurredAt: DateTime(2026, 6, 12),
          ),
        );
        await db.budgetTransactionMemberships.insertOne(
          BudgetTransactionMembershipsCompanion.insert(
            id: 'imported-report-membership',
            budgetId: 'imported-report-budget',
            transactionId: const Value('imported-report-transaction'),
          ),
        );

        final reports = await readAsyncValue<List<BudgetPerformanceReport>>(
          makeContainer(),
          budgetPerformanceReportProvider,
        );
        final report = reports.singleWhere(
          (candidate) => candidate.currencyCode == 'USD',
        );
        final row = report.rows.single;

        expect(row.name, 'Imported composite');
        expect(row.isImported, isTrue);
        expect(row.isReadOnly, isTrue);
        expect(row.spent, 1.2345);
        expect(report.totalBudgeted, 10);
      },
    );

    test(
      'updates when transaction spending changes without a budget edit',
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

        final container = makeContainer();
        final initialCompleter = Completer<BudgetPerformanceReport>();
        final updatedCompleter = Completer<BudgetPerformanceReport>();
        final sub = container.listen<AsyncValue<List<BudgetPerformanceReport>>>(
          budgetPerformanceReportProvider,
          (previous, next) {
            if (!next.hasValue) return;
            final reports = next.requireValue;
            if (reports.isEmpty) return;
            final report = reports.single;
            if (!initialCompleter.isCompleted) {
              initialCompleter.complete(report);
            }
            if (report.totalSpent == 75 && !updatedCompleter.isCompleted) {
              updatedCompleter.complete(report);
            }
          },
          fireImmediately: true,
        );
        addTearDown(sub.close);

        final initial = await initialCompleter.future.timeout(
          const Duration(seconds: 5),
        );
        expect(initial.totalSpent, 0);

        await insertTxn(
          id: 'txn-food-after-report',
          amount: 75,
          direction: 'expense',
          occurredAt: DateTime(2026, 6, 12),
          categoryId: 'cat-food',
        );

        final updated = await updatedCompleter.future.timeout(
          const Duration(seconds: 5),
        );
        expect(updated.rows.single.spent, 75);
        expect(updated.totalSpent, 75);
      },
    );
  });
}

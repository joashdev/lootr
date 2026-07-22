import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/application/providers/budget_detail_provider.dart';
import 'package:lootr/application/providers/budgets_tab_provider.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/imported_budget_detail_provider.dart';
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

  setUp(() async {
    db = AppDatabase.inMemory();

    await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));

    await db.categories.insertOne(
      CategoriesCompanion.insert(
        id: 'cat-food',
        name: 'Food',
        categoryGroup: 'expense',
      ),
    );
    await db.categories.insertOne(
      CategoriesCompanion.insert(
        id: 'cat-transport',
        name: 'Transport',
        categoryGroup: 'expense',
      ),
    );
    await db.categories.insertOne(
      CategoriesCompanion.insert(
        id: 'cat-income',
        name: 'Salary',
        categoryGroup: 'income',
      ),
    );

    await db.accounts.insertOne(
      AccountsCompanion.insert(
        id: 'acc-1',
        ownerUserId: 'usr-1',
        name: 'Cash',
        accountType: 'cash',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('budgets providers', () {
    test(
      'budgetsTabProvider filters by selected month and computes summary',
      () async {
        await db.budgets.insertOne(
          BudgetsCompanion.insert(
            id: 'bud-food-jun',
            ownerUserId: 'usr-1',
            categoryId: 'cat-food',
            amount: 500,
            month: 6,
            year: 2026,
          ),
        );
        await db.budgets.insertOne(
          BudgetsCompanion.insert(
            id: 'bud-transport-jun',
            ownerUserId: 'usr-1',
            categoryId: 'cat-transport',
            amount: 200,
            month: 6,
            year: 2026,
          ),
        );
        await db.budgets.insertOne(
          BudgetsCompanion.insert(
            id: 'bud-food-jul',
            ownerUserId: 'usr-1',
            categoryId: 'cat-food',
            amount: 800,
            month: 7,
            year: 2026,
          ),
        );

        await db.transactions.insertOne(
          TransactionsCompanion.insert(
            id: 'txn-food-jun',
            accountId: 'acc-1',
            amount: 120,
            transactionDirection: 'expense',
            transactionMode: 'one_time',
            occurredAt: DateTime(2026, 6, 10),
            categoryId: const Value('cat-food'),
          ),
        );
        await db.transactions.insertOne(
          TransactionsCompanion.insert(
            id: 'txn-transport-jun',
            accountId: 'acc-1',
            amount: 80,
            transactionDirection: 'expense',
            transactionMode: 'one_time',
            occurredAt: DateTime(2026, 6, 14),
            categoryId: const Value('cat-transport'),
          ),
        );
        await db.transactions.insertOne(
          TransactionsCompanion.insert(
            id: 'txn-food-jul',
            accountId: 'acc-1',
            amount: 300,
            transactionDirection: 'expense',
            transactionMode: 'one_time',
            occurredAt: DateTime(2026, 7, 1),
            categoryId: const Value('cat-food'),
          ),
        );

        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWith((ref) => db)],
        );
        addTearDown(container.dispose);

        container.read(budgetMonthProvider.notifier).goTo(6);
        container.read(budgetYearProvider.notifier).goTo(2026);

        final budgets = await readAsyncValue(container, budgetsTabProvider);
        expect(budgets.map((b) => b.id), ['bud-food-jun', 'bud-transport-jun']);
        expect(
          budgets
              .firstWhere((b) => b.id == 'bud-food-jun')
              .spent
              .toDecimalString(),
          '120.00',
        );
        expect(
          budgets
              .firstWhere((b) => b.id == 'bud-transport-jun')
              .spent
              .toDecimalString(),
          '80.00',
        );

        final summary = container.read(budgetSummaryProvider);
        expect(summary.single.budgeted.toDecimalString(), '700.00');
        expect(summary.single.spent.toDecimalString(), '200.00');
      },
    );

    test(
      'budgetDetailProvider returns only matching category transactions in period',
      () async {
        await db.budgets.insertOne(
          BudgetsCompanion.insert(
            id: 'bud-food-jun',
            ownerUserId: 'usr-1',
            categoryId: 'cat-food',
            amount: 500,
            month: 6,
            year: 2026,
          ),
        );

        await db.transactions.insertOne(
          TransactionsCompanion.insert(
            id: 'txn-match',
            accountId: 'acc-1',
            amount: 100,
            transactionDirection: 'expense',
            transactionMode: 'one_time',
            occurredAt: DateTime(2026, 6, 8),
            categoryId: const Value('cat-food'),
          ),
        );
        await db.transactions.insertOne(
          TransactionsCompanion.insert(
            id: 'txn-wrong-month',
            accountId: 'acc-1',
            amount: 60,
            transactionDirection: 'expense',
            transactionMode: 'one_time',
            occurredAt: DateTime(2026, 7, 8),
            categoryId: const Value('cat-food'),
          ),
        );
        await db.transactions.insertOne(
          TransactionsCompanion.insert(
            id: 'txn-wrong-category',
            accountId: 'acc-1',
            amount: 40,
            transactionDirection: 'expense',
            transactionMode: 'one_time',
            occurredAt: DateTime(2026, 6, 9),
            categoryId: const Value('cat-transport'),
          ),
        );
        await db.transactions.insertOne(
          TransactionsCompanion.insert(
            id: 'txn-wrong-direction',
            accountId: 'acc-1',
            amount: 999,
            transactionDirection: 'income',
            transactionMode: 'one_time',
            occurredAt: DateTime(2026, 6, 10),
            categoryId: const Value('cat-food'),
          ),
        );

        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWith((ref) => db)],
        );
        addTearDown(container.dispose);

        final detail = await readAsyncValue(
          container,
          budgetDetailProvider('bud-food-jun'),
        );

        expect(detail, isNotNull);
        expect(detail!.budget.spent, 100);
        expect(detail.transactions.map((tx) => tx.id), ['txn-match']);
      },
    );

    test(
      'budget detail resolves legacy transaction currency from its account',
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
        await db.budgets.insertOne(
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
        );
        await db.transactions.insertAll([
          TransactionsCompanion.insert(
            id: 'txn-btc-legacy',
            accountId: 'acc-btc',
            amount: 0.000000000001,
            transactionDirection: 'expense',
            transactionMode: 'one_time',
            occurredAt: DateTime(2026, 6, 8),
            categoryId: const Value('cat-food'),
          ),
          TransactionsCompanion.insert(
            id: 'txn-php',
            accountId: 'acc-1',
            amount: 1,
            transactionDirection: 'expense',
            transactionMode: 'one_time',
            occurredAt: DateTime(2026, 6, 8),
            categoryId: const Value('cat-food'),
          ),
        ]);

        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWith((ref) => db)],
        );
        addTearDown(container.dispose);
        final detail = await readAsyncValue(
          container,
          budgetDetailProvider('bud-btc'),
        );

        expect(detail, isNotNull);
        expect(detail!.transactions.map((tx) => tx.id), ['txn-btc-legacy']);
        expect(detail.transactions.single.currencyCode, 'BTC');
        expect(detail.transactions.single.amountScale, 12);
        expect(detail.transactions.single.amountAtoms, '1');
      },
    );

    test(
      'imported composite budget exposes exact totals and reviewable drill-down',
      () async {
        await db.accounts.insertOne(
          AccountsCompanion.insert(
            id: 'acc-usd',
            ownerUserId: 'usr-1',
            name: 'USD account',
            accountType: 'cash',
            currencyCode: const Value('USD'),
            currencyPrecision: const Value(4),
          ),
        );
        await db.budgetDefinitions.insertOne(
          BudgetDefinitionsCompanion.insert(
            id: 'imported-composite',
            ownerUserId: 'usr-1',
            name: const Value('Imported composite'),
            amountAtoms: '100000',
            amountScale: 4,
            currencyCode: 'USD',
            membershipMode: const Value('explicit_only'),
          ),
        );
        await db.transactions.insertOne(
          TransactionsCompanion.insert(
            id: 'txn-explicit',
            accountId: 'acc-usd',
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
            id: 'attached-transaction',
            budgetId: 'imported-composite',
            transactionId: const Value('txn-explicit'),
          ),
        );
        await db.budgetCategoryMemberships.insertOne(
          BudgetCategoryMembershipsCompanion.insert(
            id: 'missing-category',
            budgetId: 'imported-composite',
            sourceReference: const Value('redacted-reference'),
            reviewState: const Value('missing_reference'),
          ),
        );

        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWith((ref) => db)],
        );
        addTearDown(container.dispose);
        container.read(budgetMonthProvider.notifier).goTo(6);
        container.read(budgetYearProvider.notifier).goTo(2026);

        final budgets = await readAsyncValue(container, budgetsTabProvider);
        final imported = budgets.singleWhere(
          (budget) => budget.id == 'imported-composite',
        );
        expect(imported.name, 'Imported composite');
        expect(imported.currencyCode, 'USD');
        expect(imported.budgeted.toDecimalString(), '10.0000');
        expect(imported.spent.toDecimalString(), '1.2345');
        expect(imported.isReadOnly, isTrue);
        expect(imported.needsReview, isTrue);
        expect(imported.missingReferenceCount, 1);

        final detail = await readAsyncValue(
          container,
          importedBudgetDetailProvider(
            const ImportedBudgetRequest(
              id: 'imported-composite',
              year: 2026,
              month: 6,
            ),
          ),
        );
        expect(detail, isNotNull);
        expect(detail!.transactions.single.transaction.id, 'txn-explicit');
        expect(
          detail.transactions.single.inclusionReason,
          'Explicitly attached',
        );
      },
    );
  });
}

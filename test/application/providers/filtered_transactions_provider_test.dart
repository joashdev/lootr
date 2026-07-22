import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/filtered_transactions_provider.dart';
import 'package:lootr/application/providers/transaction_filters_provider.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/value_objects/date_range.dart';

Future<T?> readStreamValue<T>(
  StreamProvider<T> provider,
  ProviderContainer container,
) async {
  final completer = Completer<T?>();
  final subscription = container.listen(provider, (previous, next) {
    if (next.hasValue && !completer.isCompleted) {
      completer.complete(next.value);
    }
  });

  final result = await completer.future.timeout(
    const Duration(seconds: 5),
    onTimeout: () => null,
  );
  subscription.close();
  return result;
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.inMemory();

    await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
    await db.accounts.insertOne(
      AccountsCompanion.insert(
        id: 'acc-1',
        ownerUserId: 'usr-1',
        name: 'Cash',
        accountType: 'cash',
        balance: const Value(1000),
      ),
    );
    await db.accounts.insertOne(
      AccountsCompanion.insert(
        id: 'acc-eur',
        ownerUserId: 'usr-1',
        name: 'Euro account',
        accountType: 'bank',
        currencyCode: const Value('EUR'),
        currencyPrecision: const Value(4),
      ),
    );
    await db.categories.insertOne(
      CategoriesCompanion.insert(
        id: 'cat-food',
        name: 'Food',
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
    await db.payees.insertOne(
      PayeesCompanion.insert(
        id: 'pay-cafe',
        normalizedName: 'cafe manila',
        displayName: const Value('Café Manila'),
      ),
    );
    await db.payees.insertOne(
      PayeesCompanion.insert(
        id: 'pay-employer',
        normalizedName: 'acme payroll',
        displayName: const Value('ACME Payroll'),
      ),
    );

    await db.transactions.insertOne(
      TransactionsCompanion.insert(
        id: 'txn-coffee',
        accountId: 'acc-1',
        categoryId: const Value('cat-food'),
        payeeId: const Value('pay-cafe'),
        amount: 100.0,
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        note: const Value('Morning brew'),
        occurredAt: DateTime(2026, 6, 20, 9),
      ),
    );
    await db.transfers.insertOne(
      TransfersCompanion.insert(
        id: 'transfer-cross-currency',
        sourceAccountId: 'acc-1',
        destinationAccountId: 'acc-eur',
        amount: 100,
        sourceAmountAtoms: const Value('10000'),
        sourceAmountScale: const Value(2),
        sourceCurrencyCode: const Value('PHP'),
        destinationAmountAtoms: const Value('15000'),
        destinationAmountScale: const Value(4),
        destinationCurrencyCode: const Value('EUR'),
        occurredAt: DateTime(2026, 6, 21, 12),
      ),
    );
    await db.transactions.insertOne(
      TransactionsCompanion.insert(
        id: 'txn-bonus',
        accountId: 'acc-1',
        categoryId: const Value('cat-income'),
        payeeId: const Value('pay-employer'),
        amount: 2500.0,
        transactionDirection: 'income',
        transactionMode: 'one_time',
        note: const Value('Monthly bonus'),
        occurredAt: DateTime(2026, 6, 19, 10),
      ),
    );
    await db.transactions.insertOne(
      TransactionsCompanion.insert(
        id: 'txn-rent',
        accountId: 'acc-1',
        categoryId: const Value('cat-food'),
        amount: 900.0,
        transactionDirection: 'expense',
        transactionMode: 'recurring',
        title: const Value('Preserved landlord'),
        note: const Value('June rent'),
        occurredAt: DateTime(2026, 6, 1, 12),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('filteredTransactionsProvider', () {
    test('matches payee names accent-insensitively and by amount', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);

      container.read(transactionSearchQueryProvider.notifier).setQuery('cafe');
      final cafeResults = await readStreamValue(
        filteredTransactionsProvider,
        container,
      );

      expect(cafeResults?.map((item) => item.id), ['txn-coffee']);

      container.read(transactionSearchQueryProvider.notifier).setQuery('2500');
      final amountResults = await readStreamValue(
        filteredTransactionsProvider,
        container,
      );

      expect(amountResults?.map((item) => item.id), ['txn-bonus']);

      container
          .read(transactionSearchQueryProvider.notifier)
          .setQuery('preserved landlord');
      final titleResults = await readStreamValue(
        filteredTransactionsProvider,
        container,
      );

      expect(titleResults?.map((item) => item.id), ['txn-rent']);
    });

    test('composes active filters with search using AND logic', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);

      container
          .read(transactionFiltersProvider.notifier)
          .setDirection('expense');
      container
          .read(transactionFiltersProvider.notifier)
          .setCategoryId('cat-food');
      container.read(transactionSearchQueryProvider.notifier).setQuery('rent');

      final matchingResults = await readStreamValue(
        filteredTransactionsProvider,
        container,
      );
      expect(matchingResults?.map((item) => item.id), ['txn-rent']);

      container
          .read(transactionFiltersProvider.notifier)
          .setDirection('income');
      final emptyResults = await readStreamValue(
        filteredTransactionsProvider,
        container,
      );

      expect(emptyResults, isEmpty);
    });

    test('rebuilds when date and amount filters change', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);

      container
          .read(transactionFiltersProvider.notifier)
          .setExactAmountRange(
            currencyCode: 'PHP',
            minCoefficient: '5000',
            minScale: 2,
            maxCoefficient: '15000',
            maxScale: 2,
          );
      container
          .read(transactionFiltersProvider.notifier)
          .setDateRange(
            DateRange(
              DateTime(2026, 6, 20),
              DateTime(2026, 6, 20, 23, 59, 59, 999),
            ),
          );

      final results = await readStreamValue(
        filteredTransactionsProvider,
        container,
      );

      expect(results?.map((item) => item.id), ['txn-coffee']);
    });

    test(
      'filters a cross-currency transfer by its selected account leg',
      () async {
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWith((ref) => db)],
        );
        addTearDown(container.dispose);

        container
            .read(transactionFiltersProvider.notifier)
            .setAccountId('acc-eur');
        container
            .read(transactionFiltersProvider.notifier)
            .setExactAmountRange(
              currencyCode: 'EUR',
              minCoefficient: '14000',
              minScale: 4,
              maxCoefficient: '16000',
              maxScale: 4,
            );

        final destinationResults = await readStreamValue(
          filteredTransactionsProvider,
          container,
        );
        expect(destinationResults?.map((item) => item.id), [
          'transfer-cross-currency',
        ]);

        container
            .read(transactionFiltersProvider.notifier)
            .setAccountId('acc-1');
        final sourceResults = await readStreamValue(
          filteredTransactionsProvider,
          container,
        );
        expect(sourceResults, isEmpty);
      },
    );
  });
}

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/currency_totals_provider.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/data/database/app_database.dart';

void main() {
  test('dashboard totals expose one exact partition per currency', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    await database.users.insertOne(UsersCompanion.insert(id: 'user'));
    await database.accounts.insertAll([
      AccountsCompanion.insert(
        id: 'php',
        ownerUserId: 'user',
        name: 'PHP',
        accountType: 'bank',
        balance: const Value(1),
        balanceAtoms: const Value('100'),
        currencyPrecision: const Value(2),
        currencyCode: const Value('PHP'),
      ),
      AccountsCompanion.insert(
        id: 'btc',
        ownerUserId: 'user',
        name: 'BTC',
        accountType: 'bank',
        balance: const Value(0),
        balanceAtoms: const Value('1'),
        currencyPrecision: const Value(12),
        currencyCode: const Value('BTC'),
      ),
    ]);
    final now = DateTime.now();
    await database.transactions.insertAll([
      TransactionsCompanion.insert(
        id: 'php-income',
        accountId: 'php',
        amount: 0.01,
        amountAtoms: const Value('1'),
        amountScale: const Value(2),
        currencyCode: const Value('PHP'),
        transactionDirection: 'income',
        transactionMode: 'one_time',
        occurredAt: now,
      ),
      TransactionsCompanion.insert(
        id: 'btc-expense',
        accountId: 'btc',
        amount: 0,
        amountAtoms: const Value('1'),
        amountScale: const Value(12),
        currencyCode: const Value('BTC'),
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        occurredAt: now,
      ),
    ]);

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    final completer = Completer<List<DashboardCurrencyPartition>>();
    final subscription = container.listen(dashboardCurrencyTotalsProvider, (
      _,
      value,
    ) {
      if (value.hasValue && !completer.isCompleted) {
        completer.complete(value.requireValue);
      }
    }, fireImmediately: true);
    addTearDown(subscription.close);

    final partitions = await completer.future.timeout(
      const Duration(seconds: 5),
    );
    expect(partitions.map((partition) => partition.currencyCode), [
      'BTC',
      'PHP',
    ]);
    expect(
      partitions.first.balance.netWorth.toDecimalString(),
      '0.000000000001',
    );
    expect(
      partitions.first.monthlyFlow.expense.toDecimalString(),
      '0.000000000001',
    );
    expect(partitions.last.balance.netWorth.toDecimalString(), '1.00');
    expect(partitions.last.monthlyFlow.income.toDecimalString(), '0.01');
  });
}

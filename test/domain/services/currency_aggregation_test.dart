import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/domain/entities/account.dart';
import 'package:lootr/domain/entities/transaction.dart';
import 'package:lootr/domain/services/currency_aggregation.dart';

void main() {
  final timestamp = DateTime(2026, 7, 18);

  Transaction transaction({
    required String id,
    required String currency,
    required String atoms,
    required int scale,
    required String direction,
  }) {
    return Transaction(
      id: id,
      accountId: 'account-$currency',
      amount: 0,
      amountAtoms: atoms,
      amountScale: scale,
      currencyCode: currency,
      direction: direction,
      mode: 'one_time',
      occurredAt: timestamp,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  Account account({
    required String id,
    required String currency,
    required String atoms,
    required int scale,
    String type = 'bank',
  }) {
    return Account(
      id: id,
      ownerUserId: 'user',
      name: id,
      accountType: type,
      balance: 0,
      currencyCode: currency,
      balanceAtoms: atoms,
      currencyPrecision: scale,
      isArchived: false,
      isHidden: false,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  test('mixed-currency flows are exact and never form a grand total', () {
    final grouped = CurrencyAggregation.flows([
      transaction(
        id: 'php-income',
        currency: 'PHP',
        atoms: '10001',
        scale: 2,
        direction: 'income',
      ),
      transaction(
        id: 'php-expense',
        currency: 'PHP',
        atoms: '1',
        scale: 2,
        direction: 'expense',
      ),
      transaction(
        id: 'btc-expense',
        currency: 'BTC',
        atoms: '1',
        scale: 12,
        direction: 'expense',
      ),
    ]);

    expect(grouped.keys, unorderedEquals(['PHP', 'BTC']));
    expect(grouped['PHP']!.net.toDecimalString(), '100.00');
    expect(grouped['BTC']!.expense.toDecimalString(), '0.000000000001');
  });

  test('asset and liability balances stay partitioned by currency', () {
    final grouped = CurrencyAggregation.balances([
      account(id: 'php-asset', currency: 'PHP', atoms: '150005', scale: 2),
      account(
        id: 'php-liability',
        currency: 'PHP',
        atoms: '50000',
        scale: 2,
        type: 'loan',
      ),
      account(id: 'precision-four', currency: 'CLF', atoms: '1', scale: 4),
    ], isLiability: (type) => type == 'loan');

    expect(grouped['PHP']!.netWorth.toDecimalString(), '1000.05');
    expect(grouped['CLF']!.netWorth.toDecimalString(), '0.0001');
  });
}

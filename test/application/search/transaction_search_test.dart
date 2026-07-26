import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/search/transaction_search.dart';
import 'package:lootr/domain/entities/payee.dart';
import 'package:lootr/domain/entities/transaction.dart';

void main() {
  final transaction = Transaction(
    id: 'txn-1',
    accountId: 'account-1',
    payeeId: 'payee-1',
    amount: 1250.5,
    amountAtoms: '125050',
    amountScale: 2,
    currencyCode: 'PHP',
    title: 'Team lunch',
    direction: 'expense',
    mode: 'one_time',
    note: 'Client planning',
    occurredAt: DateTime(2026, 6, 18),
    createdAt: DateTime(2026, 6, 18),
    updatedAt: DateTime(2026, 6, 18),
  );
  final payee = Payee(
    id: 'payee-1',
    normalizedName: 'cafe manila',
    displayName: 'Café Manila',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('recognizes full month names and YYYY-MM deterministically', () {
    expect(TransactionSearch.parse('June').matches(transaction, payee), isTrue);
    expect(
      TransactionSearch.parse('June 2026').matches(transaction, payee),
      isTrue,
    );
    expect(
      TransactionSearch.parse('2026-06').matches(transaction, payee),
      isTrue,
    );
    expect(
      TransactionSearch.parse('2026-07').matches(transaction, payee),
      isFalse,
    );
  });

  test('requires explicit currency for an exact decimal constraint', () {
    expect(
      TransactionSearch.parse('PHP 1250.50').matches(transaction, payee),
      isTrue,
    );
    expect(
      TransactionSearch.parse('1250.50 PHP').matches(transaction, payee),
      isTrue,
    );
    expect(
      TransactionSearch.parse('USD 1250.50').matches(transaction, payee),
      isFalse,
    );
    expect(
      TransactionSearch.parse('PHP 1250.51').matches(transaction, payee),
      isFalse,
    );
  });

  test(
    'recognized constraints and remaining text compose with AND semantics',
    () {
      expect(
        TransactionSearch.parse(
          'cafe June 2026 1250.50 PHP',
        ).matches(transaction, payee),
        isTrue,
      );
      expect(
        TransactionSearch.parse(
          'groceries June 2026 1250.50 PHP',
        ).matches(transaction, payee),
        isFalse,
      );
    },
  );

  test('preserves unqualified amount and phrase search compatibility', () {
    expect(
      TransactionSearch.parse('1250.50').matches(transaction, payee),
      isTrue,
    );
    expect(
      TransactionSearch.parse('team lunch').matches(transaction, payee),
      isTrue,
    );
  });
}

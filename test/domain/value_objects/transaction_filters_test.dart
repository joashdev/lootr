import 'package:test/test.dart';
import 'package:lootr/domain/entities/transaction.dart';
import 'package:lootr/domain/value_objects/date_range.dart';
import 'package:lootr/domain/value_objects/transaction_filters.dart';

void main() {
  final now = DateTime.now();
  final jan1 = DateTime(2026, 1, 1);
  final jan31 = DateTime(2026, 1, 31);

  Transaction makeTx({
    String id = 'tx-1',
    String accountId = 'acc-1',
    String? categoryId,
    double amount = 100,
    String? amountAtoms,
    int? amountScale,
    String? currencyCode,
    String direction = 'expense',
    String mode = 'one_time',
    DateTime? occurredAt,
  }) {
    return Transaction(
      id: id,
      accountId: accountId,
      categoryId: categoryId,
      amount: amount,
      amountAtoms: amountAtoms,
      amountScale: amountScale,
      currencyCode: currencyCode,
      direction: direction,
      mode: mode,
      occurredAt: occurredAt ?? now,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('TransactionFilters', () {
    group('isEmpty', () {
      test('should return true for default filters', () {
        const filters = TransactionFilters();
        expect(filters.isEmpty, isTrue);
      });

      test('should return false when direction is set', () {
        const filters = TransactionFilters(directions: ['expense']);
        expect(filters.isEmpty, isFalse);
      });

      test('should return false when mode is set', () {
        const filters = TransactionFilters(modes: ['recurring']);
        expect(filters.isEmpty, isFalse);
      });

      test('should return false when accountId is set', () {
        const filters = TransactionFilters(accountIds: ['acc-1']);
        expect(filters.isEmpty, isFalse);
      });

      test('should return false when categoryId is set', () {
        const filters = TransactionFilters(categoryIds: ['cat-1']);
        expect(filters.isEmpty, isFalse);
      });

      test('should return false when amount range is set', () {
        const filters = TransactionFilters(
          currencyCode: 'PHP',
          minAmountCoefficient: '5000',
          minAmountScale: 2,
        );
        expect(filters.isEmpty, isFalse);
      });

      test('should return false when currency is set', () {
        const filters = TransactionFilters(currencyCode: 'BTC');
        expect(filters.isEmpty, isFalse);
      });

      test('should return false when dateRange is set', () {
        final filters = TransactionFilters(dateRange: DateRange(jan1, jan31));
        expect(filters.isEmpty, isFalse);
      });
    });

    group('apply', () {
      test('empty filters should return all transactions', () {
        final txs = [
          makeTx(id: '1', direction: 'expense'),
          makeTx(id: '2', direction: 'income'),
        ];
        const filters = TransactionFilters();
        expect(filters.apply(txs).length, 2);
      });

      test('should filter by direction', () {
        final txs = [
          makeTx(id: '1', direction: 'expense'),
          makeTx(id: '2', direction: 'income'),
          makeTx(id: '3', direction: 'expense'),
        ];
        const filters = TransactionFilters(directions: ['expense']);
        final result = filters.apply(txs);
        expect(result.length, 2);
        expect(result.every((t) => t.direction == 'expense'), isTrue);
      });

      test('should filter by mode', () {
        final txs = [
          makeTx(id: '1', mode: 'one_time'),
          makeTx(id: '2', mode: 'recurring'),
          makeTx(id: '3', mode: 'one_time'),
        ];
        const filters = TransactionFilters(modes: ['recurring']);
        final result = filters.apply(txs);
        expect(result.length, 1);
        expect(result.first.id, '2');
      });

      test('should filter by accountId', () {
        final txs = [
          makeTx(id: '1', accountId: 'acc-1'),
          makeTx(id: '2', accountId: 'acc-2'),
        ];
        const filters = TransactionFilters(accountIds: ['acc-1']);
        final result = filters.apply(txs);
        expect(result.length, 1);
        expect(result.first.accountId, 'acc-1');
      });

      test('should filter by categoryId', () {
        final txs = [
          makeTx(id: '1', categoryId: 'cat-1'),
          makeTx(id: '2', categoryId: 'cat-2'),
          makeTx(id: '3', categoryId: null),
        ];
        const filters = TransactionFilters(categoryIds: ['cat-1']);
        final result = filters.apply(txs);
        expect(result.length, 1);
        expect(result.first.categoryId, 'cat-1');
      });

      test('should filter by currency-qualified minimum amount', () {
        final txs = [
          makeTx(id: '1', amount: 50),
          makeTx(id: '2', amount: 100),
          makeTx(id: '3', amount: 150),
        ];
        const filters = TransactionFilters(
          currencyCode: 'PHP',
          minAmountCoefficient: '10000',
          minAmountScale: 2,
        );
        final result = filters.apply(txs);
        expect(result.length, 2);
        expect(result.every((t) => t.amount >= 100), isTrue);
      });

      test('should filter by currency-qualified maximum amount', () {
        final txs = [
          makeTx(id: '1', amount: 50),
          makeTx(id: '2', amount: 100),
          makeTx(id: '3', amount: 150),
        ];
        const filters = TransactionFilters(
          currencyCode: 'PHP',
          maxAmountCoefficient: '10000',
          maxAmountScale: 2,
        );
        final result = filters.apply(txs);
        expect(result.length, 2);
        expect(result.every((t) => t.amount <= 100), isTrue);
      });

      test('filters exact values without a double conversion', () {
        final txs = [
          makeTx(
            id: 'below',
            amount: 1,
            amountAtoms: '999999999999',
            amountScale: 12,
            currencyCode: 'XTS',
          ),
          makeTx(
            id: 'boundary',
            amount: 1,
            amountAtoms: '1000000000000',
            amountScale: 12,
            currencyCode: 'XTS',
          ),
          makeTx(
            id: 'other-currency',
            amount: 1,
            amountAtoms: '1000000000000',
            amountScale: 12,
            currencyCode: 'BTC',
          ),
        ];
        const filters = TransactionFilters(
          currencyCode: 'XTS',
          minAmountCoefficient: '1000000000000',
          minAmountScale: 12,
        );

        expect(filters.apply(txs).map((t) => t.id), ['boundary']);
      });

      test('compares exact bounds across different scales', () {
        final txs = [
          makeTx(
            id: 'same-value',
            amount: 1,
            amountAtoms: '10000',
            amountScale: 4,
            currencyCode: 'CLF',
          ),
          makeTx(
            id: 'above',
            amount: 1.0001,
            amountAtoms: '10001',
            amountScale: 4,
            currencyCode: 'CLF',
          ),
        ];
        const filters = TransactionFilters(
          currencyCode: 'CLF',
          maxAmountCoefficient: '100',
          maxAmountScale: 2,
        );

        expect(filters.apply(txs).map((t) => t.id), ['same-value']);
      });

      test('should filter by dateRange', () {
        final txs = [
          makeTx(id: '1', occurredAt: DateTime(2026, 1, 5)),
          makeTx(id: '2', occurredAt: DateTime(2026, 1, 15)),
          makeTx(id: '3', occurredAt: DateTime(2026, 2, 1)),
        ];
        final filters = TransactionFilters(dateRange: DateRange(jan1, jan31));
        final result = filters.apply(txs);
        expect(result.length, 2);
        expect(result.map((t) => t.id).toList(), ['1', '2']);
      });

      test('should combine multiple filters', () {
        final txs = [
          makeTx(id: '1', direction: 'expense', mode: 'one_time', amount: 50),
          makeTx(id: '2', direction: 'expense', mode: 'recurring', amount: 100),
          makeTx(id: '3', direction: 'income', mode: 'one_time', amount: 100),
          makeTx(id: '4', direction: 'expense', mode: 'one_time', amount: 150),
        ];
        const filters = TransactionFilters(
          directions: ['expense'],
          modes: ['one_time'],
          currencyCode: 'PHP',
          minAmountCoefficient: '5000',
          minAmountScale: 2,
          maxAmountCoefficient: '15000',
          maxAmountScale: 2,
        );
        final result = filters.apply(txs);
        expect(result.length, 2);
        expect(result.map((t) => t.id).toList(), ['1', '4']);
      });
    });

    group('equality', () {
      test('should equal same filters', () {
        const a = TransactionFilters(
          directions: ['expense'],
          modes: ['one_time'],
        );
        const b = TransactionFilters(
          directions: ['expense'],
          modes: ['one_time'],
        );
        expect(a, equals(b));
      });

      test('should not equal different filters', () {
        const a = TransactionFilters(directions: ['expense']);
        const b = TransactionFilters(directions: ['income']);
        expect(a, isNot(equals(b)));
      });

      test('should support multiple selections per group', () {
        const filters = TransactionFilters(
          directions: ['expense', 'income'],
          accountIds: ['acc-1', 'acc-2'],
        );
        expect(filters.direction, 'expense');
        expect(filters.accountId, 'acc-1');
        expect(filters.activeCount, 4);
      });
    });
  });
}

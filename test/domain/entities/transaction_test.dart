import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/domain/entities/transaction.dart';

void main() {
  final now = DateTime.now();

  group('Transaction', () {
    test('should construct with all fields', () {
      final tx = Transaction(
        id: 'tx-1',
        accountId: 'acc-1',
        categoryId: 'cat-1',
        payeeId: 'pay-1',
        parentTransactionId: 'parent-1',
        recurringTemplateId: 'rt-1',
        amount: 100.50,
        direction: 'expense',
        mode: 'one_time',
        subtype: 'salary',
        note: 'Test transaction',
        metadata: {'key': 'value'},
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(tx.id, 'tx-1');
      expect(tx.accountId, 'acc-1');
      expect(tx.categoryId, 'cat-1');
      expect(tx.payeeId, 'pay-1');
      expect(tx.parentTransactionId, 'parent-1');
      expect(tx.recurringTemplateId, 'rt-1');
      expect(tx.amount, 100.50);
      expect(tx.direction, 'expense');
      expect(tx.mode, 'one_time');
      expect(tx.subtype, 'salary');
      expect(tx.note, 'Test transaction');
      expect(tx.metadata, {'key': 'value'});
      expect(tx.occurredAt, now);
      expect(tx.createdAt, now);
      expect(tx.updatedAt, now);
      expect(tx.deletedAt, isNull);
    });

    test('should be equatable', () {
      final a = Transaction(
        id: 'tx-1',
        accountId: 'acc-1',
        amount: 100,
        direction: 'expense',
        mode: 'one_time',
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final b = Transaction(
        id: 'tx-1',
        accountId: 'acc-1',
        amount: 100,
        direction: 'expense',
        mode: 'one_time',
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('should not equal different transactions', () {
      final a = Transaction(
        id: 'tx-1',
        accountId: 'acc-1',
        amount: 100,
        direction: 'expense',
        mode: 'one_time',
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final b = Transaction(
        id: 'tx-2',
        accountId: 'acc-1',
        amount: 100,
        direction: 'expense',
        mode: 'one_time',
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(a, isNot(equals(b)));
    });

    test('copyWith should create new instance with updated fields', () {
      final tx = Transaction(
        id: 'tx-1',
        accountId: 'acc-1',
        amount: 100,
        direction: 'expense',
        mode: 'one_time',
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final updated = tx.copyWith(amount: 200, direction: 'income');

      expect(updated.id, tx.id);
      expect(updated.amount, 200);
      expect(updated.direction, 'income');
      expect(updated.mode, tx.mode);
    });

    test('copyWith should set nullable fields to null', () {
      final tx = Transaction(
        id: 'tx-1',
        accountId: 'acc-1',
        amount: 100,
        direction: 'expense',
        mode: 'one_time',
        categoryId: 'cat-1',
        note: 'old note',
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final updated = tx.copyWith(
        categoryId: () => null,
        note: () => null,
      );

      expect(updated.categoryId, isNull);
      expect(updated.note, isNull);
      expect(updated.amount, tx.amount);
    });

    test('JSON round-trip', () {
      final tx = Transaction(
        id: 'tx-1',
        accountId: 'acc-1',
        amount: 100,
        direction: 'expense',
        mode: 'one_time',
        note: 'test',
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final json = tx.toJson();
      final rebuilt = Transaction.fromJson(json);

      expect(rebuilt, equals(tx));
    });

    test('nullable fields in JSON round-trip', () {
      final tx = Transaction(
        id: 'tx-1',
        accountId: 'acc-1',
        amount: 100,
        direction: 'expense',
        mode: 'one_time',
        categoryId: 'cat-1',
        payeeId: 'pay-1',
        note: 'note',
        metadata: {'key': 'value'},
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
        deletedAt: now,
      );

      final json = tx.toJson();
      final rebuilt = Transaction.fromJson(json);

      expect(rebuilt, equals(tx));
    });
  });
}

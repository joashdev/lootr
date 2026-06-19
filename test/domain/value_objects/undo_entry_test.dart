import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/domain/value_objects/undo_entry.dart';

void main() {
  group('UndoEntry', () {
    test('should construct with required fields', () {
      final now = DateTime.now();
      final entry = UndoEntry(
        transactionId: 'tx-1',
        message: 'Undo this transaction',
        rollback: () async {},
        createdAt: now,
      );

      expect(entry.transactionId, 'tx-1');
      expect(entry.message, 'Undo this transaction');
      expect(entry.createdAt, now);
    });

    test('rollback callback should be invocable', () async {
      var called = false;
      final entry = UndoEntry(
        transactionId: 'tx-1',
        message: 'Test',
        rollback: () async => called = true,
        createdAt: DateTime.now(),
      );

      await entry.rollback();
      expect(called, isTrue);
    });

    test('should equal same values', () {
      final now = DateTime.now();
      final a = UndoEntry(
        transactionId: 'tx-1',
        message: 'test',
        rollback: () async {},
        createdAt: now,
      );
      final b = UndoEntry(
        transactionId: 'tx-1',
        message: 'test',
        rollback: () async {},
        createdAt: now,
      );
      expect(a, equals(b));
    });

    test('should not equal different transactionId', () {
      final now = DateTime.now();
      final a = UndoEntry(
        transactionId: 'tx-1',
        message: 'test',
        rollback: () async {},
        createdAt: now,
      );
      final b = UndoEntry(
        transactionId: 'tx-2',
        message: 'test',
        rollback: () async {},
        createdAt: now,
      );
      expect(a, isNot(equals(b)));
    });

    test('hashCode should be consistent', () {
      final now = DateTime.now();
      final a = UndoEntry(
        transactionId: 'tx-1',
        message: 'test',
        rollback: () async {},
        createdAt: now,
      );
      final b = UndoEntry(
        transactionId: 'tx-1',
        message: 'test',
        rollback: () async {},
        createdAt: now,
      );
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart';
import 'package:lootr/data/repositories/transaction_repo.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/use_cases/delete_transaction.dart';
import 'package:lootr/domain/value_objects/result.dart';
import 'package:lootr/domain/value_objects/undo_entry.dart';

class MockTransactionRepo extends Mock implements TransactionRepo {}

void main() {
  late MockTransactionRepo mockRepo;
  late DeleteTransaction useCase;

  setUpAll(() {
    registerFallbackValue(TransactionsCompanion(
      id: const Value(''),
      accountId: const Value(''),
      amount: const Value(0),
      transactionDirection: const Value('expense'),
      transactionMode: const Value('one_time'),
      occurredAt: Value(DateTime.now()),
    ));
  });

  final testTransaction = TransactionData(
    id: 'txn-1',
    accountId: 'acc-1',
    amount: 100,
    transactionDirection: 'expense',
    transactionMode: 'one_time',
    syncStatus: 'local_only',
    occurredAt: DateTime(2026, 6, 19),
    createdAt: DateTime(2026, 6, 19),
    updatedAt: DateTime(2026, 6, 19),
  );

  setUp(() {
    mockRepo = MockTransactionRepo();
    useCase = DeleteTransaction(mockRepo);
  });

  group('DeleteTransaction', () {
    test('should return Failure when transaction not found', () async {
      when(() => mockRepo.watchById('txn-1'))
          .thenAnswer((_) => Stream.value(null));

      final result = await useCase('txn-1');

      expect(result.isFailure, isTrue);
      final failure = result as Failure<UndoEntry>;
      expect(failure.code, 'not_found');
    });

    test('should return Success with UndoEntry on valid delete', () async {
      when(() => mockRepo.watchById('txn-1'))
          .thenAnswer((_) => Stream.value(testTransaction));
      when(() => mockRepo.softDelete('txn-1')).thenAnswer((_) async {});
      when(() => mockRepo.create(any())).thenAnswer((_) async => 'restored-1');

      final result = await useCase('txn-1');

      expect(result.isSuccess, isTrue);
      final success = result as Success<UndoEntry>;
      expect(success.value.transactionId, 'txn-1');
      expect(success.value.message, 'Transaction deleted');
    });

    test('should restore transaction on undo with new id', () async {
      when(() => mockRepo.watchById('txn-1'))
          .thenAnswer((_) => Stream.value(testTransaction));
      when(() => mockRepo.softDelete('txn-1')).thenAnswer((_) async {});
      when(() => mockRepo.create(any())).thenAnswer((_) async => 'restored-1');

      final result = await useCase('txn-1');
      final entry = (result as Success<UndoEntry>).value;

      await entry.rollback();

      verify(() => mockRepo.create(any())).called(1);
    });

    test('should return Failure when softDelete throws', () async {
      when(() => mockRepo.watchById('txn-1'))
          .thenAnswer((_) => Stream.value(testTransaction));
      when(() => mockRepo.softDelete('txn-1'))
          .thenThrow(Exception('DB error'));

      final result = await useCase('txn-1');

      expect(result.isFailure, isTrue);
      final failure = result as Failure<UndoEntry>;
      expect(failure.code, 'delete_error');
    });
  });
}

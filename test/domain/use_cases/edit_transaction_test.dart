import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart';
import 'package:lootr/data/repositories/transaction_repo.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/entities/transaction.dart';
import 'package:lootr/domain/use_cases/edit_transaction.dart';
import 'package:lootr/domain/value_objects/result.dart';

class MockTransactionRepo extends Mock implements TransactionRepo {}

void main() {
  late MockTransactionRepo mockRepo;
  late EditTransaction useCase;

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

  final testTransaction = Transaction(
    id: 'txn-1',
    accountId: 'acc-1',
    amount: 200,
    direction: 'expense',
    mode: 'one_time',
    occurredAt: DateTime(2026, 6, 19),
    createdAt: DateTime(2026, 6, 19),
    updatedAt: DateTime(2026, 6, 19),
  );

  final testOriginal = TransactionData(
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
    useCase = EditTransaction(mockRepo);
  });

  group('EditTransaction', () {
    test('should return Failure when amount is zero', () async {
      final tx = testTransaction.copyWith(amount: 0);

      final result = await useCase(tx);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<void>;
      expect(failure.code, 'invalid_amount');
    });

    test('should return Failure for invalid direction', () async {
      final tx = testTransaction.copyWith(direction: 'invalid');

      final result = await useCase(tx);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<void>;
      expect(failure.code, 'invalid_direction');
    });

    test('should return Failure when transaction not found', () async {
      when(() => mockRepo.watchById('txn-1'))
          .thenAnswer((_) => Stream.value(null));

      final result = await useCase(testTransaction);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<void>;
      expect(failure.code, 'not_found');
    });

    test('should return Success on valid update', () async {
      when(() => mockRepo.watchById('txn-1'))
          .thenAnswer((_) => Stream.value(testOriginal));
      when(() => mockRepo.update(any())).thenAnswer((_) async {});

      final result = await useCase(testTransaction);

      expect(result.isSuccess, isTrue);
    });

    test('should return Failure when repo throws', () async {
      when(() => mockRepo.watchById('txn-1'))
          .thenAnswer((_) => Stream.value(testOriginal));
      when(() => mockRepo.update(any()))
          .thenThrow(Exception('DB error'));

      final result = await useCase(testTransaction);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<void>;
      expect(failure.code, 'update_error');
    });
  });
}

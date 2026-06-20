import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart';
import 'package:lootr/data/repositories/transaction_repo.dart';
import 'package:lootr/data/repositories/account_repo.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/entities/transaction.dart';
import 'package:lootr/domain/use_cases/edit_transaction.dart';
import 'package:lootr/domain/value_objects/result.dart';

class MockTransactionRepo extends Mock implements TransactionRepo {}

class MockAccountRepo extends Mock implements AccountRepo {}

void main() {
  late MockTransactionRepo mockTxRepo;
  late MockAccountRepo mockAccountRepo;
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
    mockTxRepo = MockTransactionRepo();
    mockAccountRepo = MockAccountRepo();
    useCase = EditTransaction(mockTxRepo, mockAccountRepo);
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
      when(() => mockTxRepo.watchById('txn-1'))
          .thenAnswer((_) => Stream.value(null));

      final result = await useCase(testTransaction);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<void>;
      expect(failure.code, 'not_found');
    });

    test('should return Failure when transaction is soft-deleted', () async {
      final deleted = testOriginal.copyWith(deletedAt: Value(DateTime(2026, 1, 1)));
      when(() => mockTxRepo.watchById('txn-1'))
          .thenAnswer((_) => Stream.value(deleted));

      final result = await useCase(testTransaction);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<void>;
      expect(failure.code, 'transaction_deleted');
    });

    test('should return Failure when new account not found', () async {
      when(() => mockTxRepo.watchById('txn-1'))
          .thenAnswer((_) => Stream.value(testOriginal));
      when(() => mockAccountRepo.watchById('acc-2'))
          .thenAnswer((_) => Stream.value(null));

      final tx = testTransaction.copyWith(accountId: 'acc-2');
      final result = await useCase(tx);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<void>;
      expect(failure.code, 'account_not_found');
    });

    test('should return Success on valid update (same account)', () async {
      when(() => mockTxRepo.watchById('txn-1'))
          .thenAnswer((_) => Stream.value(testOriginal));
      when(() => mockTxRepo.update(any())).thenAnswer((_) async {});

      final result = await useCase(testTransaction);

      expect(result.isSuccess, isTrue);
    });

    test('should return Success on valid update (different account)', () async {
      final newAccount = AccountData(
        id: 'acc-2',
        ownerUserId: 'usr-1',
        name: 'Bank',
        accountType: 'bank',
        balance: 500,
        currencyCode: 'PHP',
        isArchived: false,
        isHidden: false,
        syncStatus: 'local_only',
        createdAt: DateTime(2026, 6, 19),
        updatedAt: DateTime(2026, 6, 19),
      );
      when(() => mockTxRepo.watchById('txn-1'))
          .thenAnswer((_) => Stream.value(testOriginal));
      when(() => mockAccountRepo.watchById('acc-2'))
          .thenAnswer((_) => Stream.value(newAccount));
      when(() => mockTxRepo.update(any())).thenAnswer((_) async {});

      final tx = testTransaction.copyWith(accountId: 'acc-2');
      final result = await useCase(tx);

      expect(result.isSuccess, isTrue);
    });

    test('should return Failure when repo throws', () async {
      when(() => mockTxRepo.watchById('txn-1'))
          .thenAnswer((_) => Stream.value(testOriginal));
      when(() => mockTxRepo.update(any()))
          .thenThrow(Exception('DB error'));

      final result = await useCase(testTransaction);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<void>;
      expect(failure.code, 'update_error');
    });
  });
}

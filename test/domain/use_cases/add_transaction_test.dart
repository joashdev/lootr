import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart';
import 'package:lootr/data/repositories/transaction_repo.dart';
import 'package:lootr/data/repositories/account_repo.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/entities/transaction.dart';
import 'package:lootr/domain/use_cases/add_transaction.dart';
import 'package:lootr/domain/value_objects/result.dart';

class MockTransactionRepo extends Mock implements TransactionRepo {}

class MockAccountRepo extends Mock implements AccountRepo {}

void main() {
  late MockTransactionRepo mockTransactionRepo;
  late MockAccountRepo mockAccountRepo;
  late AddTransaction useCase;

  setUpAll(() {
    registerFallbackValue(
      TransactionsCompanion(
        id: const Value(''),
        accountId: const Value(''),
        amount: const Value(0),
        transactionDirection: const Value('expense'),
        transactionMode: const Value('one_time'),
        occurredAt: Value(DateTime.now()),
      ),
    );
  });

  final testTransaction = Transaction(
    id: 'txn-1',
    accountId: 'acc-1',
    amount: 100,
    direction: 'expense',
    mode: 'one_time',
    occurredAt: DateTime(2026, 6, 19),
    createdAt: DateTime(2026, 6, 19),
    updatedAt: DateTime(2026, 6, 19),
  );

  final testAccount = AccountData(
    id: 'acc-1',
    ownerUserId: 'usr-1',
    name: 'GCash',
    accountType: 'ewallet',
    balance: 1000,
    currencyCode: 'PHP',
    isArchived: false,
    isHidden: false,
    syncStatus: 'local_only',
    createdAt: DateTime(2026, 6, 19),
    updatedAt: DateTime(2026, 6, 19),
  );

  setUp(() {
    mockTransactionRepo = MockTransactionRepo();
    mockAccountRepo = MockAccountRepo();
    useCase = AddTransaction(mockTransactionRepo, mockAccountRepo);
  });

  group('AddTransaction', () {
    test('should return Failure when amount is zero', () async {
      final tx = testTransaction.copyWith(amount: 0);

      final result = await useCase(tx);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<String>;
      expect(failure.code, 'invalid_amount');
    });

    test('should return Failure when amount is negative', () async {
      final tx = testTransaction.copyWith(amount: -50);

      final result = await useCase(tx);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<String>;
      expect(failure.code, 'invalid_amount');
    });

    test('should return Failure for invalid direction', () async {
      final tx = testTransaction.copyWith(direction: 'invalid');

      final result = await useCase(tx);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<String>;
      expect(failure.code, 'invalid_direction');
    });

    test('should return Failure when account not found', () async {
      when(
        () => mockAccountRepo.watchById('acc-1'),
      ).thenAnswer((_) => Stream.value(null));

      final result = await useCase(testTransaction);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<String>;
      expect(failure.code, 'account_not_found');
    });

    test('should return Failure when account is archived', () async {
      final archived = testAccount.copyWith(isArchived: true);
      when(
        () => mockAccountRepo.watchById('acc-1'),
      ).thenAnswer((_) => Stream.value(archived));

      final result = await useCase(testTransaction);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<String>;
      expect(failure.code, 'account_archived');
    });

    test('should return Failure when account is deleted', () async {
      final deleted = testAccount.copyWith(
        deletedAt: Value(DateTime(2026, 1, 1)),
      );
      when(
        () => mockAccountRepo.watchById('acc-1'),
      ).thenAnswer((_) => Stream.value(deleted));

      final result = await useCase(testTransaction);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<String>;
      expect(failure.code, 'account_deleted');
    });

    test('should return Success with id on valid transaction', () async {
      when(
        () => mockAccountRepo.watchById('acc-1'),
      ).thenAnswer((_) => Stream.value(testAccount));

      when(
        () => mockTransactionRepo.create(any()),
      ).thenAnswer((_) async => 'txn-1');

      final result = await useCase(testTransaction);

      expect(result.isSuccess, isTrue);
      final success = result as Success<String>;
      expect(success.value, 'txn-1');
    });

    test('should handle income transaction', () async {
      final tx = testTransaction.copyWith(direction: 'income');

      when(
        () => mockAccountRepo.watchById('acc-1'),
      ).thenAnswer((_) => Stream.value(testAccount));

      when(
        () => mockTransactionRepo.create(any()),
      ).thenAnswer((_) async => 'txn-2');

      final result = await useCase(tx);

      expect(result.isSuccess, isTrue);
    });
  });
}

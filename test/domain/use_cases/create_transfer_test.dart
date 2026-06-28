import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart';
import 'package:lootr/data/repositories/transfer_repo.dart';
import 'package:lootr/data/repositories/account_repo.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/entities/transfer.dart';
import 'package:lootr/domain/use_cases/create_transfer.dart';
import 'package:lootr/domain/value_objects/result.dart';

class MockTransferRepo extends Mock implements TransferRepo {}

class MockAccountRepo extends Mock implements AccountRepo {}

void main() {
  late MockTransferRepo mockTransferRepo;
  late MockAccountRepo mockAccountRepo;
  late CreateTransfer useCase;

  setUpAll(() {
    registerFallbackValue(
      TransfersCompanion(
        id: const Value(''),
        sourceAccountId: const Value(''),
        destinationAccountId: const Value(''),
        amount: const Value(0),
        occurredAt: Value(DateTime.now()),
      ),
    );
  });

  final testTransfer = Transfer(
    id: 'trf-1',
    sourceAccountId: 'acc-1',
    destinationAccountId: 'acc-2',
    amount: 500,
    occurredAt: DateTime(2026, 6, 19),
    createdAt: DateTime(2026, 6, 19),
    updatedAt: DateTime(2026, 6, 19),
  );

  final sourceAccount = AccountData(
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

  final destAccount = AccountData(
    id: 'acc-2',
    ownerUserId: 'usr-1',
    name: 'Bank',
    accountType: 'bank',
    balance: 2000,
    currencyCode: 'PHP',
    isArchived: false,
    isHidden: false,
    syncStatus: 'local_only',
    createdAt: DateTime(2026, 6, 19),
    updatedAt: DateTime(2026, 6, 19),
  );

  setUp(() {
    mockTransferRepo = MockTransferRepo();
    mockAccountRepo = MockAccountRepo();
    useCase = CreateTransfer(mockTransferRepo, mockAccountRepo);
  });

  group('CreateTransfer', () {
    test('should return Failure when source equals destination', () async {
      final trf = testTransfer.copyWith(
        sourceAccountId: 'acc-1',
        destinationAccountId: 'acc-1',
      );

      final result = await useCase(trf);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<String>;
      expect(failure.code, 'same_account');
    });

    test('should return Failure when amount is zero', () async {
      final trf = testTransfer.copyWith(amount: 0);

      final result = await useCase(trf);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<String>;
      expect(failure.code, 'invalid_amount');
    });

    test('should return Failure when source account not found', () async {
      when(
        () => mockAccountRepo.watchById('acc-1'),
      ).thenAnswer((_) => Stream.value(null));

      final result = await useCase(testTransfer);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<String>;
      expect(failure.code, 'source_not_found');
    });

    test('should return Failure when source account is archived', () async {
      final archived = sourceAccount.copyWith(isArchived: true);
      when(
        () => mockAccountRepo.watchById('acc-1'),
      ).thenAnswer((_) => Stream.value(archived));
      when(
        () => mockAccountRepo.watchById('acc-2'),
      ).thenAnswer((_) => Stream.value(destAccount));

      final result = await useCase(testTransfer);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<String>;
      expect(failure.code, 'source_archived');
    });

    test('should return Failure when destination account not found', () async {
      when(
        () => mockAccountRepo.watchById('acc-1'),
      ).thenAnswer((_) => Stream.value(sourceAccount));
      when(
        () => mockAccountRepo.watchById('acc-2'),
      ).thenAnswer((_) => Stream.value(null));

      final result = await useCase(testTransfer);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<String>;
      expect(failure.code, 'dest_not_found');
    });

    test('should return Failure when destination account is deleted', () async {
      final deleted = destAccount.copyWith(
        deletedAt: Value(DateTime(2026, 1, 1)),
      );
      when(
        () => mockAccountRepo.watchById('acc-1'),
      ).thenAnswer((_) => Stream.value(sourceAccount));
      when(
        () => mockAccountRepo.watchById('acc-2'),
      ).thenAnswer((_) => Stream.value(deleted));

      final result = await useCase(testTransfer);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<String>;
      expect(failure.code, 'dest_deleted');
    });

    test('should return Success with id on valid transfer', () async {
      when(
        () => mockAccountRepo.watchById('acc-1'),
      ).thenAnswer((_) => Stream.value(sourceAccount));
      when(
        () => mockAccountRepo.watchById('acc-2'),
      ).thenAnswer((_) => Stream.value(destAccount));
      when(
        () => mockTransferRepo.create(any()),
      ).thenAnswer((_) async => 'trf-1');

      final result = await useCase(testTransfer);

      expect(result.isSuccess, isTrue);
      final success = result as Success<String>;
      expect(success.value, 'trf-1');
    });
  });
}

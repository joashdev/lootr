import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart';
import 'package:lootr/data/repositories/transaction_repo.dart';
import 'package:lootr/data/repositories/recurring_repo.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/use_cases/advance_recurring.dart';
import 'package:lootr/domain/value_objects/result.dart';

class MockTransactionRepo extends Mock implements TransactionRepo {}

class MockRecurringRepo extends Mock implements RecurringRepo {}

void main() {
  late MockTransactionRepo mockTransactionRepo;
  late MockRecurringRepo mockRecurringRepo;
  late AdvanceRecurring useCase;

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

  final testTemplate = RecurringTemplateData(
    id: 'rec-1',
    accountId: 'acc-1',
    amount: 500,
    recurrenceRule: 'monthly',
    reminderEnabled: true,
    autoCreateDisabled: false,
    syncStatus: 'local_only',
    createdAt: DateTime(2026, 6, 19),
    updatedAt: DateTime(2026, 6, 19),
  );

  setUp(() {
    mockTransactionRepo = MockTransactionRepo();
    mockRecurringRepo = MockRecurringRepo();
    useCase = AdvanceRecurring(mockTransactionRepo, mockRecurringRepo);
  });

  group('AdvanceRecurring', () {
    test('should return Failure when template not found', () async {
      when(
        () => mockRecurringRepo.watchById('rec-1'),
      ).thenAnswer((_) => Stream.value(null));

      final result = await useCase('rec-1');

      expect(result.isFailure, isTrue);
      final failure = result as Failure<void>;
      expect(failure.code, 'not_found');
    });

    test('should create transaction and advance occurrence', () async {
      when(
        () => mockRecurringRepo.watchById('rec-1'),
      ).thenAnswer((_) => Stream.value(testTemplate));
      when(
        () => mockTransactionRepo.create(any()),
      ).thenAnswer((_) async => 'txn-1');
      when(
        () => mockRecurringRepo.advanceNextOccurrence('rec-1'),
      ).thenAnswer((_) async {});

      final result = await useCase('rec-1');

      expect(result.isSuccess, isTrue);
      verify(() => mockTransactionRepo.create(any())).called(1);
      verify(() => mockRecurringRepo.advanceNextOccurrence('rec-1')).called(1);
    });
  });
}

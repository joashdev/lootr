import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart';
import 'package:lootr/data/repositories/budget_repo.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/entities/budget.dart';
import 'package:lootr/domain/use_cases/add_budget.dart';
import 'package:lootr/domain/value_objects/result.dart';

class MockBudgetRepo extends Mock implements BudgetRepo {}

void main() {
  late MockBudgetRepo mockRepo;
  late AddBudget useCase;

  setUpAll(() {
    registerFallbackValue(BudgetsCompanion(
      id: const Value(''),
      ownerUserId: const Value(''),
      categoryId: const Value(''),
      amount: const Value(0),
      month: const Value(1),
      year: const Value(2026),
    ));
  });

  final testBudget = Budget(
    id: 'bdg-1',
    ownerUserId: 'usr-1',
    categoryId: 'cat-1',
    amount: 5000,
    month: 6,
    year: 2026,
    createdAt: DateTime(2026, 6, 19),
    updatedAt: DateTime(2026, 6, 19),
  );

  setUp(() {
    mockRepo = MockBudgetRepo();
    useCase = AddBudget(mockRepo);
  });

  group('AddBudget', () {
    test('should return Failure for invalid month (0)', () async {
      final b = testBudget.copyWith(month: 0);

      final result = await useCase(b);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<String>;
      expect(failure.code, 'invalid_month');
    });

    test('should return Failure for invalid month (13)', () async {
      final b = testBudget.copyWith(month: 13);

      final result = await useCase(b);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<String>;
      expect(failure.code, 'invalid_month');
    });

    test('should return Failure when amount is zero', () async {
      final b = testBudget.copyWith(amount: 0);

      final result = await useCase(b);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<String>;
      expect(failure.code, 'invalid_amount');
    });

    test('should return Failure for duplicate budget', () async {
      final existing = BudgetData(
        id: 'bdg-0',
        ownerUserId: 'usr-1',
        categoryId: 'cat-1',
        amount: 3000,
        month: 6,
        year: 2026,
        syncStatus: 'local_only',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );

      when(() => mockRepo.watchAll(month: 6, year: 2026))
          .thenAnswer((_) => Stream.value([existing]));

      final result = await useCase(testBudget);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<String>;
      expect(failure.code, 'duplicate_budget');
    });

    test('should return Success with id on valid budget', () async {
      when(() => mockRepo.watchAll(month: 6, year: 2026))
          .thenAnswer((_) => Stream.value(<BudgetData>[]));
      when(() => mockRepo.create(any())).thenAnswer((_) async => 'bdg-1');

      final result = await useCase(testBudget);

      expect(result.isSuccess, isTrue);
      final success = result as Success<String>;
      expect(success.value, 'bdg-1');
    });

    test('should not detect duplicate for different category', () async {
      final existing = BudgetData(
        id: 'bdg-0',
        ownerUserId: 'usr-1',
        categoryId: 'cat-2',
        amount: 3000,
        month: 6,
        year: 2026,
        syncStatus: 'local_only',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );

      when(() => mockRepo.watchAll(month: 6, year: 2026))
          .thenAnswer((_) => Stream.value([existing]));
      when(() => mockRepo.create(any())).thenAnswer((_) async => 'bdg-1');

      final result = await useCase(testBudget);

      expect(result.isSuccess, isTrue);
    });
  });
}

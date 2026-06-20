import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lootr/data/repositories/budget_repo.dart';
import 'package:lootr/domain/use_cases/get_budget_spent.dart';
import 'package:lootr/domain/value_objects/result.dart';

class MockBudgetRepo extends Mock implements BudgetRepo {}

void main() {
  late MockBudgetRepo mockRepo;
  late GetBudgetSpent useCase;

  setUp(() {
    mockRepo = MockBudgetRepo();
    useCase = GetBudgetSpent(mockRepo);
  });

  group('GetBudgetSpent', () {
    test('should return Success with spent amount', () async {
      when(() => mockRepo.watchSpentForBudget('bdg-1'))
          .thenAnswer((_) => Stream.value(3500.0));

      final result = await useCase('bdg-1');

      expect(result.isSuccess, isTrue);
      final success = result as Success<double>;
      expect(success.value, 3500.0);
    });

    test('should return Success with zero when no spending', () async {
      when(() => mockRepo.watchSpentForBudget('bdg-1'))
          .thenAnswer((_) => Stream.value(0.0));

      final result = await useCase('bdg-1');

      expect(result.isSuccess, isTrue);
      final success = result as Success<double>;
      expect(success.value, 0.0);
    });

    test('should return Failure when stream errors', () async {
      when(() => mockRepo.watchSpentForBudget('bdg-1'))
          .thenAnswer((_) => Stream.error(Exception('DB error')));

      final result = await useCase('bdg-1');

      expect(result.isFailure, isTrue);
      final failure = result as Failure<double>;
      expect(failure.code, 'progress_error');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lootr/data/repositories/goal_repo.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/use_cases/contribute_to_goal.dart';
import 'package:lootr/domain/value_objects/result.dart';

class MockGoalRepo extends Mock implements GoalRepo {}

void main() {
  late MockGoalRepo mockRepo;
  late ContributeToGoal useCase;

  final testGoal = GoalData(
    id: 'gol-1',
    ownerUserId: 'usr-1',
    name: 'Emergency Fund',
    goalType: 'emergency_fund',
    targetAmount: 50000,
    currentAmount: 10000,
    syncStatus: 'local_only',
    createdAt: DateTime(2026, 6, 19),
    updatedAt: DateTime(2026, 6, 19),
  );

  setUp(() {
    mockRepo = MockGoalRepo();
    useCase = ContributeToGoal(mockRepo);
  });

  group('ContributeToGoal', () {
    test('should return Failure when amount is zero', () async {
      final result = await useCase('gol-1', 0);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<void>;
      expect(failure.code, 'invalid_amount');
    });

    test('should return Failure when amount is negative', () async {
      final result = await useCase('gol-1', -100);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<void>;
      expect(failure.code, 'invalid_amount');
    });

    test('should return Failure when goal not found', () async {
      when(() => mockRepo.watchById('gol-1'))
          .thenAnswer((_) => Stream.value(null));

      final result = await useCase('gol-1', 1000);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<void>;
      expect(failure.code, 'not_found');
    });

    test('should return Failure when would exceed target', () async {
      when(() => mockRepo.watchById('gol-1'))
          .thenAnswer((_) => Stream.value(testGoal));

      final result = await useCase('gol-1', 50000);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<void>;
      expect(failure.code, 'would_exceed_target');
    });

    test('should return Success on valid contribution', () async {
      when(() => mockRepo.watchById('gol-1'))
          .thenAnswer((_) => Stream.value(testGoal));
      when(() => mockRepo.addContribution('gol-1', 1000))
          .thenAnswer((_) async {});

      final result = await useCase('gol-1', 1000);

      expect(result.isSuccess, isTrue);
    });

    test('should allow contribution exactly to target', () async {
      when(() => mockRepo.watchById('gol-1'))
          .thenAnswer((_) => Stream.value(testGoal));
      when(() => mockRepo.addContribution('gol-1', 40000))
          .thenAnswer((_) async {});

      final result = await useCase('gol-1', 40000);

      expect(result.isSuccess, isTrue);
    });
  });
}

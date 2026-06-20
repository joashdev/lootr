import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart';
import 'package:lootr/data/repositories/goal_repo.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/entities/goal.dart';
import 'package:lootr/domain/use_cases/add_goal.dart';
import 'package:lootr/domain/value_objects/result.dart';
import 'package:lootr/domain/value_objects/field_types.dart';

class MockGoalRepo extends Mock implements GoalRepo {}

void main() {
  late MockGoalRepo mockRepo;
  late AddGoal useCase;

  setUpAll(() {
    registerFallbackValue(GoalsCompanion(
      id: const Value(''),
      ownerUserId: const Value(''),
      name: const Value(''),
      goalType: const Value('custom'),
      targetAmount: const Value(0),
      currentAmount: const Value(0),
    ));
  });

  final testGoal = Goal(
    id: 'gol-1',
    ownerUserId: 'usr-1',
    name: 'Emergency Fund',
    goalType: GoalType.emergencyFund,
    targetAmount: 50000,
    currentAmount: 0,
    createdAt: DateTime(2026, 6, 19),
    updatedAt: DateTime(2026, 6, 19),
  );

  setUp(() {
    mockRepo = MockGoalRepo();
    useCase = AddGoal(mockRepo);
  });

  group('AddGoal', () {
    test('should return Failure when target amount is zero', () async {
      final g = testGoal.copyWith(targetAmount: 0);

      final result = await useCase(g);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<String>;
      expect(failure.code, 'invalid_target');
    });

    test('should return Failure for invalid goal type', () async {
      final g = testGoal.copyWith(goalType: 'invalid_type');

      final result = await useCase(g);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<String>;
      expect(failure.code, 'invalid_goal_type');
    });

    test('should return Success with id on valid goal', () async {
      when(() => mockRepo.create(any())).thenAnswer((_) async => 'gol-1');

      final result = await useCase(testGoal);

      expect(result.isSuccess, isTrue);
      final success = result as Success<String>;
      expect(success.value, 'gol-1');
    });

    test('should accept all valid goal types', () async {
      const validTypes = [
        GoalType.emergencyFund,
        GoalType.savings,
        GoalType.travel,
        GoalType.debtPayoff,
        GoalType.custom,
      ];

      for (final goalType in validTypes) {
        when(() => mockRepo.create(any())).thenAnswer((_) async => 'gol-1');
        final g = testGoal.copyWith(goalType: goalType);
        final result = await useCase(g);
        expect(result.isSuccess, isTrue);
      }
    });
  });
}

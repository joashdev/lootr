import '../entities/goal.dart';
import '../value_objects/result.dart';
import '../../data/repositories/goal_repo.dart';
import '../entities/mappers.dart';

class AddGoal {
  final GoalRepo _goalRepo;

  AddGoal(this._goalRepo);

  Future<Result<String>> call(Goal goal) async {
    if (goal.targetAmount <= 0) {
      return Failure('Target amount must be greater than zero',
          code: 'invalid_target');
    }

    const validTypes = [
      'emergency_fund',
      'savings',
      'travel',
      'debt_payoff',
      'custom',
    ];

    if (!validTypes.contains(goal.goalType)) {
      return Failure('Invalid goal type: ${goal.goalType}',
          code: 'invalid_goal_type');
    }

    try {
      final id = await _goalRepo.create(goal.toCompanion());
      return Success(id);
    } catch (e) {
      return Failure('Failed to add goal: $e', code: 'create_error');
    }
  }
}

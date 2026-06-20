import '../value_objects/result.dart';
import '../../data/repositories/goal_repo.dart';

class ContributeToGoal {
  final GoalRepo _goalRepo;

  ContributeToGoal(this._goalRepo);

  Future<Result<void>> call(String goalId, double amount) async {
    if (amount <= 0) {
      return Failure('Contribution amount must be greater than zero',
          code: 'invalid_amount');
    }

    try {
      final goal = await _goalRepo.watchById(goalId).first;
      if (goal == null) {
        return Failure('Goal not found: $goalId', code: 'not_found');
      }

      if (goal.currentAmount + amount > goal.targetAmount) {
        return Failure(
          'Contribution would exceed target amount of ${goal.targetAmount}',
          code: 'would_exceed_target',
        );
      }

      await _goalRepo.addContribution(goalId, amount);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to contribute to goal: $e',
          code: 'contribution_error');
    }
  }
}

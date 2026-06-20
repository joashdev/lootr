import '../value_objects/result.dart';
import '../../data/repositories/budget_repo.dart';

class UpdateBudgetProgress {
  final BudgetRepo _budgetRepo;

  UpdateBudgetProgress(this._budgetRepo);

  Future<Result<double>> call(String budgetId) async {
    try {
      final spent =
          await _budgetRepo.watchSpentForBudget(budgetId).first;
      return Success(spent);
    } catch (e) {
      return Failure('Failed to update budget progress: $e',
          code: 'progress_error');
    }
  }
}

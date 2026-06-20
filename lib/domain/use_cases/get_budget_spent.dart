import '../value_objects/result.dart';
import '../../data/repositories/budget_repo.dart';

class GetBudgetSpent {
  final BudgetRepo _budgetRepo;

  GetBudgetSpent(this._budgetRepo);

  Future<Result<double>> call(String budgetId) async {
    try {
      final spent =
          await _budgetRepo.watchSpentForBudget(budgetId).first;
      return Success(spent);
    } catch (e) {
      return Failure('Failed to get budget spent: $e',
          code: 'progress_error');
    }
  }
}

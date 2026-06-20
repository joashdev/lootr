import '../entities/budget.dart';
import '../value_objects/result.dart';
import '../../data/repositories/budget_repo.dart';
import '../entities/mappers.dart';

class AddBudget {
  final BudgetRepo _budgetRepo;

  AddBudget(this._budgetRepo);

  Future<Result<String>> call(Budget budget) async {
    if (budget.month < 1 || budget.month > 12) {
      return Failure('Month must be between 1 and 12', code: 'invalid_month');
    }

    if (budget.amount <= 0) {
      return Failure('Amount must be greater than zero', code: 'invalid_amount');
    }

    try {
      final existing = await _budgetRepo
          .watchAll(month: budget.month, year: budget.year)
          .first;

      final duplicate = existing.where((b) =>
          b.categoryId == budget.categoryId &&
          b.ownerUserId == budget.ownerUserId);

      if (duplicate.isNotEmpty) {
        return Failure(
          'Budget already exists for this category in '
          '${budget.month}/${budget.year}',
          code: 'duplicate_budget',
        );
      }

      final id = await _budgetRepo.create(budget.toCompanion());
      return Success(id);
    } catch (e) {
      return Failure('Failed to add budget: $e', code: 'create_error');
    }
  }
}

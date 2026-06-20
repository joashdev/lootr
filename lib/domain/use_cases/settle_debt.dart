import '../value_objects/result.dart';
import '../../data/repositories/debt_repo.dart';

class SettleDebt {
  final DebtRepo _debtRepo;

  SettleDebt(this._debtRepo);

  Future<Result<void>> call(String debtId) async {
    try {
      final debt = await _debtRepo.watchById(debtId).first;
      if (debt == null) {
        return Failure('Debt record not found: $debtId', code: 'not_found');
      }
      await _debtRepo.settle(debtId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to settle debt: $e', code: 'settle_error');
    }
  }
}

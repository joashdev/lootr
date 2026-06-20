import '../value_objects/result.dart';
import '../../data/repositories/debt_repo.dart';

class SettleDebt {
  final DebtRepo _debtRepo;

  SettleDebt(this._debtRepo);

  Future<Result<void>> call(String debtId) async {
    try {
      await _debtRepo.settle(debtId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to settle debt: $e', code: 'settle_error');
    }
  }
}

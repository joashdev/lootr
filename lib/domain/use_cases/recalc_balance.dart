import '../value_objects/result.dart';
import '../../data/repositories/account_repo.dart';

class RecalcBalance {
  final AccountRepo _accountRepo;

  RecalcBalance(this._accountRepo);

  Future<Result<double>> call(String accountId) async {
    try {
      await _accountRepo.recalcBalance(accountId);
      final balance = await _accountRepo.getBalance(accountId);
      return Success(balance);
    } catch (e) {
      return Failure('Failed to recalculate balance: $e', code: 'recalc_error');
    }
  }
}

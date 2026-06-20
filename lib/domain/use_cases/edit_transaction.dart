import '../entities/transaction.dart';
import '../value_objects/result.dart';
import '../../data/repositories/transaction_repo.dart';
import '../entities/mappers.dart';

class EditTransaction {
  final TransactionRepo _transactionRepo;

  EditTransaction(this._transactionRepo);

  Future<Result<void>> call(Transaction updated) async {
    if (updated.amount <= 0) {
      return Failure('Amount must be greater than zero', code: 'invalid_amount');
    }

    if (updated.direction != 'expense' &&
        updated.direction != 'income') {
      return Failure('Invalid transaction direction: ${updated.direction}',
          code: 'invalid_direction');
    }

    try {
      final original = await _transactionRepo.watchById(updated.id).first;
      if (original == null) {
        return Failure('Transaction not found: ${updated.id}',
            code: 'not_found');
      }
    } catch (e) {
      return Failure('Failed to load original transaction: $e',
          code: 'load_error');
    }

    try {
      await _transactionRepo.update(updated.toUpdateCompanion());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to edit transaction: $e', code: 'update_error');
    }
  }
}

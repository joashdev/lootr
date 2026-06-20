import '../entities/transaction.dart';
import '../value_objects/result.dart';
import '../../data/repositories/transaction_repo.dart';
import '../../data/repositories/account_repo.dart';
import '../entities/mappers.dart';

class EditTransaction {
  final TransactionRepo _transactionRepo;
  final AccountRepo _accountRepo;

  EditTransaction(this._transactionRepo, this._accountRepo);

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
      if (original.deletedAt != null) {
        return Failure('Cannot edit a deleted transaction: ${updated.id}',
            code: 'transaction_deleted');
      }

      if (updated.accountId != original.accountId) {
        final account =
            await _accountRepo.watchById(updated.accountId).first;
        if (account == null) {
          return Failure('Account not found: ${updated.accountId}',
              code: 'account_not_found');
        }
        if (account.deletedAt != null) {
          return Failure('Account is deleted: ${updated.accountId}',
              code: 'account_deleted');
        }
        if (account.isArchived) {
          return Failure('Account is archived: ${updated.accountId}',
              code: 'account_archived');
        }
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

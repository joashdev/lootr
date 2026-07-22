import '../entities/transaction.dart';
import '../value_objects/result.dart';
import '../../data/repositories/transaction_repo.dart';
import '../../data/repositories/account_repo.dart';
import '../entities/mappers.dart';

class AddTransaction {
  final TransactionRepo _transactionRepo;
  final AccountRepo _accountRepo;

  AddTransaction(this._transactionRepo, this._accountRepo);

  Future<Result<String>> call(Transaction transaction) async {
    if (transaction.exactAmount.coefficient <= BigInt.zero) {
      return Failure(
        'Amount must be greater than zero',
        code: 'invalid_amount',
      );
    }

    if (transaction.direction != 'expense' &&
        transaction.direction != 'income') {
      return Failure(
        'Invalid transaction direction: ${transaction.direction}',
        code: 'invalid_direction',
      );
    }

    try {
      final account = await _accountRepo.watchById(transaction.accountId).first;
      if (account == null) {
        return Failure(
          'Account not found: ${transaction.accountId}',
          code: 'account_not_found',
        );
      }
      if (account.deletedAt != null) {
        return Failure(
          'Account is deleted: ${transaction.accountId}',
          code: 'account_deleted',
        );
      }
      if (account.isArchived) {
        return Failure(
          'Account is archived: ${transaction.accountId}',
          code: 'account_archived',
        );
      }
    } catch (e) {
      return Failure('Failed to validate account: $e', code: 'account_error');
    }

    try {
      final id = await _transactionRepo.create(transaction.toCompanion());
      return Success(id);
    } catch (e) {
      return Failure('Failed to add transaction: $e', code: 'create_error');
    }
  }
}

import '../entities/transfer.dart';
import '../value_objects/result.dart';
import '../../data/repositories/transfer_repo.dart';
import '../../data/repositories/account_repo.dart';
import '../entities/mappers.dart';

class CreateTransfer {
  final TransferRepo _transferRepo;
  final AccountRepo _accountRepo;

  CreateTransfer(this._transferRepo, this._accountRepo);

  Future<Result<String>> call(Transfer transfer) async {
    if (transfer.sourceAccountId == transfer.destinationAccountId) {
      return Failure(
        'Source and destination accounts must be different',
        code: 'same_account',
      );
    }

    if (transfer.exactSourceAmount.coefficient <= BigInt.zero ||
        transfer.exactDestinationAmount.coefficient <= BigInt.zero) {
      return Failure(
        'Amount must be greater than zero',
        code: 'invalid_amount',
      );
    }

    try {
      final source = await _accountRepo
          .watchById(transfer.sourceAccountId)
          .first;
      if (source == null) {
        return Failure(
          'Source account not found: ${transfer.sourceAccountId}',
          code: 'source_not_found',
        );
      }
      if (source.deletedAt != null) {
        return Failure(
          'Source account is deleted: ${transfer.sourceAccountId}',
          code: 'source_deleted',
        );
      }
      if (source.isArchived) {
        return Failure(
          'Source account is archived: ${transfer.sourceAccountId}',
          code: 'source_archived',
        );
      }

      final dest = await _accountRepo
          .watchById(transfer.destinationAccountId)
          .first;
      if (dest == null) {
        return Failure(
          'Destination account not found: ${transfer.destinationAccountId}',
          code: 'dest_not_found',
        );
      }
      if (dest.deletedAt != null) {
        return Failure(
          'Destination account is deleted: ${transfer.destinationAccountId}',
          code: 'dest_deleted',
        );
      }
      if (dest.isArchived) {
        return Failure(
          'Destination account is archived: ${transfer.destinationAccountId}',
          code: 'dest_archived',
        );
      }
    } catch (e) {
      return Failure('Failed to validate accounts: $e', code: 'account_error');
    }

    try {
      final id = await _transferRepo.create(transfer.toCompanion());
      return Success(id);
    } catch (e) {
      return Failure('Failed to create transfer: $e', code: 'create_error');
    }
  }
}

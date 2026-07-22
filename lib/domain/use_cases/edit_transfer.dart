import '../../data/repositories/account_repo.dart';
import '../../data/repositories/transfer_repo.dart';
import '../entities/mappers.dart';
import '../entities/transfer.dart';
import '../value_objects/result.dart';

class EditTransfer {
  final TransferRepo _transferRepo;
  final AccountRepo _accountRepo;

  EditTransfer(this._transferRepo, this._accountRepo);

  Future<Result<void>> call(Transfer updated) async {
    if (updated.sourceAccountId == updated.destinationAccountId) {
      return Failure(
        'Source and destination accounts must be different',
        code: 'same_account',
      );
    }

    if (updated.exactSourceAmount.coefficient <= BigInt.zero ||
        updated.exactDestinationAmount.coefficient <= BigInt.zero) {
      return Failure(
        'Amount must be greater than zero',
        code: 'invalid_amount',
      );
    }

    if (updated.exactFeeAmount.isNegative) {
      return Failure('Fee amount cannot be negative', code: 'invalid_fee');
    }

    try {
      final original = await _transferRepo.watchById(updated.id).first;
      if (original == null) {
        return Failure('Transfer not found: ${updated.id}', code: 'not_found');
      }
      if (original.deletedAt != null) {
        return Failure(
          'Cannot edit a deleted transfer: ${updated.id}',
          code: 'transfer_deleted',
        );
      }

      final source = await _accountRepo
          .watchById(updated.sourceAccountId)
          .first;
      if (source == null) {
        return Failure(
          'Source account not found: ${updated.sourceAccountId}',
          code: 'source_not_found',
        );
      }
      if (source.deletedAt != null) {
        return Failure(
          'Source account is deleted: ${updated.sourceAccountId}',
          code: 'source_deleted',
        );
      }
      if (source.isArchived) {
        return Failure(
          'Source account is archived: ${updated.sourceAccountId}',
          code: 'source_archived',
        );
      }

      final destination = await _accountRepo
          .watchById(updated.destinationAccountId)
          .first;
      if (destination == null) {
        return Failure(
          'Destination account not found: ${updated.destinationAccountId}',
          code: 'dest_not_found',
        );
      }
      if (destination.deletedAt != null) {
        return Failure(
          'Destination account is deleted: ${updated.destinationAccountId}',
          code: 'dest_deleted',
        );
      }
      if (destination.isArchived) {
        return Failure(
          'Destination account is archived: ${updated.destinationAccountId}',
          code: 'dest_archived',
        );
      }
    } catch (e) {
      return Failure(
        'Failed to validate transfer: $e',
        code: 'validation_error',
      );
    }

    try {
      await _transferRepo.update(updated.toUpdateCompanion());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to edit transfer: $e', code: 'update_error');
    }
  }
}

import '../value_objects/result.dart';
import '../value_objects/undo_entry.dart';
import '../entities/mappers.dart';
import '../../data/repositories/transaction_repo.dart';

class DeleteTransaction {
  final TransactionRepo _transactionRepo;

  DeleteTransaction(this._transactionRepo);

  Future<Result<UndoEntry>> call(String id) async {
    final data = await _transactionRepo.watchById(id).first;
    if (data == null) {
      return Failure('Transaction not found: $id', code: 'not_found');
    }

    final entity = data.toEntity();

    try {
      await _transactionRepo.softDelete(id);

      final undoEntry = UndoEntry(
        transactionId: id,
        message: 'Transaction deleted',
        rollback: () async {
          final restoredId =
              'txn-${DateTime.now().microsecondsSinceEpoch}';
          await _transactionRepo.create(
            entity.copyWith(
              id: restoredId,
              deletedAt: () => null,
            ).toCompanion(),
          );
        },
        createdAt: DateTime.now(),
      );

      return Success(undoEntry);
    } catch (e) {
      return Failure('Failed to delete transaction: $e', code: 'delete_error');
    }
  }
}

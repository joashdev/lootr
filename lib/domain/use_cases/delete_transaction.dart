import '../value_objects/result.dart';
import '../value_objects/undo_entry.dart';
import '../../data/repositories/transaction_repo.dart';

class DeleteTransaction {
  final TransactionRepo _transactionRepo;

  DeleteTransaction(this._transactionRepo);

  Future<Result<UndoEntry>> call(String id) async {
    final data = await _transactionRepo.watchById(id).first;
    if (data == null) {
      return Failure('Transaction not found: $id', code: 'not_found');
    }

    try {
      await _transactionRepo.softDelete(id);

      final undoEntry = UndoEntry(
        transactionId: id,
        message: 'Transaction deleted',
        // Restore in place (same id) so sync sees a single row flip back
        // instead of a tombstone plus a duplicate, and so side effects of
        // create() (e.g. advancing recurring templates) don't re-run.
        rollback: () => _transactionRepo.restore(id),
        createdAt: DateTime.now(),
      );

      return Success(undoEntry);
    } catch (e) {
      return Failure('Failed to delete transaction: $e', code: 'delete_error');
    }
  }
}

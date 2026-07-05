import '../../data/repositories/transfer_repo.dart';
import '../value_objects/result.dart';
import '../value_objects/undo_entry.dart';

class DeleteTransfer {
  final TransferRepo _transferRepo;

  DeleteTransfer(this._transferRepo);

  Future<Result<UndoEntry>> call(String id) async {
    final data = await _transferRepo.watchById(id).first;
    if (data == null) {
      return Failure('Transfer not found: $id', code: 'not_found');
    }

    try {
      await _transferRepo.softDelete(id);

      final undoEntry = UndoEntry(
        transactionId: id,
        message: 'Transfer deleted',
        // Restore in place (same id) so the original transfer and its fee
        // transaction come back instead of a duplicate under a new id.
        rollback: () => _transferRepo.restore(id),
        createdAt: DateTime.now(),
      );

      return Success(undoEntry);
    } catch (e) {
      return Failure('Failed to delete transfer: $e', code: 'delete_error');
    }
  }
}

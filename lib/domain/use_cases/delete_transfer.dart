import '../../data/repositories/transfer_repo.dart';
import '../entities/mappers.dart';
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

    final entity = data.toEntity();

    try {
      await _transferRepo.softDelete(id);

      final undoEntry = UndoEntry(
        transactionId: id,
        message: 'Transfer deleted',
        rollback: () async {
          final restoredId = 'xfer-${DateTime.now().microsecondsSinceEpoch}';
          await _transferRepo.create(
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
      return Failure('Failed to delete transfer: $e', code: 'delete_error');
    }
  }
}

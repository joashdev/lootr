import '../../domain/entities/transaction.dart';
import '../../domain/entities/transfer.dart';

const _transferEntryType = 'transfer';

Transaction mapTransferToTransaction(Transfer transfer) {
  return Transaction(
    id: transfer.id,
    accountId: transfer.sourceAccountId,
    amount: transfer.amount,
    direction: 'transfer',
    mode: 'one_time',
    subtype: _transferEntryType,
    note: transfer.note,
    metadata: <String, dynamic>{
      'entry_type': _transferEntryType,
      'transfer_id': transfer.id,
      'source_account_id': transfer.sourceAccountId,
      'destination_account_id': transfer.destinationAccountId,
      'fee_amount': transfer.feeAmount,
    },
    occurredAt: transfer.occurredAt,
    createdAt: transfer.createdAt,
    updatedAt: transfer.updatedAt,
    deletedAt: transfer.deletedAt,
  );
}

bool isTransferEntry(Transaction transaction) {
  final metadata = transaction.metadata;
  return transaction.direction == 'transfer' &&
      (transaction.subtype == _transferEntryType ||
          metadata?['entry_type'] == _transferEntryType ||
          metadata?['transfer_id'] != null);
}

Transfer? transferFromTransaction(Transaction transaction) {
  if (!isTransferEntry(transaction)) return null;

  final metadata = transaction.metadata;
  final destinationAccountId = metadata?['destination_account_id']?.toString();
  if (destinationAccountId == null || destinationAccountId.isEmpty) {
    return null;
  }

  final sourceAccountId =
      metadata?['source_account_id']?.toString() ?? transaction.accountId;
  final feeAmountRaw = metadata?['fee_amount'];
  final feeAmount = feeAmountRaw is num
      ? feeAmountRaw.toDouble()
      : double.tryParse(feeAmountRaw?.toString() ?? '') ?? 0;

  return Transfer(
    id: metadata?['transfer_id']?.toString() ?? transaction.id,
    sourceAccountId: sourceAccountId,
    destinationAccountId: destinationAccountId,
    amount: transaction.amount,
    feeAmount: feeAmount,
    note: transaction.note,
    occurredAt: transaction.occurredAt,
    createdAt: transaction.createdAt,
    updatedAt: transaction.updatedAt,
    deletedAt: transaction.deletedAt,
  );
}

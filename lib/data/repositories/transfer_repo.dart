import 'package:drift/drift.dart' hide isNull;

import '../database/app_database.dart';

class TransferRepo {
  final AppDatabase _db;

  TransferRepo(this._db);

  Stream<List<TransferData>> watchAll() {
    final q = _db.select(_db.transfers)
      ..where((t) => t.deletedAt.isNull());
    q.orderBy(
        [(t) => OrderingTerm(expression: t.occurredAt, mode: OrderingMode.desc)]);
    return q.watch();
  }

  Stream<List<TransferData>> watchByAccount(String accountId) {
    final q = _db.select(_db.transfers)
      ..where((t) =>
          (t.sourceAccountId.equals(accountId) |
              t.destinationAccountId.equals(accountId)) &
          t.deletedAt.isNull());
    q.orderBy(
        [(t) => OrderingTerm(expression: t.occurredAt, mode: OrderingMode.desc)]);
    return q.watch();
  }

  Future<String> create(TransfersCompanion t) async {
    if (!t.id.present) throw ArgumentError('id is required for create');
    final id = t.id.value;
    final hasFee = t.feeAmount.present && (t.feeAmount.value ?? 0) > 0;

    return _db.transaction(() async {
      await _db.into(_db.transfers).insert(t);

      final row = await (_db.select(_db.transfers)
            ..where((r) => r.id.equals(id))
            ..limit(1))
          .getSingle();

      final sourceAccount = await (_db.select(_db.accounts)
            ..where((a) => a.id.equals(row.sourceAccountId))
            ..limit(1))
          .getSingle();

      final totalDeduction = row.amount + (hasFee ? row.feeAmount! : 0);
      await (_db.update(_db.accounts)
            ..where((a) => a.id.equals(row.sourceAccountId)))
          .write(AccountsCompanion(
        balance: Value(sourceAccount.balance - totalDeduction),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ));

      final destAccount = await (_db.select(_db.accounts)
            ..where((a) => a.id.equals(row.destinationAccountId))
            ..limit(1))
          .getSingle();

      await (_db.update(_db.accounts)
            ..where((a) => a.id.equals(row.destinationAccountId)))
          .write(AccountsCompanion(
        balance: Value(destAccount.balance + row.amount),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ));

      if (hasFee) {
        final feeId = 'txn-fee-$id';
        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                id: feeId,
                accountId: row.sourceAccountId,
                amount: row.feeAmount!,
                transactionDirection: 'expense',
                transactionMode: 'one_time',
                transactionSubtype: const Value('transfer_fee'),
                note: const Value('Transfer fee'),
                occurredAt: row.occurredAt,
              ),
            );
      }

      return id;
    });
  }

  Future<void> softDelete(String id) async {
    await _db.transaction(() async {
      final rows = await (_db.select(_db.transfers)
            ..where((t) => t.id.equals(id) & t.deletedAt.isNull())
            ..limit(1))
          .get();
      if (rows.isEmpty) return;
      final transfer = rows.first;
      final hasFee = transfer.feeAmount != null && transfer.feeAmount! > 0;

      final sourceAccount = await (_db.select(_db.accounts)
            ..where((a) => a.id.equals(transfer.sourceAccountId))
            ..limit(1))
          .getSingle();

      final totalReversal = transfer.amount + (hasFee ? transfer.feeAmount! : 0);
      await (_db.update(_db.accounts)
            ..where((a) => a.id.equals(transfer.sourceAccountId)))
          .write(AccountsCompanion(
        balance: Value(sourceAccount.balance + totalReversal),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ));

      final destAccount = await (_db.select(_db.accounts)
            ..where((a) => a.id.equals(transfer.destinationAccountId))
            ..limit(1))
          .getSingle();

      await (_db.update(_db.accounts)
            ..where((a) => a.id.equals(transfer.destinationAccountId)))
          .write(AccountsCompanion(
        balance: Value(destAccount.balance - transfer.amount),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ));

      final now = DateTime.now();
      await (_db.update(_db.transfers)..where((t) => t.id.equals(id)))
          .write(TransfersCompanion(
        deletedAt: Value(now),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(now),
      ));

      if (hasFee) {
        final feeId = 'txn-fee-$id';
        await (_db.update(_db.transactions)..where((t) => t.id.equals(feeId)))
            .write(TransactionsCompanion(
          deletedAt: Value(now),
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(now),
        ));
      }
    });
  }
}

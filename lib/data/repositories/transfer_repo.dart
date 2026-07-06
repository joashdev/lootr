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

  Stream<TransferData?> watchById(String id) {
    return (_db.select(_db.transfers)
          ..where((t) => t.id.equals(id))
          ..limit(1))
        .watch()
        .map((rows) => rows.isNotEmpty ? rows.first : null);
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

  Future<void> update(TransfersCompanion transferCompanion) async {
    if (!transferCompanion.id.present) {
      throw ArgumentError('id is required for update');
    }

    final id = transferCompanion.id.value;

    await _db.transaction(() async {
      final old = await (_db.select(_db.transfers)
            ..where((t) => t.id.equals(id))
            ..limit(1))
          .getSingle();

      final oldHasFee = (old.feeAmount ?? 0) > 0;
      final oldSourceAccount = await (_db.select(_db.accounts)
            ..where((a) => a.id.equals(old.sourceAccountId))
            ..limit(1))
          .getSingle();
      final oldDestinationAccount = await (_db.select(_db.accounts)
            ..where((a) => a.id.equals(old.destinationAccountId))
            ..limit(1))
          .getSingle();

      await (_db.update(_db.accounts)
            ..where((a) => a.id.equals(old.sourceAccountId)))
          .write(AccountsCompanion(
        balance: Value(
          oldSourceAccount.balance + old.amount + (oldHasFee ? old.feeAmount! : 0),
        ),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ));

      await (_db.update(_db.accounts)
            ..where((a) => a.id.equals(old.destinationAccountId)))
          .write(AccountsCompanion(
        balance: Value(oldDestinationAccount.balance - old.amount),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ));

      await (_db.update(_db.transfers)..where((t) => t.id.equals(id)))
          .write(transferCompanion);
      await (_db.update(_db.transfers)..where((t) => t.id.equals(id)))
          .write(TransfersCompanion(
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ));

      final updated = await (_db.select(_db.transfers)
            ..where((t) => t.id.equals(id))
            ..limit(1))
          .getSingle();
      final updatedHasFee = (updated.feeAmount ?? 0) > 0;
      final newSourceAccount = await (_db.select(_db.accounts)
            ..where((a) => a.id.equals(updated.sourceAccountId))
            ..limit(1))
          .getSingle();
      final newDestinationAccount = await (_db.select(_db.accounts)
            ..where((a) => a.id.equals(updated.destinationAccountId))
            ..limit(1))
          .getSingle();

      await (_db.update(_db.accounts)
            ..where((a) => a.id.equals(updated.sourceAccountId)))
          .write(AccountsCompanion(
        balance: Value(
          newSourceAccount.balance -
              updated.amount -
              (updatedHasFee ? updated.feeAmount! : 0),
        ),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ));

      await (_db.update(_db.accounts)
            ..where((a) => a.id.equals(updated.destinationAccountId)))
          .write(AccountsCompanion(
        balance: Value(newDestinationAccount.balance + updated.amount),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ));

      final feeId = 'txn-fee-$id';
      if (oldHasFee && updatedHasFee) {
        await (_db.update(_db.transactions)..where((t) => t.id.equals(feeId)))
            .write(TransactionsCompanion(
          accountId: Value(updated.sourceAccountId),
          amount: Value(updated.feeAmount!),
          note: const Value('Transfer fee'),
          occurredAt: Value(updated.occurredAt),
          deletedAt: const Value(null),
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(DateTime.now()),
        ));
      } else if (!oldHasFee && updatedHasFee) {
        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                id: feeId,
                accountId: updated.sourceAccountId,
                amount: updated.feeAmount!,
                transactionDirection: 'expense',
                transactionMode: 'one_time',
                transactionSubtype: const Value('transfer_fee'),
                note: const Value('Transfer fee'),
                occurredAt: updated.occurredAt,
              ),
            );
      } else if (oldHasFee && !updatedHasFee) {
        await (_db.update(_db.transactions)..where((t) => t.id.equals(feeId)))
            .write(TransactionsCompanion(
          deletedAt: Value(DateTime.now()),
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(DateTime.now()),
        ));
      }
    });
  }

  /// Reverses [softDelete]: clears the tombstone on the original transfer
  /// (and its fee transaction, if any) and re-applies both balance impacts.
  /// Used by undo so the transfer keeps its id (sync-friendly).
  Future<void> restore(String id) async {
    await _db.transaction(() async {
      final rows = await (_db.select(_db.transfers)
            ..where((t) => t.id.equals(id) & t.deletedAt.isNotNull())
            ..limit(1))
          .get();
      if (rows.isEmpty) return;
      final transfer = rows.first;
      final hasFee = transfer.feeAmount != null && transfer.feeAmount! > 0;

      final sourceAccount = await (_db.select(_db.accounts)
            ..where((a) => a.id.equals(transfer.sourceAccountId))
            ..limit(1))
          .getSingle();

      final totalDeduction =
          transfer.amount + (hasFee ? transfer.feeAmount! : 0);
      await (_db.update(_db.accounts)
            ..where((a) => a.id.equals(transfer.sourceAccountId)))
          .write(AccountsCompanion(
        balance: Value(sourceAccount.balance - totalDeduction),
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
        balance: Value(destAccount.balance + transfer.amount),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ));

      final now = DateTime.now();
      await (_db.update(_db.transfers)..where((t) => t.id.equals(id)))
          .write(TransfersCompanion(
        deletedAt: const Value(null),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(now),
      ));

      if (hasFee) {
        final feeId = 'txn-fee-$id';
        await (_db.update(_db.transactions)..where((t) => t.id.equals(feeId)))
            .write(TransactionsCompanion(
          deletedAt: const Value(null),
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(now),
        ));
      }
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

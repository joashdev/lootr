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

      await (_db.update(_db.accounts)
            ..where((a) => a.id.equals(row.sourceAccountId)))
          .write(AccountsCompanion(
        balance: Value(sourceAccount.balance - row.amount),
        syncStatus: const Value('pending_sync'),
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
      ));

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

      final sourceAccount = await (_db.select(_db.accounts)
            ..where((a) => a.id.equals(transfer.sourceAccountId))
            ..limit(1))
          .getSingle();

      await (_db.update(_db.accounts)
            ..where((a) => a.id.equals(transfer.sourceAccountId)))
          .write(AccountsCompanion(
        balance: Value(sourceAccount.balance + transfer.amount),
        syncStatus: const Value('pending_sync'),
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
      ));

      final now = DateTime.now();
      await (_db.update(_db.transfers)..where((t) => t.id.equals(id)))
          .write(TransfersCompanion(
        deletedAt: Value(now),
        syncStatus: const Value('pending_sync'),
      ));
    });
  }
}

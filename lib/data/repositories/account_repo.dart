import 'package:drift/drift.dart' hide isNull;

import '../database/app_database.dart';

class AccountRepo {
  final AppDatabase _db;

  AccountRepo(this._db);

  Stream<List<AccountData>> watchAll({bool includeArchived = false}) {
    final q = _db.select(_db.accounts)
      ..where((a) => a.deletedAt.isNull());

    if (!includeArchived) {
      q.where((a) => a.isArchived.equals(false));
    }

    return q.watch();
  }

  Stream<AccountData?> watchById(String id) {
    return (_db.select(_db.accounts)
          ..where((a) => a.id.equals(id))
          ..limit(1))
        .watch()
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  Future<String> create(AccountsCompanion a) async {
    if (!a.id.present) throw ArgumentError('id is required for create');
    await _db.into(_db.accounts).insert(a);
    return a.id.value;
  }

  Future<void> update(AccountsCompanion a) async {
    if (!a.id.present) throw ArgumentError('id is required for update');
    final id = a.id.value;
    await (_db.update(_db.accounts)..where((row) => row.id.equals(id)))
        .write(a);
    await (_db.update(_db.accounts)..where((row) => row.id.equals(id)))
        .write(AccountsCompanion(
      syncStatus: const Value('pending_sync'),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> archive(String id) async {
    await (_db.update(_db.accounts)..where((a) => a.id.equals(id)))
        .write(AccountsCompanion(
      isArchived: const Value(true),
      syncStatus: const Value('pending_sync'),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<double> getBalance(String id) async {
    final account = await (_db.select(_db.accounts)
          ..where((a) => a.id.equals(id))
          ..limit(1))
        .getSingle();
    return account.balance;
  }

  Future<void> recalcBalance(String id) async {
    await _db.transaction(() async {
      final txns = await (_db.select(_db.transactions)
            ..where((t) => t.accountId.equals(id) & t.deletedAt.isNull()))
          .get();

      final transfers = await (_db.select(_db.transfers)
            ..where((t) =>
                t.deletedAt.isNull() &
                (t.sourceAccountId.equals(id) | t.destinationAccountId.equals(id))))
          .get();

      double balance = 0;
      for (final t in txns) {
        balance += t.transactionDirection == 'income' ? t.amount : -t.amount;
      }
      for (final x in transfers) {
        if (x.sourceAccountId == id) balance -= x.amount;
        if (x.destinationAccountId == id) balance += x.amount;
      }

      await (_db.update(_db.accounts)..where((a) => a.id.equals(id)))
          .write(AccountsCompanion(
        balance: Value(balance),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ));
    });
  }
}

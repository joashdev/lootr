import 'package:drift/drift.dart' hide isNull;

import '../database/app_database.dart';

class DebtRepo {
  final AppDatabase _db;

  DebtRepo(this._db);

  Stream<List<DebtRecordData>> watchAll() {
    return (_db.select(
      _db.debtRecords,
    )..where((d) => d.deletedAt.isNull())).watch();
  }

  Stream<DebtRecordData?> watchById(String id) {
    return (_db.select(_db.debtRecords)
          ..where((d) => d.id.equals(id))
          ..limit(1))
        .watch()
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  Future<String> create(DebtRecordsCompanion d) async {
    if (!d.id.present) throw ArgumentError('id is required for create');
    await _db.into(_db.debtRecords).insert(d);
    return d.id.value;
  }

  Future<void> update(DebtRecordsCompanion d) async {
    if (!d.id.present) throw ArgumentError('id is required for update');
    final id = d.id.value;
    await (_db.update(
      _db.debtRecords,
    )..where((row) => row.id.equals(id))).write(d);
    await (_db.update(
      _db.debtRecords,
    )..where((row) => row.id.equals(id))).write(
      DebtRecordsCompanion(
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> settle(String id) async {
    await (_db.update(_db.debtRecords)..where((d) => d.id.equals(id))).write(
      DebtRecordsCompanion(
        status: const Value('settled'),
        remainingBalance: const Value(0.0),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> softDelete(String id) async {
    await (_db.update(
      _db.debtRecords,
    )..where((row) => row.id.equals(id))).write(
      DebtRecordsCompanion(
        deletedAt: Value(DateTime.now()),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

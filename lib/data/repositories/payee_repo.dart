import 'package:drift/drift.dart' hide isNull;

import '../database/app_database.dart';

class PayeeRepo {
  final AppDatabase _db;

  PayeeRepo(this._db);

  Stream<List<PayeeData>> watchAll() {
    final q = _db.select(_db.payees)..where((p) => p.deletedAt.isNull());
    q.orderBy([(p) => OrderingTerm(expression: p.normalizedName)]);
    return q.watch();
  }

  Stream<PayeeData?> watchById(String id) {
    return (_db.select(_db.payees)
          ..where((p) => p.id.equals(id))
          ..limit(1))
        .watch()
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  Future<PayeeData?> findByNormalizedName(String name) async {
    final rows =
        await (_db.select(_db.payees)
              ..where(
                (p) => p.normalizedName.equals(name) & p.deletedAt.isNull(),
              )
              ..limit(1))
            .get();
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<PayeeData> createOrGet(String normalizedName) async {
    return _db.transaction(() async {
      final existing = await findByNormalizedName(normalizedName);
      if (existing != null) return existing;

      final id = 'pay-${DateTime.now().microsecondsSinceEpoch}';
      await _db
          .into(_db.payees)
          .insert(
            PayeesCompanion.insert(id: id, normalizedName: normalizedName),
          );
      return (_db.select(_db.payees)
            ..where((p) => p.id.equals(id))
            ..limit(1))
          .getSingle();
    });
  }

  Future<PayeeData> createOrGetByName(String name) async {
    final trimmed = name.trim();
    final normalized = trimmed.toLowerCase();

    return _db.transaction(() async {
      final existing = await findByNormalizedName(normalized);
      if (existing != null) {
        if (existing.displayName == null && trimmed.isNotEmpty) {
          await (_db.update(
            _db.payees,
          )..where((p) => p.id.equals(existing.id))).write(
            PayeesCompanion(
              displayName: Value(trimmed),
              syncStatus: const Value('pending_sync'),
              updatedAt: Value(DateTime.now()),
            ),
          );
          return (_db.select(_db.payees)
                ..where((p) => p.id.equals(existing.id))
                ..limit(1))
              .getSingle();
        }
        return existing;
      }

      final id = 'pay-${DateTime.now().microsecondsSinceEpoch}';
      await _db
          .into(_db.payees)
          .insert(
            PayeesCompanion.insert(
              id: id,
              normalizedName: normalized,
              displayName: Value(trimmed),
            ),
          );
      return (_db.select(_db.payees)
            ..where((p) => p.id.equals(id))
            ..limit(1))
          .getSingle();
    });
  }

  Future<void> updateName(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final normalized = trimmed.toLowerCase();

    await _db.transaction(() async {
      // `normalized_name` is covered by a unique index, so a rename onto an
      // existing payee's name would otherwise throw a raw SQLite exception.
      // Surface it as a typed conflict the UI can turn into validation feedback.
      final existing = await findByNormalizedName(normalized);
      if (existing != null && existing.id != id) {
        throw const PayeeNameConflictException();
      }

      await (_db.update(_db.payees)..where((p) => p.id.equals(id))).write(
        PayeesCompanion(
          normalizedName: Value(normalized),
          displayName: Value(trimmed),
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }
}

/// Thrown by [PayeeRepo.updateName] when the target name already belongs to
/// another payee (the unique `idx_payees_normalized` index would reject it).
class PayeeNameConflictException implements Exception {
  const PayeeNameConflictException();

  @override
  String toString() => 'A payee with that name already exists.';
}

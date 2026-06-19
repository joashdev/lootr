import 'package:drift/drift.dart' hide isNull;

import '../database/app_database.dart';

class PayeeRepo {
  final AppDatabase _db;

  PayeeRepo(this._db);

  Stream<List<PayeeData>> watchAll() {
    final q = _db.select(_db.payees)
      ..where((p) => p.deletedAt.isNull());
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
    final rows = await (_db.select(_db.payees)
          ..where((p) => p.normalizedName.equals(name) & p.deletedAt.isNull())
          ..limit(1))
        .get();
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<PayeeData> createOrGet(String normalizedName) async {
    return _db.transaction(() async {
      final existing = await findByNormalizedName(normalizedName);
      if (existing != null) return existing;

      final id = 'pay-${DateTime.now().millisecondsSinceEpoch}';
      await _db.into(_db.payees).insert(PayeesCompanion.insert(
            id: id,
            normalizedName: normalizedName,
          ));
      return (_db.select(_db.payees)
            ..where((p) => p.id.equals(id))
            ..limit(1))
          .getSingle();
    });
  }
}

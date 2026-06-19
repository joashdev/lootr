import 'package:drift/drift.dart' hide isNull;

import '../database/app_database.dart';

class CategoryRepo {
  final AppDatabase _db;

  CategoryRepo(this._db);

  Stream<List<CategoryData>> watchAll() {
    final q = _db.select(_db.categories)
      ..where((c) => c.deletedAt.isNull());
    q.orderBy([(c) => OrderingTerm(expression: c.name)]);
    return q.watch();
  }

  Stream<List<CategoryData>> watchByGroup(String group) {
    final q = _db.select(_db.categories)
      ..where((c) => c.categoryGroup.equals(group) & c.deletedAt.isNull());
    q.orderBy([(c) => OrderingTerm(expression: c.name)]);
    return q.watch();
  }

  Future<String> create(CategoriesCompanion c) async {
    if (!c.id.present) throw ArgumentError('id is required for create');
    await _db.into(_db.categories).insert(c);
    return c.id.value;
  }

  Future<void> update(CategoriesCompanion c) async {
    if (!c.id.present) throw ArgumentError('id is required for update');
    final id = c.id.value;
    await (_db.update(_db.categories)..where((row) => row.id.equals(id)))
        .write(c);
    await (_db.update(_db.categories)..where((row) => row.id.equals(id)))
        .write(CategoriesCompanion(
      syncStatus: const Value('pending_sync'),
    ));
  }
}

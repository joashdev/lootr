import 'package:drift/drift.dart' hide isNull;

import '../database/app_database.dart';

class GoalRepo {
  final AppDatabase _db;

  GoalRepo(this._db);

  Stream<List<GoalData>> watchAll() {
    return (_db.select(_db.goals)
          ..where((g) => g.deletedAt.isNull()))
        .watch();
  }

  Stream<GoalData?> watchById(String id) {
    return (_db.select(_db.goals)
          ..where((g) => g.id.equals(id))
          ..limit(1))
        .watch()
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  Future<String> create(GoalsCompanion g) async {
    if (!g.id.present) throw ArgumentError('id is required for create');
    await _db.into(_db.goals).insert(g);
    return g.id.value;
  }

  Future<void> update(GoalsCompanion g) async {
    if (!g.id.present) throw ArgumentError('id is required for update');
    final id = g.id.value;
    await (_db.update(_db.goals)..where((row) => row.id.equals(id))).write(g);
    await (_db.update(_db.goals)..where((row) => row.id.equals(id)))
        .write(GoalsCompanion(
      syncStatus: const Value('pending_sync'),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> addContribution(String id, double amount) async {
    await _db.transaction(() async {
      final goal = await (_db.select(_db.goals)
            ..where((g) => g.id.equals(id))
            ..limit(1))
          .getSingleOrNull();
      if (goal == null) throw StateError('Goal not found: $id');

      final newAmount = goal.currentAmount + amount;

      await (_db.update(_db.goals)..where((g) => g.id.equals(id)))
          .write(GoalsCompanion(
        currentAmount: Value(newAmount),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ));
    });
  }
}

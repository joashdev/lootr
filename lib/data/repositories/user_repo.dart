import 'package:drift/drift.dart' hide isNull;

import '../database/app_database.dart';

class UserRepo {
  final AppDatabase _db;

  UserRepo(this._db);

  Stream<UserData?> watchCurrentUser() {
    return (_db.select(_db.users)..limit(1)).watch().map((rows) {
      return rows.isNotEmpty ? rows.first : null;
    });
  }

  Future<String> create(UsersCompanion u) async {
    if (!u.id.present) throw ArgumentError('id is required for create');
    await _db.into(_db.users).insert(u);
    return u.id.value;
  }

  Future<void> update(UsersCompanion u) async {
    if (!u.id.present) throw ArgumentError('id is required for update');
    final id = u.id.value;
    await (_db.update(_db.users)..where((row) => row.id.equals(id))).write(u);
    await (_db.update(_db.users)..where((row) => row.id.equals(id)))
        .write(UsersCompanion(
      syncStatus: const Value('pending_sync'),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<UserData?> getCurrentUser() async {
    final rows = await (_db.select(_db.users)..limit(1)).get();
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<void> updateAiEnabled(bool enabled) async {
    final user = await (_db.select(_db.users)..limit(1)).getSingleOrNull();
    if (user == null) return;

    await (_db.update(_db.users)..where((u) => u.id.equals(user.id)))
        .write(UsersCompanion(
      aiEnabled: Value(enabled),
      syncStatus: const Value('pending_sync'),
      updatedAt: Value(DateTime.now()),
    ));
  }
}

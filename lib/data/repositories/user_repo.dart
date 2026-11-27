import 'package:drift/drift.dart' hide isNull;

import '../database/app_database.dart';

class UserRepo {
  final AppDatabase _db;

  UserRepo(this._db);

  static const localProfileId = 'local-user-1';

  SimpleSelectStatement<$UsersTable, UserData> _currentUserQuery() =>
      _db.select(_db.users)
        ..where(
          (row) => row.deletedAt.isNull() & row.id.equals('demo-user-1').not(),
        )
        ..orderBy([
          (row) => OrderingTerm.desc(row.id.equals(localProfileId)),
          (row) => OrderingTerm.asc(row.createdAt),
          (row) => OrderingTerm.asc(row.id),
        ])
        ..limit(1);

  Stream<UserData?> watchCurrentUser() =>
      _currentUserQuery().watchSingleOrNull();

  Future<String> create(UsersCompanion user) async {
    if (!user.id.present) throw ArgumentError('id is required for create');
    await _db.into(_db.users).insert(user);
    return user.id.value;
  }

  Future<void> update(UsersCompanion user) async {
    if (!user.id.present) throw ArgumentError('id is required for update');
    await (_db.update(
      _db.users,
    )..where((row) => row.id.equals(user.id.value))).write(
      user.copyWith(
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<UserData?> getCurrentUser() => _currentUserQuery().getSingleOrNull();

  Future<void> saveProfile({
    required String? displayName,
    required String currencyCode,
  }) async {
    await _db.transaction(() async {
      final current = await getCurrentUser();
      final profile = UsersCompanion(
        id: Value(current?.id ?? localProfileId),
        displayName: Value(displayName),
        currencyCode: Value(currencyCode),
      );
      if (current != null) {
        await update(profile);
      } else {
        await _db
            .into(_db.users)
            .insertOnConflictUpdate(
              profile.copyWith(deletedAt: const Value(null)),
            );
      }
    });
  }

  Future<void> updateAiEnabled(bool enabled) async {
    final user = await getCurrentUser();
    if (user == null) return;

    await update(UsersCompanion(id: Value(user.id), aiEnabled: Value(enabled)));
  }
}

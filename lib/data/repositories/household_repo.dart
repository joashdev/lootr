import 'package:drift/drift.dart' hide isNull;

import '../database/app_database.dart';

class HouseholdRepo {
  final AppDatabase _db;

  HouseholdRepo(this._db);

  Stream<List<HouseholdData>> watchAll() {
    return (_db.select(_db.households)
          ..where((h) => h.deletedAt.isNull()))
        .watch();
  }

  Stream<HouseholdData?> watchById(String id) {
    return (_db.select(_db.households)
          ..where((h) => h.id.equals(id))
          ..limit(1))
        .watch()
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  Stream<List<HouseholdMemberData>> watchMembers(String householdId) {
    return (_db.select(_db.householdMembers)
          ..where(
              (m) => m.householdId.equals(householdId) & m.deletedAt.isNull()))
        .watch();
  }

  Future<String> create(HouseholdsCompanion h) async {
    if (!h.id.present) throw ArgumentError('id is required for create');
    await _db.into(_db.households).insert(h);
    return h.id.value;
  }

  Future<void> addMember(HouseholdMembersCompanion m) async {
    await _db.into(_db.householdMembers).insert(m);
  }

  Future<void> updateMemberRole(String memberId, String role) async {
    await (_db.update(_db.householdMembers)..where((m) => m.id.equals(memberId)))
        .write(HouseholdMembersCompanion(
      role: Value(role),
      syncStatus: const Value('pending_sync'),
    ));
  }
}

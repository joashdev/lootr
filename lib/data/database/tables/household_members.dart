import 'package:drift/drift.dart';
import 'users.dart';
import 'households.dart';

@DataClassName('HouseholdMemberData')
@TableIndex(name: 'idx_hh_members_household', columns: {#householdId})
@TableIndex(name: 'idx_hh_members_user', columns: {#userId})
@TableIndex(name: 'uq_hh_members_pair', columns: {#householdId, #userId}, unique: true)
class HouseholdMembers extends Table {
  TextColumn get id => text()();
  TextColumn get householdId => text().named('household_id').references(Households, #id)();
  TextColumn get userId => text().named('user_id').references(Users, #id)();
  TextColumn get role => text()();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  TextColumn get syncStatus => text().named('sync_status').withDefault(const Constant('local_only'))();
  DateTimeColumn get lastSyncedAt => dateTime().named('last_synced_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (role IN (\'owner\', \'member\', \'viewer\'))',
        'CHECK (sync_status IN (\'local_only\', \'pending_sync\', \'synced\', \'sync_failed\'))',
      ];
}

import 'package:drift/drift.dart';
import 'users.dart';

@DataClassName('HouseholdData')
@TableIndex(name: 'idx_households_created_by', columns: {#createdByUserId})
class Households extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get createdByUserId => text().named('created_by_user_id').references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  TextColumn get syncStatus => text().named('sync_status').withDefault(const Constant('local_only'))();
  DateTimeColumn get lastSyncedAt => dateTime().named('last_synced_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (sync_status IN (\'local_only\', \'pending_sync\', \'synced\', \'sync_failed\'))',
      ];
}

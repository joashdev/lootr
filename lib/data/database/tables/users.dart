import 'package:drift/drift.dart';

@DataClassName('UserData')
@TableIndex(name: 'idx_users_email', columns: {#email}, unique: true)
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get email => text().nullable()();
  TextColumn get displayName => text().named('display_name').nullable()();
  TextColumn get currencyCode => text().named('currency_code').withDefault(const Constant('PHP'))();
  TextColumn get locale => text().nullable()();
  TextColumn get timezone => text().nullable()();
  BoolColumn get aiEnabled => boolean().named('ai_enabled').withDefault(const Constant(false))();
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

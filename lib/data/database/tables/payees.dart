import 'package:drift/drift.dart';

@DataClassName('PayeeData')
@TableIndex(name: 'idx_payees_normalized', columns: {#normalizedName}, unique: true)
class Payees extends Table {
  TextColumn get id => text()();
  TextColumn get normalizedName => text().named('normalized_name')();
  TextColumn get displayName => text().named('display_name').nullable()();
  TextColumn get logoUrl => text().named('logo_url').nullable()();
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

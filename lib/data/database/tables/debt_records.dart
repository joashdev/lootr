import 'package:drift/drift.dart';
import 'users.dart';

@DataClassName('DebtRecordData')
@TableIndex(name: 'idx_debt_owner', columns: {#ownerUserId})
@TableIndex(name: 'idx_debt_status', columns: {#status})
class DebtRecords extends Table {
  TextColumn get id => text()();
  TextColumn get ownerUserId => text().named('owner_user_id').references(Users, #id)();
  TextColumn get counterpartyName => text().named('counterparty_name')();
  TextColumn get debtDirection => text().named('debt_direction')();
  RealColumn get amount => real()();
  RealColumn get remainingBalance => real().named('remaining_balance')();
  TextColumn get note => text().nullable()();
  DateTimeColumn get dueDate => dateTime().named('due_date').nullable()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  TextColumn get syncStatus => text().named('sync_status').withDefault(const Constant('local_only'))();
  DateTimeColumn get lastSyncedAt => dateTime().named('last_synced_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

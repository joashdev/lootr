import 'package:drift/drift.dart';
import 'accounts.dart';

@DataClassName('AccountBalanceSnapshotData')
@TableIndex(name: 'idx_snapshots_account_date', columns: {#accountId, #snapshotAt})
class AccountBalanceSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().named('account_id').references(Accounts, #id)();
  RealColumn get balance => real()();
  DateTimeColumn get snapshotAt => dateTime().named('snapshot_at')();

  @override
  Set<Column> get primaryKey => {id};
}

import 'package:drift/drift.dart';
import 'accounts.dart';

@DataClassName('AccountBalanceSnapshotData')
@TableIndex(
  name: 'idx_snapshots_account_date',
  columns: {#accountId, #snapshotAt},
)
class AccountBalanceSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().named('account_id').references(Accounts, #id)();
  RealColumn get balance => real()();
  TextColumn get balanceAtoms => text().named('balance_atoms').nullable()();
  IntColumn get amountScale => integer().named('amount_scale').nullable()();
  TextColumn get currencyCode => text().named('currency_code').nullable()();
  DateTimeColumn get snapshotAt => dateTime().named('snapshot_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (amount_scale IS NULL OR amount_scale >= 0)',
  ];
}

import 'package:drift/drift.dart';

@DataClassName('AccountBalanceSnapshotData')
class AccountBalanceSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer()();
  RealColumn get balance => real()();
  TextColumn get currency => text()();
  DateTimeColumn get snapshotDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

}

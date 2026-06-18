import 'package:drift/drift.dart';

@DataClassName('TransferData')
class Transfers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get fromAccountId => integer()();
  IntColumn get toAccountId => integer()();
  RealColumn get amount => real()();
  TextColumn get currency => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get transferDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

}

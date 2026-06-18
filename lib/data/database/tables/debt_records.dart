import 'package:drift/drift.dart';

@DataClassName('DebtRecordData')
class DebtRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get userId => integer()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  RealColumn get totalAmount => real()();
  RealColumn get remainingAmount => real()();
  RealColumn get interestRate => real().nullable()();
  RealColumn get minimumPayment => real().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

}

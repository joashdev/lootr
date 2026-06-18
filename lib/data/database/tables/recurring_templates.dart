import 'package:drift/drift.dart';

@DataClassName('RecurringTemplateData')
class RecurringTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get accountId => integer()();
  IntColumn get categoryId => integer().nullable()();
  IntColumn get payeeId => integer().nullable()();
  TextColumn get type => text()();
  RealColumn get amount => real()();
  TextColumn get currency => text()();
  TextColumn get description => text().nullable()();
  TextColumn get frequency => text()();
  IntColumn get interval => integer().withDefault(const Constant(1))();
  DateTimeColumn get nextDueDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

}

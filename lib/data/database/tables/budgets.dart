import 'package:drift/drift.dart';

@DataClassName('BudgetData')
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get householdId => integer()();
  IntColumn get categoryId => integer()();
  TextColumn get name => text()();
  RealColumn get amount => real()();
  RealColumn get spent => real().withDefault(const Constant(0))();
  TextColumn get mode => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

}

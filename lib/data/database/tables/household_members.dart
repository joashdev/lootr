import 'package:drift/drift.dart';

@DataClassName('HouseholdMemberData')
class HouseholdMembers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get householdId => integer()();
  IntColumn get userId => integer()();
  TextColumn get role => text()();
  DateTimeColumn get joinedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get leftAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

}

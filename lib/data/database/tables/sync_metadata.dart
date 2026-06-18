import 'package:drift/drift.dart';

@DataClassName('SyncMetadataData')
class SyncMetadata extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncTableName => text().unique()();
  DateTimeColumn get lastPulledAt => dateTime().nullable()();
  DateTimeColumn get lastPushedAt => dateTime().nullable()();
  IntColumn get clockValue => integer().withDefault(const Constant(0))();
}

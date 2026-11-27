import 'package:drift/drift.dart';

/// Local-only provenance for records created by the sample-data loader.
///
/// This table is deliberately excluded from sync. Financial tables keep their
/// normal sync contract, while sample records remain identifiable after an app
/// restart or an interrupted clear operation.
@DataClassName('DemoRecordData')
class DemoRecords extends Table {
  TextColumn get entityType => text().named('entity_type')();
  TextColumn get entityId => text().named('entity_id')();
  IntColumn get seedVersion =>
      integer().named('seed_version').withDefault(const Constant(1))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {entityType, entityId};
}

import 'package:drift/drift.dart';

@DataClassName('SyncMetadataData')
class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

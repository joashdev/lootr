import 'package:drift/drift.dart';

@DataClassName('CategoryData')
@TableIndex(name: 'idx_categories_parent', columns: {#parentCategoryId})
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get parentCategoryId => text()
      .named('parent_category_id')
      .nullable()
      .references(Categories, #id)();
  TextColumn get name => text()();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get emojiIcon => text().named('emoji_icon').nullable()();
  TextColumn get sourceAssetIcon =>
      text().named('source_asset_icon').nullable()();
  IntColumn get sortOrder => integer().named('sort_order').nullable()();
  BoolColumn get isArchived => boolean().named('is_archived').nullable()();
  TextColumn get categoryGroup => text().named('category_group')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('synced'))();
  DateTimeColumn get lastSyncedAt =>
      dateTime().named('last_synced_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (category_group IN (\'expense\', \'income\', \'transfer\'))',
    'CHECK (sync_status IN (\'local_only\', \'pending_sync\', \'synced\', \'sync_failed\'))',
  ];
}

import 'package:drift/drift.dart';
import 'users.dart';
import 'categories.dart';
import 'households.dart';

@DataClassName('BudgetData')
@TableIndex(name: 'idx_budgets_owner_period', columns: {#ownerUserId, #month, #year})
@TableIndex(name: 'uq_budget_category_period', columns: {#ownerUserId, #categoryId, #month, #year}, unique: true)
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get householdId => text().named('household_id').nullable().references(Households, #id)();
  TextColumn get ownerUserId => text().named('owner_user_id').references(Users, #id)();
  TextColumn get categoryId => text().named('category_id').references(Categories, #id)();
  RealColumn get amount => real()();
  IntColumn get month => integer()();
  IntColumn get year => integer()();

  /// Optional visual override. When null the budget inherits the icon/color
  /// of its category (resolved in the presentation layer).
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  TextColumn get syncStatus => text().named('sync_status').withDefault(const Constant('local_only'))();
  DateTimeColumn get lastSyncedAt => dateTime().named('last_synced_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (month BETWEEN 1 AND 12)',
        'CHECK (sync_status IN (\'local_only\', \'pending_sync\', \'synced\', \'sync_failed\'))',
      ];
}

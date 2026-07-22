import 'package:drift/drift.dart';
import 'users.dart';
import 'households.dart';

@DataClassName('AccountData')
@TableIndex(name: 'idx_accounts_owner', columns: {#ownerUserId})
@TableIndex(name: 'idx_accounts_household', columns: {#householdId})
@TableIndex(name: 'idx_accounts_type', columns: {#accountType})
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get householdId =>
      text().named('household_id').nullable().references(Households, #id)();
  TextColumn get ownerUserId =>
      text().named('owner_user_id').references(Users, #id)();
  TextColumn get name => text()();
  TextColumn get accountType => text().named('account_type')();
  RealColumn get balance => real().withDefault(const Constant(0))();
  TextColumn get currencyCode =>
      text().named('currency_code').withDefault(const Constant('PHP'))();
  TextColumn get balanceAtoms => text().named('balance_atoms').nullable()();
  IntColumn get currencyPrecision =>
      integer().named('currency_precision').nullable()();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get emojiIcon => text().named('emoji_icon').nullable()();
  IntColumn get sortOrder => integer().named('sort_order').nullable()();
  BoolColumn get isArchived =>
      boolean().named('is_archived').withDefault(const Constant(false))();
  BoolColumn get isHidden =>
      boolean().named('is_hidden').withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('local_only'))();
  DateTimeColumn get lastSyncedAt =>
      dateTime().named('last_synced_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (account_type IN (\'cash\', \'bank\', \'ewallet\', \'savings\', \'investment\', \'crypto\', \'credit_card\', \'loan\', \'bnpl\'))',
    'CHECK (currency_precision IS NULL OR currency_precision >= 0)',
    'CHECK (sync_status IN (\'local_only\', \'pending_sync\', \'synced\', \'sync_failed\'))',
  ];
}

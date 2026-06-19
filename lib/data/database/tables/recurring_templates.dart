import 'package:drift/drift.dart';
import 'accounts.dart';
import 'categories.dart';
import 'payees.dart';

@DataClassName('RecurringTemplateData')
@TableIndex(name: 'idx_recurring_account', columns: {#accountId})
@TableIndex(name: 'idx_recurring_next', columns: {#nextOccurrenceAt})
class RecurringTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().named('account_id').references(Accounts, #id)();
  TextColumn get categoryId => text().named('category_id').nullable().references(Categories, #id)();
  TextColumn get payeeId => text().named('payee_id').nullable().references(Payees, #id)();
  RealColumn get amount => real()();
  TextColumn get recurrenceRule => text().named('recurrence_rule')();
  BoolColumn get reminderEnabled => boolean().named('reminder_enabled').withDefault(const Constant(true))();
  BoolColumn get autoCreateDisabled => boolean().named('auto_create_disabled').withDefault(const Constant(false))();
  DateTimeColumn get nextOccurrenceAt => dateTime().named('next_occurrence_at').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  TextColumn get syncStatus => text().named('sync_status').withDefault(const Constant('local_only'))();
  DateTimeColumn get lastSyncedAt => dateTime().named('last_synced_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (sync_status IN (\'local_only\', \'pending_sync\', \'synced\', \'sync_failed\'))',
      ];
}

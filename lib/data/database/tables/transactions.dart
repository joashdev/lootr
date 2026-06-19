import 'package:drift/drift.dart';
import 'accounts.dart';
import 'categories.dart';
import 'payees.dart';
import 'recurring_templates.dart';

@DataClassName('TransactionData')
@TableIndex(name: 'idx_transactions_account', columns: {#accountId})
@TableIndex(name: 'idx_transactions_category', columns: {#categoryId})
@TableIndex(name: 'idx_transactions_payee', columns: {#payeeId})
@TableIndex(name: 'idx_transactions_parent', columns: {#parentTransactionId})
@TableIndex(name: 'idx_transactions_occurred_at', columns: {#occurredAt})
@TableIndex(name: 'idx_transactions_direction', columns: {#transactionDirection})
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().named('account_id').references(Accounts, #id)();
  TextColumn get categoryId => text().named('category_id').nullable().references(Categories, #id)();
  TextColumn get payeeId => text().named('payee_id').nullable().references(Payees, #id)();
  TextColumn get parentTransactionId => text().named('parent_transaction_id').nullable().references(Transactions, #id)();
  TextColumn get recurringTemplateId => text().named('recurring_template_id').nullable().references(RecurringTemplates, #id)();
  RealColumn get amount => real()();
  TextColumn get transactionDirection => text().named('transaction_direction')();
  TextColumn get transactionMode => text().named('transaction_mode')();
  TextColumn get transactionSubtype => text().named('transaction_subtype').nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get metadata => text().nullable()();
  DateTimeColumn get occurredAt => dateTime().named('occurred_at')();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  TextColumn get syncStatus => text().named('sync_status').withDefault(const Constant('local_only'))();
  DateTimeColumn get lastSyncedAt => dateTime().named('last_synced_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

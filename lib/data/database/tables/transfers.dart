import 'package:drift/drift.dart';
import 'accounts.dart';

@DataClassName('TransferData')
@TableIndex(name: 'idx_transfers_source', columns: {#sourceAccountId})
@TableIndex(name: 'idx_transfers_dest', columns: {#destinationAccountId})
@TableIndex(name: 'idx_transfers_occurred_at', columns: {#occurredAt})
class Transfers extends Table {
  TextColumn get id => text()();
  @ReferenceName('sourceAccount')
  TextColumn get sourceAccountId =>
      text().named('source_account_id').references(Accounts, #id)();
  @ReferenceName('destAccount')
  TextColumn get destinationAccountId =>
      text().named('destination_account_id').references(Accounts, #id)();
  RealColumn get amount => real()();
  TextColumn get sourceAmountAtoms =>
      text().named('source_amount_atoms').nullable()();
  IntColumn get sourceAmountScale =>
      integer().named('source_amount_scale').nullable()();
  TextColumn get sourceCurrencyCode =>
      text().named('source_currency_code').nullable()();
  TextColumn get destinationAmountAtoms =>
      text().named('destination_amount_atoms').nullable()();
  IntColumn get destinationAmountScale =>
      integer().named('destination_amount_scale').nullable()();
  TextColumn get destinationCurrencyCode =>
      text().named('destination_currency_code').nullable()();
  RealColumn get feeAmount =>
      real().named('fee_amount').nullable().withDefault(const Constant(0))();
  TextColumn get feeAmountAtoms =>
      text().named('fee_amount_atoms').nullable()();
  IntColumn get feeAmountScale =>
      integer().named('fee_amount_scale').nullable()();
  TextColumn get feeCurrencyCode =>
      text().named('fee_currency_code').nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get occurredAt => dateTime().named('occurred_at')();
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
    'CHECK (source_amount_scale IS NULL OR source_amount_scale >= 0)',
    'CHECK (destination_amount_scale IS NULL OR destination_amount_scale >= 0)',
    'CHECK (fee_amount_scale IS NULL OR fee_amount_scale >= 0)',
    'CHECK (sync_status IN (\'local_only\', \'pending_sync\', \'synced\', \'sync_failed\'))',
  ];
}

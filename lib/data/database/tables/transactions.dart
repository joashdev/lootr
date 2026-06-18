import 'package:drift/drift.dart';

@DataClassName('TransactionData')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get accountId => integer()();
  IntColumn get categoryId => integer().nullable()();
  IntColumn get payeeId => integer().nullable()();
  IntColumn get parentTransactionId => integer().nullable()();
  IntColumn get transferId => integer().nullable()();
  TextColumn get type => text()();
  RealColumn get amount => real()();
  TextColumn get currency => text()();
  TextColumn get note => text().nullable()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get transactionDate => dateTime()();
  BoolColumn get isPending => boolean().withDefault(const Constant(false))();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  IntColumn get recurringTemplateId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

}

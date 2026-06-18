import 'package:drift/drift.dart';

@DataClassName('AiProcessingLogData')
class AiProcessingLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().nullable()();
  TextColumn get inputText => text()();
  TextColumn get outputJson => text().nullable()();
  TextColumn get modelUsed => text().nullable()();
  IntColumn get processingTimeMs => integer().nullable()();
  BoolColumn get isSuccess => boolean().withDefault(const Constant(false))();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

}

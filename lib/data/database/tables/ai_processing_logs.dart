import 'package:drift/drift.dart';

@DataClassName('AiProcessingLogData')
@TableIndex(name: 'idx_ai_logs_source', columns: {#sourceType})
@TableIndex(name: 'idx_ai_logs_reference', columns: {#sourceReferenceId})
class AiProcessingLogs extends Table {
  TextColumn get id => text()();
  TextColumn get sourceType => text().named('source_type')();
  TextColumn get sourceReferenceId => text().named('source_reference_id').nullable()();
  TextColumn get modelUsed => text().named('model_used').nullable()();
  TextColumn get extractedPayload => text().named('extracted_payload').nullable()();
  RealColumn get confidenceScore => real().named('confidence_score').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (source_type IN (\'ocr\', \'nlp\', \'categorization\'))',
      ];
}

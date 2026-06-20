import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;

import '../database/app_database.dart';

class AiProcessingLogRepo {
  final AppDatabase _db;

  AiProcessingLogRepo(this._db);

  Future<void> log({
    required String id,
    required String sourceType,
    String? sourceReferenceId,
    String? modelUsed,
    Map<String, dynamic>? extractedPayload,
    double? confidenceScore,
  }) async {
    await _db.into(_db.aiProcessingLogs).insert(
          AiProcessingLogsCompanion.insert(
            id: id,
            sourceType: sourceType,
            sourceReferenceId: Value(sourceReferenceId),
            modelUsed: Value(modelUsed),
            extractedPayload: Value(
              extractedPayload != null ? jsonEncode(extractedPayload) : null,
            ),
            confidenceScore: Value(confidenceScore),
          ),
        );
  }

  Stream<List<AiProcessingLogData>> watchAll() {
    return (_db.select(_db.aiProcessingLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<List<AiProcessingLogData>> getAll() {
    return (_db.select(_db.aiProcessingLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<List<AiProcessingLogData>> getBySource(String sourceType) {
    return (_db.select(_db.aiProcessingLogs)
          ..where((l) => l.sourceType.equals(sourceType))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }
}

import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/sync_metadata_repo.dart';
import 'conflict_applier.dart';
import 'sync_http_client.dart';
import 'syncable_tables.dart';

class PullResult {
  final bool success;
  final String? error;
  final DateTime? newLastSyncedAt;

  const PullResult({
    required this.success,
    this.error,
    this.newLastSyncedAt,
  });
}

class PullClient {
  final AppDatabase _db;
  final SyncHttpClient _httpClient;
  final SyncMetadataRepo _syncMetadataRepo;
  final ConflictApplier _conflictApplier;

  PullClient({
    required AppDatabase db,
    required SyncHttpClient httpClient,
    required String baseUrl,
    required SyncMetadataRepo syncMetadataRepo,
    required ConflictApplier conflictApplier,
  })  : _db = db,
        _httpClient = httpClient,
        _syncMetadataRepo = syncMetadataRepo,
        _conflictApplier = conflictApplier;

  Future<PullResult> pull({String? accessToken}) async {
    try {
      final lastSyncedAtStr =
          await _syncMetadataRepo.get(SyncMetadataRepo.keyLastSyncedAt);

      String? cursor;
      DateTime? serverTime;

      while (true) {
        final body = <String, dynamic>{'limit': 200};
        if (lastSyncedAtStr != null) body['last_synced_at'] = lastSyncedAtStr;
        if (cursor != null) body['cursor'] = cursor;

        final response = await _httpClient.post(
          '/sync/pull',
          body: body,
          accessToken: accessToken,
        );

        if (!response.isSuccess) {
          return PullResult(
            success: false,
            error: 'Pull failed with status ${response.statusCode}',
          );
        }

        final serverTimeStr = response.body['server_time'] as String?;
        if (serverTimeStr != null) {
          serverTime = DateTime.parse(serverTimeStr);
        }

        final changes = response.body['changes'] as Map<String, dynamic>?;
        if (changes != null) {
          await _db.transaction(() async {
            for (final entry in changes.entries) {
              final tableName = entry.key;
              if (!syncableTableNames.contains(tableName)) continue;

              final records = entry.value as List<dynamic>?;
              if (records == null || records.isEmpty) continue;

              for (final record in records) {
                await _applyPullRecord(
                    tableName, record as Map<String, dynamic>);
              }
            }
          });
        }

        final hasMore = response.body['has_more'] as bool? ?? false;
        if (!hasMore) break;

        cursor = response.body['next_cursor'] as String?;
        if (cursor == null) break;
      }

      if (serverTime != null) {
        await _syncMetadataRepo.set(
          SyncMetadataRepo.keyLastSyncedAt,
          serverTime.toUtc().toIso8601String(),
        );
      }

      return PullResult(success: true, newLastSyncedAt: serverTime);
    } catch (e) {
      return PullResult(success: false, error: e.toString());
    }
  }

  Future<void> _applyPullRecord(
      String tableName, Map<String, dynamic> serverRecord) async {
    final id = serverRecord['id'] as String;
    final serverUpdatedAtStr = serverRecord['updated_at'] as String?;
    final serverUpdatedAt = serverUpdatedAtStr != null
        ? DateTime.parse(serverUpdatedAtStr)
        : DateTime.now().toUtc();

    final existing = await _getLocalRecord(tableName, id);

    if (existing == null) {
      await _insertRecord(tableName, serverRecord, serverUpdatedAt);
      return;
    }

    final localUpdatedAt = _parseDateTime(existing['updated_at']);

    if (_conflictApplier.shouldApplyServerRecord(
        serverUpdatedAt, localUpdatedAt)) {
      final serverDeletedAt = serverRecord['deleted_at'] as String?;
      if (serverDeletedAt != null) {
        await _softDeleteLocal(
            tableName, id, DateTime.parse(serverDeletedAt));
      } else {
        await _updateRecord(tableName, serverRecord, serverUpdatedAt);
      }
    }
  }

  Future<Map<String, dynamic>?> _getLocalRecord(
      String tableName, String id) async {
    try {
      final query = 'SELECT * FROM $tableName WHERE id = ? LIMIT 1';
      final rows = await _db
          .customSelect(query, variables: [Variable.withString(id)])
          .get();
      if (rows.isEmpty) return null;
      return rows.first.data;
    } catch (_) {
      return null;
    }
  }

  Future<void> _insertRecord(
    String tableName,
    Map<String, dynamic> serverRecord,
    DateTime serverUpdatedAt,
  ) async {
    final def = syncableTableDefinitions.cast<SyncTableDefinition?>().firstWhere(
      (d) => d!.name == tableName,
      orElse: () => null,
    );
    if (def == null) return;

    final columns = [...def.dataColumns, 'sync_status', 'last_synced_at'];
    final valuesList = columns.map((col) {
      if (col == 'sync_status') return "'synced'";
      if (col == 'last_synced_at') {
        return "'${serverUpdatedAt.toUtc().toIso8601String()}'";
      }
      return _toSqlLiteral(serverRecord[col]);
    }).join(', ');

    final sql =
        'INSERT INTO $tableName (${columns.join(', ')}) VALUES ($valuesList)';
    await _db.customStatement(sql);
  }

  Future<void> _updateRecord(
    String tableName,
    Map<String, dynamic> serverRecord,
    DateTime serverUpdatedAt,
  ) async {
    final id = serverRecord['id'] as String;
    final updates = <String>[];
    for (final entry in serverRecord.entries) {
      if (entry.key == 'id') continue;
      updates.add("${entry.key} = ${_toSqlLiteral(entry.value)}");
    }
    updates.add("sync_status = 'synced'");
    updates.add(
        "last_synced_at = '${serverUpdatedAt.toUtc().toIso8601String()}'");

    final sql =
        'UPDATE $tableName SET ${updates.join(', ')} WHERE id = ${_toSqlLiteral(id)}';
    await _db.customStatement(sql);
  }

  Future<void> _softDeleteLocal(
    String tableName,
    String id,
    DateTime deletedAt,
  ) async {
    await _db.customUpdate(
      'UPDATE $tableName SET deleted_at = ?, sync_status = ?, updated_at = ? WHERE id = ?',
      variables: [
        Variable.withDateTime(deletedAt),
        Variable.withString('synced'),
        Variable.withDateTime(deletedAt),
        Variable.withString(id),
      ],
    );
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _toSqlLiteral(dynamic value) {
    if (value == null) return 'NULL';
    if (value is int) return value.toString();
    if (value is double) return value.toString();
    if (value is bool) return value ? '1' : '0';
    if (value is String) {
      final escaped = value.replaceAll("'", "''");
      return "'$escaped'";
    }
    final escaped = value.toString().replaceAll("'", "''");
    return "'$escaped'";
  }
}

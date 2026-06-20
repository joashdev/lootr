import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/sync_metadata_repo.dart';
import 'sync_http_client.dart';
import 'syncable_tables.dart';

class PushResult {
  final bool success;
  final String? error;

  const PushResult({required this.success, this.error});
}

class PushClient {
  final AppDatabase _db;
  final SyncHttpClient _httpClient;
  final SyncMetadataRepo _syncMetadataRepo;

  PushClient({
    required AppDatabase db,
    required SyncHttpClient httpClient,
    required String baseUrl,
    required SyncMetadataRepo syncMetadataRepo,
  })  : _db = db,
        _httpClient = httpClient,
        _syncMetadataRepo = syncMetadataRepo;

  Future<PushResult> push({String? accessToken}) async {
    try {
      final changes = await _collectPendingChanges();
      final deletedChanges = await _collectDeletedRecords();

      final allChanges = <String, List<Map<String, dynamic>>>{};
      for (final table in syncableTableDefinitions) {
        final tableChanges = <Map<String, dynamic>>[];
        if (changes.containsKey(table.name)) {
          tableChanges.addAll(changes[table.name]!);
        }
        if (deletedChanges.containsKey(table.name)) {
          tableChanges.addAll(deletedChanges[table.name]!);
        }
        if (tableChanges.isNotEmpty) {
          allChanges[table.name] = tableChanges;
        }
      }

      if (allChanges.isEmpty) {
        return const PushResult(success: true);
      }

      final response = await _httpClient.post(
        '/sync/push',
        body: {'changes': allChanges},
        accessToken: accessToken,
      );

      if (response.isNetworkError || response.isServerError) {
        await _markAllPushedAsFailed(changes);
        await _markAllPushedAsFailed(deletedChanges);
        return PushResult(success: false, error: 'Network or server error');
      }

      if (!response.isSuccess) {
        await _markAllPushedAsFailed(changes);
        await _markAllPushedAsFailed(deletedChanges);
        return PushResult(
          success: false,
          error: 'Push failed with status ${response.statusCode}',
        );
      }

      await _processPushResponse(response.body);
      return const PushResult(success: true);
    } catch (e) {
      return PushResult(success: false, error: e.toString());
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> _collectPendingChanges() async {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final table in syncableTableDefinitions) {
      final columns = table.dataColumns.join(', ');
      final query = '''
        SELECT $columns
        FROM ${table.name}
        WHERE sync_status IN ('local_only', 'pending_sync', 'sync_failed')
          AND deleted_at IS NULL
      ''';
      final rows = await _db.customSelect(query).get();
      if (rows.isNotEmpty) {
        result[table.name] = rows.map((row) {
          final map = <String, dynamic>{};
          for (final col in table.dataColumns) {
            map[col] = _serializeValue(row.data[col]);
          }
          return map;
        }).toList();
      }
    }
    return result;
  }

  Future<Map<String, List<Map<String, dynamic>>>> _collectDeletedRecords() async {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final table in syncableTableDefinitions) {
      final columns = table.dataColumns.join(', ');
      final query = '''
        SELECT $columns
        FROM ${table.name}
        WHERE deleted_at IS NOT NULL
          AND sync_status != 'synced'
      ''';
      final rows = await _db.customSelect(query).get();
      if (rows.isNotEmpty) {
        result[table.name] = rows.map((row) {
          final map = <String, dynamic>{};
          for (final col in table.dataColumns) {
            map[col] = _serializeValue(row.data[col]);
          }
          return map;
        }).toList();
      }
    }
    return result;
  }

  dynamic _serializeValue(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is bool) return value ? 1 : 0;
    if (value is int) return value;
    if (value is double) return value;
    return value.toString();
  }

  Future<void> _processPushResponse(Map<String, dynamic> body) async {
    final results = body['results'] as Map<String, dynamic>?;
    if (results == null) return;

    for (final entry in results.entries) {
      final tableName = entry.key;
      if (!syncableTableNames.contains(tableName)) continue;
      final tableResults = entry.value as List<dynamic>?;
      if (tableResults == null) continue;

      for (final recordResult in tableResults) {
        final record = recordResult as Map<String, dynamic>;
        final id = record['id'] as String;
        final status = record['status'] as String;

        switch (status) {
          case 'applied':
            final serverUpdatedAt = record['server_updated_at'] as String?;
            final syncedAt = serverUpdatedAt != null
                ? DateTime.parse(serverUpdatedAt)
                : DateTime.now().toUtc();
            await _db.customUpdate(
              'UPDATE $tableName SET sync_status = ?, last_synced_at = ? WHERE id = ?',
              variables: [
                Variable.withString('synced'),
                Variable.withDateTime(syncedAt),
                Variable.withString(id),
              ],
            );
            break;

          case 'conflict':
            final serverRecord = record['server_record'] as Map<String, dynamic>?;
            if (serverRecord != null) {
              await _replaceWithServerRecord(tableName, serverRecord);
            }
            break;

          case 'error':
            await _db.customUpdate(
              'UPDATE $tableName SET sync_status = ? WHERE id = ?',
              variables: [
                Variable.withString('sync_failed'),
                Variable.withString(id),
              ],
            );
            final errorDetail = record['message'] as String? ?? 'Unknown push error';
            await _syncMetadataRepo.set(
              SyncMetadataRepo.keyLastSyncError,
              '$tableName/$id: $errorDetail',
            );
            break;
        }
      }
    }
  }

  Future<void> _replaceWithServerRecord(
    String tableName,
    Map<String, dynamic> serverRecord,
  ) async {
    final def = syncableTableDefinitions.cast<SyncTableDefinition?>().firstWhere(
      (d) => d!.name == tableName,
      orElse: () => null,
    );
    if (def == null) return;

    final columns = [...def.dataColumns, 'sync_status', 'last_synced_at'];
    final now = DateTime.now().toUtc();
    final updatedAtStr = serverRecord['updated_at'];
    final lastSyncedAt = updatedAtStr != null
        ? DateTime.parse(updatedAtStr.toString())
        : now;

    final valuesList = <String>[];
    for (final col in columns) {
      if (col == 'sync_status') {
        valuesList.add("'synced'");
      } else if (col == 'last_synced_at') {
        valuesList.add("'${lastSyncedAt.toUtc().toIso8601String()}'");
      } else {
        final val = serverRecord[col];
        valuesList.add(_toSqlLiteral(val));
      }
    }

    final setClauses = <String>[];
    for (final col in columns) {
      if (col == 'id') continue;
      if (col == 'sync_status') {
        setClauses.add("$col = 'synced'");
      } else if (col == 'last_synced_at') {
        setClauses.add("$col = '${lastSyncedAt.toUtc().toIso8601String()}'");
      } else {
        final val = serverRecord[col];
        setClauses.add("$col = ${_toSqlLiteral(val)}");
      }
    }

    final sql = '''
      INSERT INTO $tableName (${columns.join(', ')})
      VALUES (${valuesList.join(', ')})
      ON CONFLICT(id) DO UPDATE SET ${setClauses.join(', ')}
    ''';

    await _db.customStatement(sql);
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

  Future<void> _markAllPushedAsFailed(
    Map<String, List<Map<String, dynamic>>> changes,
  ) async {
    for (final entry in changes.entries) {
      for (final row in entry.value) {
        final id = row['id'] as String?;
        if (id == null) continue;
        await _db.customUpdate(
          'UPDATE ${entry.key} SET sync_status = ? WHERE id = ?',
          variables: [
            Variable.withString('sync_failed'),
            Variable.withString(id),
          ],
        );
      }
    }
  }
}

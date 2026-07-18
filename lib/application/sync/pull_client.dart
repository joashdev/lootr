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

  const PullResult({required this.success, this.error, this.newLastSyncedAt});
}

class PullClient {
  final AppDatabase _db;
  final SyncHttpClient _httpClient;
  final SyncMetadataRepo _syncMetadataRepo;
  final ConflictApplier _conflictApplier;

  PullClient({
    required AppDatabase db,
    required SyncHttpClient httpClient,
    required SyncMetadataRepo syncMetadataRepo,
    required ConflictApplier conflictApplier,
  }) : // Keep public named arguments stable while storing them privately.
       // ignore: prefer_initializing_formals
       _db = db,
       // ignore: prefer_initializing_formals
       _httpClient = httpClient,
       // ignore: prefer_initializing_formals
       _syncMetadataRepo = syncMetadataRepo,
       // ignore: prefer_initializing_formals
       _conflictApplier = conflictApplier;

  Future<PullResult> pull({String? accessToken}) async {
    try {
      final lastSyncedAtStr = await _syncMetadataRepo.get(
        SyncMetadataRepo.keyLastSyncedAt,
      );

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
                  tableName,
                  record as Map<String, dynamic>,
                );
              }
            }
          });
        }

        final hasMore = response.body['has_more'] as bool? ?? false;
        if (!hasMore) break;

        cursor = response.body['next_cursor'] as String?;
        if (cursor == null) break;
      }

      final effectiveServerTime = serverTime ?? DateTime.now().toUtc();
      await _syncMetadataRepo.set(
        SyncMetadataRepo.keyLastSyncedAt,
        effectiveServerTime.toUtc().toIso8601String(),
      );

      return PullResult(success: true, newLastSyncedAt: effectiveServerTime);
    } catch (e) {
      return PullResult(success: false, error: e.toString());
    }
  }

  Future<void> _applyPullRecord(
    String tableName,
    Map<String, dynamic> serverRecord,
  ) async {
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

    if (_conflictApplier.serverWins(serverUpdatedAt, localUpdatedAt)) {
      final serverDeletedAt = serverRecord['deleted_at'] as String?;
      if (serverDeletedAt != null) {
        await _softDeleteLocal(tableName, id, DateTime.parse(serverDeletedAt));
      } else {
        await _updateRecord(tableName, serverRecord, serverUpdatedAt);
      }
    }
  }

  Future<Map<String, dynamic>?> _getLocalRecord(
    String tableName,
    String id,
  ) async {
    final query = 'SELECT * FROM $tableName WHERE id = ? LIMIT 1';
    final rows = await _db
        .customSelect(query, variables: [Variable.withString(id)])
        .get();
    if (rows.isEmpty) return null;
    return rows.first.data;
  }

  Future<void> _insertRecord(
    String tableName,
    Map<String, dynamic> serverRecord,
    DateTime serverUpdatedAt,
  ) async {
    final def = syncableTableDefinitions
        .cast<SyncTableDefinition?>()
        .firstWhere((d) => d!.name == tableName, orElse: () => null);
    if (def == null) return;

    final columns = [...def.dataColumns, 'sync_status', 'last_synced_at'];
    final valueParts = <String>[];
    final valueVars = <Variable<Object>>[];
    final setParts = <String>[];
    final setVars = <Variable<Object>>[];

    for (final col in columns) {
      if (col == 'sync_status') {
        valueParts.add('?');
        valueVars.add(Variable.withString('synced'));
        setParts.add("$col = ?");
        setVars.add(Variable.withString('synced'));
      } else if (col == 'last_synced_at') {
        valueParts.add('?');
        valueVars.add(Variable.withDateTime(serverUpdatedAt.toUtc()));
        setParts.add("$col = ?");
        setVars.add(Variable.withDateTime(serverUpdatedAt.toUtc()));
      } else {
        final val = serverRecord[col];
        if (val == null) {
          valueParts.add('NULL');
          if (col != 'id') setParts.add("$col = NULL");
        } else {
          valueParts.add('?');
          valueVars.add(_variableFor(val));
          if (col != 'id') {
            setParts.add("$col = ?");
            setVars.add(_variableFor(val));
          }
        }
      }
    }

    final sql =
        'INSERT INTO $tableName (${columns.join(', ')}) VALUES (${valueParts.join(', ')}) '
        'ON CONFLICT(id) DO UPDATE SET ${setParts.join(', ')}';
    await _db.customUpdate(sql, variables: [...valueVars, ...setVars]);
  }

  Future<void> _updateRecord(
    String tableName,
    Map<String, dynamic> serverRecord,
    DateTime serverUpdatedAt,
  ) async {
    final id = serverRecord['id'];
    final setClauses = <String>[];
    final variables = <Variable<Object>>[];

    for (final entry in serverRecord.entries) {
      if (entry.key == 'id') continue;
      if (entry.value == null) {
        setClauses.add("${entry.key} = NULL");
      } else {
        setClauses.add("${entry.key} = ?");
        variables.add(_variableFor(entry.value));
      }
    }
    setClauses.add("sync_status = ?");
    variables.add(Variable.withString('synced'));
    setClauses.add("last_synced_at = ?");
    variables.add(Variable.withDateTime(serverUpdatedAt.toUtc()));

    final sql = 'UPDATE $tableName SET ${setClauses.join(', ')} WHERE id = ?';
    variables.add(_variableFor(id));
    await _db.customUpdate(sql, variables: variables);
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

  Variable<Object> _variableFor(dynamic value) {
    if (value is int) return Variable.withInt(value);
    if (value is double) return Variable.withReal(value);
    if (value is bool) return Variable.withInt(value ? 1 : 0);
    if (value is DateTime) return Variable.withDateTime(value);
    return Variable.withString(value.toString());
  }
}

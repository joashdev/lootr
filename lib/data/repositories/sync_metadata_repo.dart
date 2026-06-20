import '../database/app_database.dart';

class SyncMetadataRepo {
  final AppDatabase _db;

  SyncMetadataRepo(this._db);

  static const keyLastSyncedAt = 'last_synced_at';
  static const keyLastSyncAttemptAt = 'last_sync_attempt_at';
  static const keyLastSyncStatus = 'last_sync_status';
  static const keyLastSyncError = 'last_sync_error';
  static const keySyncFailedCount = 'sync_failed_count';
  static const keySyncPendingCount = 'sync_pending_count';

  Future<String?> get(String key) async {
    final rows = await (_db.select(_db.syncMetadata)
          ..where((m) => m.key.equals(key))
          ..limit(1))
        .get();
    return rows.isNotEmpty ? rows.first.value : null;
  }

  Future<void> set(String key, String value) async {
    await _db.into(_db.syncMetadata).insertOnConflictUpdate(
          SyncMetadataCompanion.insert(key: key, value: value),
        );
  }
}

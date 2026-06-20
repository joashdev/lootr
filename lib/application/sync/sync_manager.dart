import 'dart:async';

import '../../data/database/app_database.dart';
import '../../data/repositories/sync_metadata_repo.dart';
import 'conflict_applier.dart';
import 'connectivity_monitor.dart';
import 'pull_client.dart';
import 'push_client.dart';
import 'sync_http_client.dart';
import 'syncable_tables.dart';

class SyncManager {
  final AppDatabase _db;
  final SyncMetadataRepo _syncMetadataRepo;
  final PushClient _pushClient;
  final PullClient _pullClient;
  final ConnectivityMonitor _connectivityMonitor;

  bool _syncInProgress = false;
  bool _pendingSync = false;
  bool _disposed = false;
  final StreamController<void> _syncCompleteController =
      StreamController<void>.broadcast();

  final String? _storedAccessToken;
  final String? Function()? _onTokenExpiredSync;
  final Future<String?> Function()? _onTokenExpired;

  Timer? _retryTimer;
  int _retryDelay = 30;
  static const _maxRetryDelay = 600;

  SyncManager({
    required AppDatabase db,
    required SyncMetadataRepo syncMetadataRepo,
    required SyncHttpClient httpClient,
    required ConnectivityMonitor connectivityMonitor,
    String? accessToken,
    String? Function()? onTokenExpired,
    Future<String?> Function()? onTokenExpiredAsync,
    ConflictApplier? conflictApplier,
  })  : _db = db,
        _syncMetadataRepo = syncMetadataRepo,
        _connectivityMonitor = connectivityMonitor,
        _storedAccessToken = accessToken,
        _onTokenExpiredSync = onTokenExpired,
        _onTokenExpired = onTokenExpiredAsync,
        _pushClient = PushClient(
          db: db,
          httpClient: httpClient,
          syncMetadataRepo: syncMetadataRepo,
        ),
        _pullClient = PullClient(
          db: db,
          httpClient: httpClient,
          syncMetadataRepo: syncMetadataRepo,
          conflictApplier: conflictApplier ?? ConflictApplier(),
        );

  Stream<void> get onSyncComplete => _syncCompleteController.stream;

  Future<void> sync({
    String? accessToken,
    String? Function()? onTokenExpired,
    Future<String?> Function()? onTokenExpiredAsync,
  }) async {
    if (_disposed) return;
    final token = accessToken ?? _storedAccessToken;
    if (!_acquireLock()) return;

    try {
      final now = DateTime.now().toUtc();
      await _syncMetadataRepo.set(
          SyncMetadataRepo.keyLastSyncAttemptAt, now.toIso8601String());

      final isAuthenticated = token != null;
      if (!isAuthenticated) {
        await _syncMetadataRepo.set(
            SyncMetadataRepo.keyLastSyncStatus, 'aborted_auth');
        return;
      }

      final online = await _connectivityMonitor.isOnline;
      if (!online) {
        await _syncMetadataRepo.set(
            SyncMetadataRepo.keyLastSyncStatus, 'aborted_offline');
        return;
      }

      var effectiveToken = token;
      final pushResult = await _pushClient.push(accessToken: effectiveToken);
      if (!pushResult.success) {
        await _syncMetadataRepo.set(
            SyncMetadataRepo.keyLastSyncStatus, 'failed');
        await _syncMetadataRepo.set(
            SyncMetadataRepo.keyLastSyncError, pushResult.error ?? 'Push failed');

        if (pushResult.error?.contains('Unauthorized') == true ||
            pushResult.error?.contains('401') == true) {
          String? newToken;
          if (onTokenExpiredAsync != null) {
            newToken = await onTokenExpiredAsync();
          } else if (onTokenExpired != null) {
            newToken = onTokenExpired();
          } else if (_onTokenExpired != null) {
            newToken = await _onTokenExpired!();
          } else if (_onTokenExpiredSync != null) {
            newToken = _onTokenExpiredSync!();
          }
          if (newToken != null) {
            effectiveToken = newToken;
            final retryPush = await _pushClient.push(accessToken: effectiveToken);
            if (!retryPush.success) {
              await _scheduleRetry();
              return;
            }
          } else {
            await _scheduleRetry();
            return;
          }
        } else {
          await _scheduleRetry();
          return;
        }
      }

      final pullResult = await _pullClient.pull(accessToken: effectiveToken);
      if (!pullResult.success) {
        await _syncMetadataRepo.set(
            SyncMetadataRepo.keyLastSyncStatus, 'partial');
        await _syncMetadataRepo.set(
            SyncMetadataRepo.keyLastSyncError,
            pullResult.error ?? 'Pull failed (push was successful)');
      }

      await _postSyncHooks();

      _retryDelay = 30;

      await _updateSyncMetadata(true);
    } catch (e) {
      await _syncMetadataRepo.set(
          SyncMetadataRepo.keyLastSyncStatus, 'failed');
      await _syncMetadataRepo.set(
          SyncMetadataRepo.keyLastSyncError, e.toString());
      await _scheduleRetry();
    } finally {
      _releaseLock();
      _syncCompleteController.add(null);
    }
  }

  bool _acquireLock() {
    if (_syncInProgress) {
      _pendingSync = true;
      return false;
    }
    _syncInProgress = true;
    return true;
  }

  void _releaseLock() {
    _syncInProgress = false;
    if (_pendingSync && !_disposed) {
      _pendingSync = false;
      scheduleMicrotask(() => sync());
    }
  }

  Future<void> _postSyncHooks() async {
    try {
      await _countSyncRecords();
    } catch (_) {}
  }

  Future<void> _countSyncRecords() async {
    int failedCount = 0;
    int pendingCount = 0;
    for (final tableName in syncableTableNames) {
      final failedQuery =
          "SELECT COUNT(*) as cnt FROM $tableName WHERE sync_status = 'sync_failed'";
      final failedRows = await _db.customSelect(failedQuery).get();
      if (failedRows.isNotEmpty) {
        failedCount += _parseCount(failedRows.first.data['cnt']);
      }

      final pendingQuery =
          "SELECT COUNT(*) as cnt FROM $tableName WHERE sync_status IN ('pending_sync', 'local_only')";
      final pendingRows = await _db.customSelect(pendingQuery).get();
      if (pendingRows.isNotEmpty) {
        pendingCount += _parseCount(pendingRows.first.data['cnt']);
      }
    }
    await _syncMetadataRepo.set(
        SyncMetadataRepo.keySyncFailedCount, failedCount.toString());
    await _syncMetadataRepo.set(
        SyncMetadataRepo.keySyncPendingCount, pendingCount.toString());
  }

  int _parseCount(dynamic cnt) {
    if (cnt is int) return cnt;
    if (cnt is String) return int.tryParse(cnt) ?? 0;
    if (cnt is double) return cnt.toInt();
    return 0;
  }

  Future<void> _updateSyncMetadata(bool success) async {
    try {
      await _countSyncRecords();

      if (success) {
        final failedCount =
            await _syncMetadataRepo.get(SyncMetadataRepo.keySyncFailedCount);
        if (failedCount != null && int.tryParse(failedCount) != null) {
          if (int.parse(failedCount) > 0) {
            await _syncMetadataRepo.set(
                SyncMetadataRepo.keyLastSyncStatus, 'partial');
            return;
          }
        }
        await _syncMetadataRepo.set(
            SyncMetadataRepo.keyLastSyncStatus, 'success');
      }
    } catch (_) {}
  }

  Future<void> _scheduleRetry() async {
    if (_disposed) return;
    _retryTimer?.cancel();
    final delay = _retryDelay;
    _retryDelay = (_retryDelay * 2).clamp(30, _maxRetryDelay);

    _retryTimer = Timer(Duration(seconds: delay), () {
      if (!_disposed) sync();
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    await _syncCompleteController.close();
  }
}

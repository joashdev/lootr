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
    required String baseUrl,
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
          baseUrl: baseUrl,
          syncMetadataRepo: syncMetadataRepo,
        ),
        _pullClient = PullClient(
          db: db,
          httpClient: httpClient,
          baseUrl: baseUrl,
          syncMetadataRepo: syncMetadataRepo,
          conflictApplier: conflictApplier ?? ConflictApplier(),
        );

  Stream<void> get onSyncComplete => _syncCompleteController.stream;

  Future<void> sync({
    String? accessToken,
    String? Function()? onTokenExpired,
    Future<String?> Function()? onTokenExpiredAsync,
  }) async {
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

      final pushResult = await _pushClient.push(accessToken: token);
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
            final retryPush = await _pushClient.push(accessToken: newToken);
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

      final pullResult = await _pullClient.pull(accessToken: token);
      if (!pullResult.success) {
        await _syncMetadataRepo.set(
            SyncMetadataRepo.keyLastSyncStatus, 'partial');
        await _syncMetadataRepo.set(
            SyncMetadataRepo.keyLastSyncError,
            pullResult.error ?? 'Pull failed (push was successful)');
      }

      await _postSyncHooks();

      await _updateSyncMetadata(true);

      _retryDelay = 30;

      await _syncMetadataRepo.set(
          SyncMetadataRepo.keyLastSyncStatus, 'success');
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
    if (_pendingSync) {
      _pendingSync = false;
      scheduleMicrotask(() => sync());
    }
  }

  Future<void> _postSyncHooks() async {
    try {
      await _countSyncFailedRecords();
    } catch (_) {}
  }

  Future<void> _countSyncFailedRecords() async {
    int count = 0;
    for (final tableName in syncableTableNames) {
      final query =
          "SELECT COUNT(*) as cnt FROM $tableName WHERE sync_status = 'sync_failed'";
      final rows = await _db.customSelect(query).get();
      if (rows.isNotEmpty) {
        final cnt = rows.first.data['cnt'];
        if (cnt is int) {
          count += cnt;
        } else if (cnt is String) {
          count += int.tryParse(cnt) ?? 0;
        } else if (cnt is double) {
          count += cnt.toInt();
        }
      }
    }
    await _syncMetadataRepo.set(
        SyncMetadataRepo.keySyncFailedCount, count.toString());
  }

  Future<void> _updateSyncMetadata(bool success) async {
    try {
      await _countSyncFailedRecords();

      if (success) {
        final failedCount =
            await _syncMetadataRepo.get(SyncMetadataRepo.keySyncFailedCount);
        if (failedCount != null && int.tryParse(failedCount) != null) {
          if (int.parse(failedCount) > 0) {
            await _syncMetadataRepo.set(
                SyncMetadataRepo.keyLastSyncStatus, 'partial');
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _scheduleRetry() async {
    _retryTimer?.cancel();
    final delay = _retryDelay;
    _retryDelay = (_retryDelay * 2).clamp(30, _maxRetryDelay);

    _retryTimer = Timer(Duration(seconds: delay), () {
      sync();
    });
  }

  Future<void> dispose() async {
    _retryTimer?.cancel();
    await _syncCompleteController.close();
  }
}

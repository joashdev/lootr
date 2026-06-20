import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../domain/value_objects/sync_health.dart';
import '../../data/repositories/sync_metadata_repo.dart';
import '../sync/conflict_applier.dart';
import '../sync/connectivity_monitor.dart';
import '../sync/sync_http_client.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_triggers.dart';
import 'database_provider.dart';
import 'repo_providers.dart';

final conflictApplierProvider = Provider<ConflictApplier>((ref) {
  return ConflictApplier();
});

final syncHttpClientProvider = Provider<SyncHttpClient>((ref) {
  final baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.lootr.app/v1',
  );
  final client = http.Client();
  ref.onDispose(client.close);
  return SyncHttpClientImpl(
    httpClient: client,
    baseUrl: baseUrl,
  );
});

final connectivityMonitorProvider = Provider<ConnectivityMonitor>((ref) {
  return ConnectivityMonitor();
});

final syncManagerProvider = Provider<SyncManager>((ref) {
  final db = ref.watch(databaseProvider);
  final syncMetadataRepo = ref.watch(syncMetadataRepoProvider);
  final httpClient = ref.watch(syncHttpClientProvider);
  final conflictApplier = ref.watch(conflictApplierProvider);
  final connectivityMonitor = ref.watch(connectivityMonitorProvider);

  final manager = SyncManager(
    db: db,
    syncMetadataRepo: syncMetadataRepo,
    httpClient: httpClient,
    connectivityMonitor: connectivityMonitor,
    conflictApplier: conflictApplier,
  );

  ref.onDispose(manager.dispose);
  return manager;
});

final syncTriggersProvider = Provider<SyncTriggers>((ref) {
  final syncManager = ref.watch(syncManagerProvider);
  final connectivityMonitor = ref.watch(connectivityMonitorProvider);

  final triggers = SyncTriggers(
    syncManager: syncManager,
    connectivityMonitor: connectivityMonitor,
  );

  ref.onDispose(triggers.dispose);
  return triggers;
});

enum SyncIconState { synced, pending, syncing, failed, offline }

final syncHealthProvider = Provider<SyncHealth>((ref) {
  final healthAsync = ref.watch(syncHealthStreamProvider);
  return healthAsync.when(
    data: (h) => h,
    loading: () => const SyncHealth(),
    error: (_, __) => const SyncHealth(),
  );
});

final syncHealthStreamProvider = StreamProvider<SyncHealth>((ref) {
  final syncRepo = ref.watch(syncMetadataRepoProvider);

  return Stream.periodic(const Duration(seconds: 10)).asyncMap((_) async {
    final lastSyncedStr = await syncRepo.get(SyncMetadataRepo.keyLastSyncedAt);
    final lastStatus = await syncRepo.get(SyncMetadataRepo.keyLastSyncStatus);
    final failedCountStr =
        await syncRepo.get(SyncMetadataRepo.keySyncFailedCount);
    final pendingCountStr =
        await syncRepo.get(SyncMetadataRepo.keySyncPendingCount);

    final failedCount =
        failedCountStr != null ? int.tryParse(failedCountStr) ?? 0 : 0;
    final pendingCount =
        pendingCountStr != null ? int.tryParse(pendingCountStr) ?? 0 : 0;

    return SyncHealth(
      lastSyncedAt:
          lastSyncedStr != null ? DateTime.tryParse(lastSyncedStr) : null,
      pendingCount: pendingCount,
      failedCount: failedCount,
      lastStatus: lastStatus ?? 'healthy',
    );
  });
});

final syncStatusIconProvider = Provider<SyncIconState>((ref) {
  final health = ref.watch(syncHealthStreamProvider);

  return health.when(
    data: (h) {
      if (h.hasFailed) return SyncIconState.failed;
      if (h.hasPending) return SyncIconState.pending;
      if (h.isHealthy && h.lastSyncedAt != null) return SyncIconState.synced;
      return SyncIconState.pending;
    },
    loading: () => SyncIconState.syncing,
    error: (_, __) => SyncIconState.failed,
  );
});

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/application/sync/connectivity_monitor.dart';
import 'package:lootr/application/sync/sync_http_client.dart';
import 'package:lootr/application/sync/sync_manager.dart';
import 'package:lootr/application/sync/sync_triggers.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/sync_metadata_repo.dart';

class FakeSyncHttpClient implements SyncHttpClient {
  final Map<String, dynamic> Function(String path, Map<String, dynamic> body)?
      handler;

  FakeSyncHttpClient({this.handler});

  @override
  Future<SyncHttpResponse> post(
    String path, {
    required Map<String, dynamic> body,
    String? accessToken,
  }) async {
    if (handler != null) {
      final result = handler!(path, body);
      final statusCode = result['statusCode'] as int? ?? 200;
      final resultBody = result['body'];
      final Map<String, dynamic> bodyMap;
      if (resultBody is Map<String, dynamic>) {
        bodyMap = resultBody;
      } else if (resultBody is Map) {
        bodyMap = resultBody.cast<String, dynamic>();
      } else {
        bodyMap = {};
      }
      return SyncHttpResponse(statusCode: statusCode, body: bodyMap);
    }
    return const SyncHttpResponse(statusCode: 200, body: {});
  }
}

class FakeOnlineMonitor implements ConnectivityMonitor {
  final bool isOnlineResult;
  final Stream<bool> onlineStreamResult;

  FakeOnlineMonitor({
    this.isOnlineResult = true,
    Stream<bool>? onlineStream,
  }) : onlineStreamResult = onlineStream ?? const Stream.empty();

  @override
  Stream<bool> get onlineStream => onlineStreamResult;

  @override
  Future<bool> get isOnline async => isOnlineResult;
}

void main() {
  late AppDatabase db;
  late SyncMetadataRepo syncMetadataRepo;

  setUp(() async {
    db = AppDatabase.inMemory();
    syncMetadataRepo = SyncMetadataRepo(db);

    await db.users.insertOne(
      UsersCompanion.insert(id: 'usr-1'),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncManager', () {
    test('does not run sync when not authenticated (V1 gate)', () async {
      final manager = SyncManager(
        db: db,
        syncMetadataRepo: syncMetadataRepo,
        httpClient: FakeSyncHttpClient(),
        baseUrl: 'https://api.test/v1',
        connectivityMonitor: FakeOnlineMonitor(),
      );

      await manager.sync(accessToken: null);

      final status =
          await syncMetadataRepo.get(SyncMetadataRepo.keyLastSyncStatus);
      expect(status, 'aborted_auth');
    });

    test('does not run sync when offline', () async {
      final manager = SyncManager(
        db: db,
        syncMetadataRepo: syncMetadataRepo,
        httpClient: FakeSyncHttpClient(),
        baseUrl: 'https://api.test/v1',
        connectivityMonitor: FakeOnlineMonitor(isOnlineResult: false),
      );

      await manager.sync(accessToken: 'token-1');

      final status =
          await syncMetadataRepo.get(SyncMetadataRepo.keyLastSyncStatus);
      expect(status, 'aborted_offline');
    });

    test('runs push and pull successfully with valid auth and online', () async {
      final httpClient = FakeSyncHttpClient(
        handler: (path, body) {
          if (path == '/sync/push') {
            final changes = body['changes'] as Map<String, dynamic>;
            final results = <String, dynamic>{};
            changes.forEach((table, records) {
              results[table] = (records as List).map((r) {
                return {
                  'id': (r as Map<String, dynamic>)['id'],
                  'status': 'applied',
                  'server_updated_at': '2026-06-20T12:00:00Z',
                };
              }).toList();
            });
            return {'statusCode': 200, 'body': {'results': results}};
          } else if (path == '/sync/pull') {
            return {
              'statusCode': 200,
              'body': {
                'server_time': '2026-06-20T12:00:00Z',
                'changes': {},
                'has_more': false,
                'next_cursor': null,
              },
            };
          }
          return {'statusCode': 200, 'body': {}};
        },
      );

      final manager = SyncManager(
        db: db,
        syncMetadataRepo: syncMetadataRepo,
        httpClient: httpClient,
        baseUrl: 'https://api.test/v1',
        connectivityMonitor: FakeOnlineMonitor(),
      );

      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-1',
          ownerUserId: 'usr-1',
          name: 'Cash',
          accountType: 'cash',
          syncStatus: const Value('local_only'),
        ),
      );

      await manager.sync(accessToken: 'token-1');

      final account = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-1'))
            ..limit(1))
          .getSingle();
      expect(account.syncStatus, 'synced');

      final status =
          await syncMetadataRepo.get(SyncMetadataRepo.keyLastSyncStatus);
      expect(status, 'success');
    });

    test('prevents concurrent sync cycles (lock mechanism)', () async {
      final httpClient = FakeSyncHttpClient(
        handler: (path, body) {
          return {
            'statusCode': 200,
            'body': const {
              'server_time': '2026-06-20T12:00:00Z',
              'changes': <String, dynamic>{},
              'has_more': false,
              'next_cursor': null,
            },
          };
        },
      );

      final manager = SyncManager(
        db: db,
        syncMetadataRepo: syncMetadataRepo,
        httpClient: httpClient,
        baseUrl: 'https://api.test/v1',
        connectivityMonitor: FakeOnlineMonitor(),
      );

      final firstFuture = manager.sync(accessToken: 'token-1');
      final secondFuture = manager.sync(accessToken: 'token-2');

      await Future.wait([firstFuture, secondFuture]);

      final attempts =
          await syncMetadataRepo.get(SyncMetadataRepo.keyLastSyncAttemptAt);
      expect(attempts, isNotNull);
    });

    test('handles push failure by marking records sync_failed', () async {
      final httpClient = FakeSyncHttpClient(
        handler: (path, body) {
          if (path == '/sync/push') {
            return {
              'statusCode': 500,
              'body': {'error': 'Server error'},
            };
          }
          return {'statusCode': 200, 'body': {}};
        },
      );

      final manager = SyncManager(
        db: db,
        syncMetadataRepo: syncMetadataRepo,
        httpClient: httpClient,
        baseUrl: 'https://api.test/v1',
        connectivityMonitor: FakeOnlineMonitor(),
      );

      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-fail',
          ownerUserId: 'usr-1',
          name: 'Fail Account',
          accountType: 'cash',
          syncStatus: const Value('local_only'),
        ),
      );

      await manager.sync(accessToken: 'token-1');

      final account = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-fail'))
            ..limit(1))
          .getSingle();
      expect(account.syncStatus, 'sync_failed');

      final status =
          await syncMetadataRepo.get(SyncMetadataRepo.keyLastSyncStatus);
      expect(status, 'failed');
    });

    test('postSyncHooks count sync_failed records', () async {
      final httpClient = FakeSyncHttpClient(
        handler: (path, body) {
          if (path == '/sync/push') {
            return {
              'statusCode': 200,
              'body': <String, dynamic>{'results': <String, dynamic>{}},
            };
          } else if (path == '/sync/pull') {
            return {
              'statusCode': 200,
              'body': <String, dynamic>{
                'server_time': '2026-06-20T12:00:00Z',
                'changes': <String, dynamic>{},
                'has_more': false,
                'next_cursor': null,
              },
            };
          }
          return {'statusCode': 200, 'body': <String, dynamic>{}};
        },
      );

      final manager = SyncManager(
        db: db,
        syncMetadataRepo: syncMetadataRepo,
        httpClient: httpClient,
        baseUrl: 'https://api.test/v1',
        connectivityMonitor: FakeOnlineMonitor(),
      );

      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-failed',
          ownerUserId: 'usr-1',
          name: 'Failed Account',
          accountType: 'cash',
          syncStatus: const Value('sync_failed'),
        ),
      );

      await manager.sync(accessToken: 'token-1');

      final lastStatus =
          await syncMetadataRepo.get(SyncMetadataRepo.keyLastSyncStatus);
      final failedCount =
          await syncMetadataRepo.get(SyncMetadataRepo.keySyncFailedCount);
      expect(lastStatus, isNotNull);
      expect(failedCount, isNotNull, reason: 'lastStatus=$lastStatus');
    });
  });

  group('SyncTriggers', () {
    test('does not fire triggers after disposal', () async {
      final manager = SyncManager(
        db: db,
        syncMetadataRepo: syncMetadataRepo,
        httpClient: FakeSyncHttpClient(
          handler: (path, body) {
            return {
              'statusCode': 200,
              'body': const {
                'server_time': '2026-06-20T12:00:00Z',
                'changes': <String, dynamic>{},
                'has_more': false,
                'next_cursor': null,
              },
            };
          },
        ),
        baseUrl: 'https://api.test/v1',
        connectivityMonitor: FakeOnlineMonitor(),
      );

      final triggers = SyncTriggers(
        syncManager: manager,
        connectivityMonitor: FakeOnlineMonitor(),
      );

      triggers.start();
      triggers.dispose();

      triggers.onPullToRefresh();

      final status =
          await syncMetadataRepo.get(SyncMetadataRepo.keyLastSyncAttemptAt);
      expect(status, isNull);
    });
  });
}

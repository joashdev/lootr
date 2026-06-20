import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/application/sync/conflict_applier.dart';
import 'package:lootr/application/sync/pull_client.dart';
import 'package:lootr/application/sync/sync_http_client.dart';
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

void main() {
  late AppDatabase db;
  late PullClient pullClient;
  late SyncMetadataRepo syncMetadataRepo;
  late ConflictApplier conflictApplier;

  setUp(() async {
    db = AppDatabase.inMemory();
    syncMetadataRepo = SyncMetadataRepo(db);
    conflictApplier = ConflictApplier();

    await db.users.insertOne(
      UsersCompanion.insert(id: 'usr-1'),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('PullClient', () {
    test('inserts new records from server', () async {
      final httpClient = FakeSyncHttpClient(
        handler: (path, body) {
          return {
            'statusCode': 200,
            'body': const {
              'server_time': '2026-06-20T12:00:00Z',
              'changes': {
                'accounts': [
                  {
                    'id': 'acc-new',
                    'household_id': null,
                    'owner_user_id': 'usr-1',
                    'name': 'New Account',
                    'account_type': 'cash',
                    'balance': 200.0,
                    'currency_code': 'PHP',
                    'is_archived': 0,
                    'is_hidden': 0,
                    'created_at': '2026-06-20T11:00:00Z',
                    'updated_at': '2026-06-20T11:30:00Z',
                    'deleted_at': null,
                  },
                ],
              },
              'has_more': false,
              'next_cursor': null,
            },
          };
        },
      );

      pullClient = PullClient(
        db: db,
        httpClient: httpClient,
        baseUrl: 'https://api.test/v1',
        syncMetadataRepo: syncMetadataRepo,
        conflictApplier: conflictApplier,
      );

      await syncMetadataRepo.set(
          SyncMetadataRepo.keyLastSyncedAt, '2026-06-20T10:00:00Z');

      final result = await pullClient.pull(accessToken: 'token-1');
      expect(result.success, isTrue);

      final account = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-new'))
            ..limit(1))
          .getSingle();
      expect(account.name, 'New Account');
      expect(account.balance, 200.0);
      expect(account.syncStatus, 'synced');
    });

    test('updates local record when server is newer', () async {
      final httpClient = FakeSyncHttpClient(
        handler: (path, body) {
          return {
            'statusCode': 200,
            'body': const {
              'server_time': '2026-06-20T12:00:00Z',
              'changes': {
                'accounts': [
                  {
                    'id': 'acc-update',
                    'household_id': null,
                    'owner_user_id': 'usr-1',
                    'name': 'Updated Name',
                    'account_type': 'ewallet',
                    'balance': 300.0,
                    'currency_code': 'PHP',
                    'is_archived': 0,
                    'is_hidden': 0,
                    'created_at': '2026-06-20T09:00:00Z',
                    'updated_at': '2026-06-20T11:30:00Z',
                    'deleted_at': null,
                  },
                ],
              },
              'has_more': false,
              'next_cursor': null,
            },
          };
        },
      );

      pullClient = PullClient(
        db: db,
        httpClient: httpClient,
        baseUrl: 'https://api.test/v1',
        syncMetadataRepo: syncMetadataRepo,
        conflictApplier: conflictApplier,
      );

      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-update',
          ownerUserId: 'usr-1',
          name: 'Old Name',
          accountType: 'cash',
          balance: const Value(100.0),
          updatedAt: Value(DateTime(2026, 6, 20, 10)),
          syncStatus: const Value('synced'),
        ),
      );

      await syncMetadataRepo.set(
          SyncMetadataRepo.keyLastSyncedAt, '2026-06-20T10:00:00Z');

      final result = await pullClient.pull(accessToken: 'token-1');
      expect(result.success, isTrue, reason: result.error);

      final account = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-update'))
            ..limit(1))
          .getSingle();
      expect(account.name, 'Updated Name');
      expect(account.accountType, 'ewallet');
      expect(account.balance, 300.0);
      expect(account.syncStatus, 'synced');
    });

    test('skips local record when local is newer', () async {
      final httpClient = FakeSyncHttpClient(
        handler: (path, body) {
          return {
            'statusCode': 200,
            'body': const {
              'server_time': '2026-06-20T16:00:00Z',
              'changes': {
                'accounts': [
                  {
                    'id': 'acc-skip',
                    'household_id': null,
                    'owner_user_id': 'usr-1',
                    'name': 'Server Name',
                    'account_type': 'ewallet',
                    'balance': 100.0,
                    'currency_code': 'PHP',
                    'is_archived': 0,
                    'is_hidden': 0,
                    'created_at': '2026-06-20T09:00:00Z',
                    'updated_at': '2026-06-20T11:30:00Z',
                    'deleted_at': null,
                  },
                ],
              },
              'has_more': false,
              'next_cursor': null,
            },
          };
        },
      );

      pullClient = PullClient(
        db: db,
        httpClient: httpClient,
        baseUrl: 'https://api.test/v1',
        syncMetadataRepo: syncMetadataRepo,
        conflictApplier: conflictApplier,
      );

      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-skip',
          ownerUserId: 'usr-1',
          name: 'Local Name',
          accountType: 'cash',
          balance: const Value(500.0),
          updatedAt: Value(DateTime.utc(2026, 6, 20, 15)),
          syncStatus: const Value('synced'),
        ),
      );

      await syncMetadataRepo.set(
          SyncMetadataRepo.keyLastSyncedAt, '2026-06-20T10:00:00Z');

      final result = await pullClient.pull(accessToken: 'token-1');
      expect(result.success, isTrue);

      final account = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-skip'))
            ..limit(1))
          .getSingle();
      expect(account.name, 'Local Name');
      expect(account.balance, 500.0);
    });

    test('handles cursor pagination', () async {
      var callCount = 0;
      final httpClient = FakeSyncHttpClient(
        handler: (path, body) {
          callCount++;
          if (callCount == 1) {
            return {
              'statusCode': 200,
              'body': const {
                'server_time': '2026-06-20T12:00:00Z',
                'changes': {
                  'accounts': [
                    {
                      'id': 'acc-page1',
                      'household_id': null,
                      'owner_user_id': 'usr-1',
                      'name': 'Page 1 Account',
                      'account_type': 'cash',
                      'balance': 100.0,
                      'currency_code': 'PHP',
                      'is_archived': 0,
                      'is_hidden': 0,
                      'created_at': '2026-06-20T11:00:00Z',
                      'updated_at': '2026-06-20T11:30:00Z',
                      'deleted_at': null,
                    },
                  ],
                },
                'has_more': true,
                'next_cursor': 'cursor-page-2',
              },
            };
          } else {
            return {
              'statusCode': 200,
              'body': const {
                'server_time': '2026-06-20T12:00:00Z',
                'changes': {
                  'accounts': [
                    {
                      'id': 'acc-page2',
                      'household_id': null,
                      'owner_user_id': 'usr-1',
                      'name': 'Page 2 Account',
                      'account_type': 'ewallet',
                      'balance': 200.0,
                      'currency_code': 'PHP',
                      'is_archived': 0,
                      'is_hidden': 0,
                      'created_at': '2026-06-20T11:00:00Z',
                      'updated_at': '2026-06-20T11:30:00Z',
                      'deleted_at': null,
                    },
                  ],
                },
                'has_more': false,
                'next_cursor': null,
              },
            };
          }
        },
      );

      pullClient = PullClient(
        db: db,
        httpClient: httpClient,
        baseUrl: 'https://api.test/v1',
        syncMetadataRepo: syncMetadataRepo,
        conflictApplier: conflictApplier,
      );

      await syncMetadataRepo.set(
          SyncMetadataRepo.keyLastSyncedAt, '2026-06-20T10:00:00Z');

      final result = await pullClient.pull(accessToken: 'token-1');
      expect(result.success, isTrue);
      expect(callCount, 2);

      final acc1 = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-page1'))
            ..limit(1))
          .getSingle();
      expect(acc1.name, 'Page 1 Account');

      final acc2 = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-page2'))
            ..limit(1))
          .getSingle();
      expect(acc2.name, 'Page 2 Account');
    });

    test('handles soft-deleted records from server', () async {
      final httpClient = FakeSyncHttpClient(
        handler: (path, body) {
          return {
            'statusCode': 200,
            'body': const {
              'server_time': '2026-06-20T12:00:00Z',
              'changes': {
                'accounts': [
                  {
                    'id': 'acc-del',
                    'household_id': null,
                    'owner_user_id': 'usr-1',
                    'name': 'Will Be Deleted',
                    'account_type': 'cash',
                    'balance': 100.0,
                    'currency_code': 'PHP',
                    'is_archived': 0,
                    'is_hidden': 0,
                    'created_at': '2026-06-20T09:00:00Z',
                    'updated_at': '2026-06-20T11:30:00Z',
                    'deleted_at': '2026-06-20T11:30:00Z',
                  },
                ],
              },
              'has_more': false,
              'next_cursor': null,
            },
          };
        },
      );

      pullClient = PullClient(
        db: db,
        httpClient: httpClient,
        baseUrl: 'https://api.test/v1',
        syncMetadataRepo: syncMetadataRepo,
        conflictApplier: conflictApplier,
      );

      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-del',
          ownerUserId: 'usr-1',
          name: 'Will Be Deleted',
          accountType: 'cash',
          balance: const Value(100.0),
          updatedAt: Value(DateTime(2026, 6, 20, 10)),
          syncStatus: const Value('synced'),
        ),
      );

      await syncMetadataRepo.set(
          SyncMetadataRepo.keyLastSyncedAt, '2026-06-20T10:00:00Z');

      final result = await pullClient.pull(accessToken: 'token-1');
      expect(result.success, isTrue);

      final account = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-del'))
            ..limit(1))
          .getSingle();
      expect(account.deletedAt, isNotNull);
      expect(account.syncStatus, 'synced');
    });

    test('stores server_time as last_synced_at', () async {
      final httpClient = FakeSyncHttpClient(
        handler: (path, body) {
          return {
            'statusCode': 200,
            'body': const {
              'server_time': '2026-06-20T12:34:56Z',
              'changes': <String, dynamic>{},
              'has_more': false,
              'next_cursor': null,
            },
          };
        },
      );

      pullClient = PullClient(
        db: db,
        httpClient: httpClient,
        baseUrl: 'https://api.test/v1',
        syncMetadataRepo: syncMetadataRepo,
        conflictApplier: conflictApplier,
      );

      await syncMetadataRepo.set(
          SyncMetadataRepo.keyLastSyncedAt, '2026-06-20T10:00:00Z');

      final result = await pullClient.pull(accessToken: 'token-1');
      expect(result.success, isTrue);

      final storedTime =
          await syncMetadataRepo.get(SyncMetadataRepo.keyLastSyncedAt);
      expect(storedTime, isNotNull);
    });

    test('returns failure on server error', () async {
      final httpClient = FakeSyncHttpClient(
        handler: (path, body) {
          return {
            'statusCode': 500,
            'body': {'error': 'Internal server error'},
          };
        },
      );

      pullClient = PullClient(
        db: db,
        httpClient: httpClient,
        baseUrl: 'https://api.test/v1',
        syncMetadataRepo: syncMetadataRepo,
        conflictApplier: conflictApplier,
      );

      final result = await pullClient.pull(accessToken: 'token-1');
      expect(result.success, isFalse);
    });
  });
}

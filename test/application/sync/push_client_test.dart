import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/application/sync/push_client.dart';
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
  late PushClient pushClient;
  late SyncMetadataRepo syncMetadataRepo;

  setUp(() async {
    db = AppDatabase.inMemory();
    syncMetadataRepo = SyncMetadataRepo(db);

    await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
  });

  tearDown(() async {
    await db.close();
  });

  group('PushClient', () {
    test('pushes pending accounts and marks them synced on success', () async {
      final httpClient = FakeSyncHttpClient(
        handler: (path, body) {
          final changes = body['changes'] as Map<String, dynamic>;
          final accounts = (changes['accounts'] as List)
              .cast<Map<String, dynamic>>();
          final results = <String, dynamic>{
            'accounts': accounts
                .map(
                  (a) => {
                    'id': a['id'],
                    'status': 'applied',
                    'server_updated_at': '2026-06-20T12:00:00Z',
                  },
                )
                .toList(),
          };
          return {
            'statusCode': 200,
            'body': {'results': results},
          };
        },
      );

      pushClient = PushClient(
        db: db,
        httpClient: httpClient,
        syncMetadataRepo: syncMetadataRepo,
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

      final result = await pushClient.push(accessToken: 'token-1');
      expect(result.success, isTrue);

      final account =
          await (db.select(db.accounts)
                ..where((a) => a.id.equals('acc-1'))
                ..limit(1))
              .getSingle();
      expect(account.syncStatus, 'synced');
    });

    test('does not sync provenance-linked imported rows', () async {
      Map<String, dynamic>? sentChanges;
      final httpClient = FakeSyncHttpClient(
        handler: (path, body) {
          sentChanges = body['changes'] as Map<String, dynamic>;
          return {
            'statusCode': 200,
            'body': {'results': <String, dynamic>{}},
          };
        },
      );
      pushClient = PushClient(
        db: db,
        httpClient: httpClient,
        syncMetadataRepo: syncMetadataRepo,
      );
      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'imported-account',
          ownerUserId: 'usr-1',
          name: 'Synthetic imported account',
          accountType: 'cash',
          syncStatus: const Value('local_only'),
        ),
      );
      await db
          .into(db.importRuns)
          .insert(
            ImportRunsCompanion.insert(
              id: 'import-run',
              sourceSystem: 'cashew',
              sourceFingerprint: 'synthetic-fingerprint',
              sourceSchemaVersion: 48,
              state: 'complete',
            ),
          );
      await db
          .into(db.importProvenance)
          .insert(
            ImportProvenanceCompanion.insert(
              id: 'import-provenance',
              importRunId: 'import-run',
              sourceSystem: 'cashew',
              sourceFingerprint: 'synthetic-fingerprint',
              sourceEntityType: 'wallets',
              sourceEntityId: 'synthetic-wallet',
              sourcePayloadSha256: 'synthetic-source-hash',
              targetTable: 'accounts',
              targetId: 'imported-account',
              mappingRole: 'primary',
              importedTargetSha256: 'synthetic-target-hash',
            ),
          );

      final result = await pushClient.push(accessToken: 'token-1');

      expect(result.success, isTrue);
      expect(sentChanges?['accounts'], isNull);
      final account = await (db.select(
        db.accounts,
      )..where((row) => row.id.equals('imported-account'))).getSingle();
      expect(account.syncStatus, 'local_only');
    });

    test('marks records as sync_failed on network error', () async {
      final httpClient = FakeSyncHttpClient(
        handler: (path, body) {
          return {'statusCode': 0, 'body': <String, dynamic>{}};
        },
      );

      pushClient = PushClient(
        db: db,
        httpClient: httpClient,
        syncMetadataRepo: syncMetadataRepo,
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

      final result = await pushClient.push(accessToken: 'token-1');
      expect(result.success, isFalse);

      final account =
          await (db.select(db.accounts)
                ..where((a) => a.id.equals('acc-1'))
                ..limit(1))
              .getSingle();
      expect(account.syncStatus, 'sync_failed');
    });

    test('marks records as sync_failed on server 500 error', () async {
      final httpClient = FakeSyncHttpClient(
        handler: (path, body) {
          return {
            'statusCode': 500,
            'body': {'error': 'Internal server error'},
          };
        },
      );

      pushClient = PushClient(
        db: db,
        httpClient: httpClient,
        syncMetadataRepo: syncMetadataRepo,
      );

      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-2',
          ownerUserId: 'usr-1',
          name: 'Bank',
          accountType: 'bank',
          syncStatus: const Value('pending_sync'),
        ),
      );

      final result = await pushClient.push(accessToken: 'token-1');
      expect(result.success, isFalse);

      final account =
          await (db.select(db.accounts)
                ..where((a) => a.id.equals('acc-2'))
                ..limit(1))
              .getSingle();
      expect(account.syncStatus, 'sync_failed');
    });

    test('handles push conflict response by replacing local record', () async {
      final httpClient = FakeSyncHttpClient(
        handler: (path, body) {
          return {
            'statusCode': 200,
            'body': {
              'results': {
                'accounts': [
                  {
                    'id': 'acc-3',
                    'status': 'conflict',
                    'server_record': {
                      'id': 'acc-3',
                      'household_id': null,
                      'owner_user_id': 'usr-1',
                      'name': 'Server Name',
                      'account_type': 'ewallet',
                      'balance': 500.0,
                      'currency_code': 'PHP',
                      'is_archived': 0,
                      'is_hidden': 0,
                      'created_at': '2026-06-20T10:00:00Z',
                      'updated_at': '2026-06-20T12:00:00Z',
                      'deleted_at': null,
                    },
                  },
                ],
              },
            },
          };
        },
      );

      pushClient = PushClient(
        db: db,
        httpClient: httpClient,
        syncMetadataRepo: syncMetadataRepo,
      );

      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-3',
          ownerUserId: 'usr-1',
          name: 'Old Name',
          accountType: 'cash',
          balance: const Value(100.0),
          syncStatus: const Value('pending_sync'),
        ),
      );

      final result = await pushClient.push(accessToken: 'token-1');
      expect(result.success, isTrue);

      final account =
          await (db.select(db.accounts)
                ..where((a) => a.id.equals('acc-3'))
                ..limit(1))
              .getSingle();
      expect(account.name, 'Server Name');
      expect(account.accountType, 'ewallet');
      expect(account.balance, 500.0);
      expect(account.syncStatus, 'synced');
    });

    test('handles push error response marking record as sync_failed', () async {
      final httpClient = FakeSyncHttpClient(
        handler: (path, body) {
          return {
            'statusCode': 200,
            'body': {
              'results': {
                'accounts': [
                  {
                    'id': 'acc-4',
                    'status': 'error',
                    'message': 'Validation failed',
                  },
                ],
              },
            },
          };
        },
      );

      pushClient = PushClient(
        db: db,
        httpClient: httpClient,
        syncMetadataRepo: syncMetadataRepo,
      );

      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-4',
          ownerUserId: 'usr-1',
          name: 'Error Account',
          accountType: 'cash',
          syncStatus: const Value('pending_sync'),
        ),
      );

      final result = await pushClient.push(accessToken: 'token-1');
      expect(result.success, isTrue);

      final account =
          await (db.select(db.accounts)
                ..where((a) => a.id.equals('acc-4'))
                ..limit(1))
              .getSingle();
      expect(account.syncStatus, 'sync_failed');
    });

    test('returns success when no pending changes exist', () async {
      final httpClient = FakeSyncHttpClient(
        handler: (path, body) {
          return {'statusCode': 200, 'body': {}};
        },
      );

      pushClient = PushClient(
        db: db,
        httpClient: httpClient,
        syncMetadataRepo: syncMetadataRepo,
      );

      final result = await pushClient.push(accessToken: 'token-1');
      expect(result.success, isTrue);
    });

    test('includes soft-deleted records in push', () async {
      final httpClient = FakeSyncHttpClient(
        handler: (path, body) {
          final changes = body['changes'] as Map<String, dynamic>;
          final accounts = (changes['accounts'] as List)
              .cast<Map<String, dynamic>>();
          expect(accounts.length, 1);
          expect(accounts.first['id'], 'acc-del');

          return {
            'statusCode': 200,
            'body': {
              'results': {
                'accounts': [
                  {
                    'id': 'acc-del',
                    'status': 'applied',
                    'server_updated_at': '2026-06-20T12:00:00Z',
                  },
                ],
              },
            },
          };
        },
      );

      pushClient = PushClient(
        db: db,
        httpClient: httpClient,
        syncMetadataRepo: syncMetadataRepo,
      );

      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-del',
          ownerUserId: 'usr-1',
          name: 'Deleted Account',
          accountType: 'cash',
          deletedAt: Value(DateTime(2026, 6, 20, 10)),
          syncStatus: const Value('pending_sync'),
        ),
      );

      final result = await pushClient.push(accessToken: 'token-1');
      expect(result.success, isTrue);
    });
  });
}

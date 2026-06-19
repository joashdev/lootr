import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/sync_metadata_repo.dart';

void main() {
  late AppDatabase db;
  late SyncMetadataRepo repo;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = SyncMetadataRepo(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncMetadataRepo', () {
    test('get returns null for non-existent key', () async {
      final value = await repo.get('nonexistent');
      expect(value, isNull);
    });

    test('set stores and get retrieves value', () async {
      await repo.set('last_synced_at', '2026-06-19T12:00:00Z');

      final value = await repo.get('last_synced_at');
      expect(value, '2026-06-19T12:00:00Z');
    });

    test('set overwrites existing key', () async {
      await repo.set('last_synced_at', '2026-06-19T12:00:00Z');
      await repo.set('last_synced_at', '2026-06-20T00:00:00Z');

      final value = await repo.get('last_synced_at');
      expect(value, '2026-06-20T00:00:00Z');
    });

    test('supports all predefined keys', () async {
      await repo.set(SyncMetadataRepo.keyLastSyncedAt, '2026-06-19');
      await repo.set(SyncMetadataRepo.keyLastSyncAttemptAt, '2026-06-19');
      await repo.set(SyncMetadataRepo.keyLastSyncStatus, 'success');
      await repo.set(SyncMetadataRepo.keyLastSyncError, '');
      await repo.set(SyncMetadataRepo.keySyncFailedCount, '0');

      expect(await repo.get(SyncMetadataRepo.keyLastSyncedAt), '2026-06-19');
      expect(await repo.get(SyncMetadataRepo.keyLastSyncStatus), 'success');
      expect(await repo.get(SyncMetadataRepo.keySyncFailedCount), '0');
    });
  });
}

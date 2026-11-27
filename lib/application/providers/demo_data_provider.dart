import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/seed/demo_data_loader.dart';
import '../../data/seed/demo_data_manifest.dart';
import '../../data/seed/demo_data_service.dart';
import 'database_provider.dart';
import 'notification_provider.dart';
import 'repo_providers.dart';

enum DemoDataStatus { absent, loading, present, unverified }

class DemoDataState {
  final DemoDataStatus status;
  final bool canSeed;
  final int recordCount;

  const DemoDataState({
    this.status = DemoDataStatus.absent,
    this.canSeed = true,
    this.recordCount = 0,
  });
}

class DemoDataNotifier extends AsyncNotifier<DemoDataState> {
  @override
  Future<DemoDataState> build() =>
      _inspect(DemoDataService(ref.watch(databaseProvider)));

  Future<void> seed() async {
    final db = ref.read(databaseProvider);
    final service = DemoDataService(db);
    final categoryRepo = ref.read(categoryRepoProvider);
    state = const AsyncData(DemoDataState(status: DemoDataStatus.loading));
    const userId = DemoDataManifest.userId;
    try {
      await db.transaction(() async {
        final inspection = await service.inspect();
        if (inspection.status == DemoInspectionStatus.present) return;
        if (!inspection.canSeed) {
          throw StateError(
            'Sample data can only be loaded into an empty ledger.',
          );
        }
        await categoryRepo.seedCategories(includeMissing: true);
        await db
            .into(db.users)
            .insertOnConflictUpdate(
              UsersCompanion.insert(
                id: userId,
                email: const Value('demo@lootr.app'),
              ),
            );

        await DemoDataLoader().load(db, userId: userId);
        await db
            .into(db.demoRecords)
            .insertOnConflictUpdate(
              DemoRecordsCompanion.insert(
                entityType: DemoEntityType.user.tableName,
                entityId: userId,
                seedVersion: const Value(DemoDataManifest.seedVersion),
              ),
            );
        await db
            .into(db.syncMetadata)
            .insertOnConflictUpdate(
              const SyncMetadataCompanion(
                key: Value('demo_data_seeded'),
                value: Value('true'),
              ),
            );
      });

      state = AsyncData(await _inspect(_service));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> clear() => _clear();

  Future<void> clearReviewedLegacy() => _clear(reviewLegacyRecords: true);

  Future<void> _clear({bool reviewLegacyRecords = false}) async {
    await _runMutation(
      () => _service.clear(reviewLegacyRecords: reviewLegacyRecords),
    );
    try {
      await ref
          .read(notificationSchedulerProvider)
          .rebuildSchedule(afterCurrent: true);
    } catch (_) {
      // The ledger is already updated. App startup retries reminder cleanup.
    }
  }

  Future<void> dismissLegacyFlag() async {
    await _runMutation(_service.dismissLegacyFlag);
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    state = const AsyncData(
      DemoDataState(status: DemoDataStatus.loading, canSeed: false),
    );
    try {
      await action();
      state = AsyncData(await _inspect(_service));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<bool> hasDemoData() async {
    final inspection = await _service.inspect();
    return inspection.status != DemoInspectionStatus.absent;
  }

  Future<DemoClearAnalysis> analyzeClear() => _service.analyzeClear();

  DemoDataService get _service => DemoDataService(ref.read(databaseProvider));

  Future<DemoDataState> _inspect(DemoDataService service) async {
    final inspection = await service.inspect();
    final status = switch (inspection.status) {
      DemoInspectionStatus.absent => DemoDataStatus.absent,
      DemoInspectionStatus.present => DemoDataStatus.present,
      DemoInspectionStatus.unverified => DemoDataStatus.unverified,
    };
    return DemoDataState(
      status: status,
      canSeed: inspection.canSeed,
      recordCount: inspection.recordCount,
    );
  }
}

final demoDataProvider = AsyncNotifierProvider<DemoDataNotifier, DemoDataState>(
  DemoDataNotifier.new,
);

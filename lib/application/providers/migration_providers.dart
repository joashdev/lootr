import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/backup/lootr_backup_service.dart';
import '../../data/migration/cashew_source_registry.dart';
import '../../data/migration/cashew_staging_service.dart';
import '../../data/security/database_key_store.dart';
import '../migration/migration_coordinator.dart';
import '../migration/migration_models.dart';
import '../migration/persistent_migration_coordinator.dart';
import '../migration/platform_data_portability_coordinator.dart';
import 'database_provider.dart';

final _databaseKeyStoreProvider = Provider<DatabaseKeyStore>((ref) {
  return PlatformDatabaseKeyStore();
});

final _secureBackupProvider = Provider<LootrBackupService>((ref) {
  return LootrBackupService(keyStore: ref.watch(_databaseKeyStoreProvider));
});

final _cashewStagingProvider = Provider<CashewStagingService>((ref) {
  return CashewStagingService();
});

final _cashewSourceRegistryProvider = Provider<CashewSourceRegistry>((ref) {
  return CashewSourceRegistry();
});

final migrationSourcePickerProvider = Provider<MigrationSourcePicker>((ref) {
  return FileSelectorMigrationSourcePicker(
    staging: ref.watch(_cashewStagingProvider),
    registry: ref.watch(_cashewSourceRegistryProvider),
  );
});

final dataPortabilityCoordinatorProvider = Provider<DataPortabilityCoordinator>(
  (ref) {
    ref.watch(databaseProvider);
    final backup = ref.watch(_secureBackupProvider);
    return PlatformDataPortabilityCoordinator(
      database: () => ref.read(databaseProvider),
      liveDatabaseFile: () => ref.read(databaseSessionProvider).liveFile,
      restoreVerifiedBackup: (file) =>
          _restoreDatabase(ref: ref, backups: backup, backup: file),
      backups: backup,
    );
  },
);

final migrationCoordinatorProvider = Provider<MigrationCoordinator>((ref) {
  ref.watch(databaseProvider);
  final backups = ref.watch(_secureBackupProvider);
  final coordinator = PersistentMigrationCoordinator(
    database: () => ref.read(databaseProvider),
    liveDatabaseFile: () => ref.read(databaseSessionProvider).liveFile,
    rollbackDirectory: () async {
      final support = await getApplicationSupportDirectory();
      return Directory(p.join(support.path, 'migration-checkpoints'));
    },
    registry: ref.watch(_cashewSourceRegistryProvider),
    staging: ref.watch(_cashewStagingProvider),
    backups: backups,
    restoreCheckpoint: (file) =>
        _restoreDatabase(ref: ref, backups: backups, backup: file),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

final migrationRunsProvider = StreamProvider<List<MigrationRunProjection>>((
  ref,
) {
  return ref.watch(migrationCoordinatorProvider).watchRuns();
});

final migrationRunProvider =
    StreamProvider.family<MigrationRunProjection?, String>((ref, runId) {
      return ref.watch(migrationCoordinatorProvider).watchRun(runId);
    });

Future<void> _restoreDatabase({
  required Ref ref,
  required LootrBackupService backups,
  required File backup,
}) async {
  final checkpoint = await ref
      .read(databaseSessionProvider.notifier)
      .whileDatabaseClosed(
        (liveFile) =>
            backups.restoreAtomically(backup: backup, liveDatabase: liveFile),
      );
  await backups.discardCheckpoint(checkpoint);
}

final migrationTimezoneOptionsProvider =
    Provider<List<MigrationTimezoneOption>>((ref) {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      final sign = offset.isNegative ? '-' : '+';
      final hours = offset.inHours.abs().toString().padLeft(2, '0');
      final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
      return [
        MigrationTimezoneOption(
          id: 'device',
          label: 'Device timezone (UTC$sign$hours:$minutes)',
        ),
        const MigrationTimezoneOption(id: 'UTC', label: 'UTC'),
      ];
    });

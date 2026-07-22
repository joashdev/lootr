import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/backup/lootr_backup_service.dart';
import '../../data/migration/cashew_source_registry.dart';
import '../../data/migration/cashew_staging_service.dart';
import '../../data/security/database_key_store.dart';
import '../database_access_gate.dart';
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
      restoreVerifiedBackup: (file) async {
        await _restoreDatabase(
          ref: ref,
          backups: backup,
          backup: file,
          accessGate: ref.read(databaseAccessGateProvider),
        );
      },
      backups: backup,
    );
  },
);

final migrationCoordinatorProvider = Provider<MigrationCoordinator>((ref) {
  final backups = ref.watch(_secureBackupProvider);
  final session = ref.read(databaseSessionProvider.notifier);
  final accessGate = ref.watch(databaseAccessGateProvider);
  DatabaseAccessLease? maintenanceLease;
  final coordinator = PersistentMigrationCoordinator(
    database: () => session.database,
    liveDatabaseFile: () => session.liveFile,
    rollbackDirectory: () async {
      final support = await getApplicationSupportDirectory();
      return Directory(p.join(support.path, 'migration-checkpoints'));
    },
    registry: ref.watch(_cashewSourceRegistryProvider),
    staging: ref.watch(_cashewStagingProvider),
    backups: backups,
    restoreCheckpoint: (file, runId) => _restoreDatabase(
      ref: ref,
      backups: backups,
      backup: file,
      accessGate: accessGate,
      rollbackRunId: runId,
    ),
    beginMaintenance: () async {
      final lease = await accessGate.acquireExclusive();
      try {
        session.beginMaintenance();
        maintenanceLease = lease;
      } catch (_) {
        lease.release();
        rethrow;
      }
    },
    endMaintenance: () async {
      session.endMaintenance();
      maintenanceLease?.release();
      maintenanceLease = null;
    },
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

Future<File> _restoreDatabase({
  required Ref ref,
  required LootrBackupService backups,
  required File backup,
  required DatabaseAccessGate accessGate,
  String? rollbackRunId,
}) async {
  final session = ref.read(databaseSessionProvider.notifier);
  DatabaseAccessLease? restoreLease;
  if (rollbackRunId == null) {
    restoreLease = await accessGate.acquireExclusive();
    try {
      session.beginMaintenance();
    } catch (_) {
      restoreLease.release();
      rethrow;
    }
  }
  try {
    final checkpoint = await session.whileDatabaseClosed(
      (liveFile) => backups.restoreAtomically(
        backup: backup,
        liveDatabase: liveFile,
        markerPayload: rollbackRunId == null
            ? 'pending'
            : 'rollback:$rollbackRunId',
      ),
      restoreOnReopenFailure: (checkpoint, liveFile) =>
          backups.restoreCheckpointAtomically(
            checkpoint: checkpoint,
            liveDatabase: liveFile,
          ),
      reuseMaintenance: true,
    );
    if (rollbackRunId == null) {
      await backups.discardCheckpoint(checkpoint);
    }
    return checkpoint;
  } finally {
    if (rollbackRunId == null) {
      session.endMaintenance();
      restoreLease?.release();
    }
  }
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

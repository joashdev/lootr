import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../migration/migration_coordinator.dart';
import '../migration/migration_models.dart';

final migrationSourcePickerProvider = Provider<MigrationSourcePicker>((ref) {
  return const SafeUnavailableMigrationSourcePicker();
});

final dataPortabilityCoordinatorProvider = Provider<DataPortabilityCoordinator>(
  (ref) {
    return const SafeUnavailableDataPortabilityCoordinator();
  },
);

final migrationCoordinatorProvider = Provider<MigrationCoordinator>((ref) {
  return const SafeUnavailableMigrationCoordinator();
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

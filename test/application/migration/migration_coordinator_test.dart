import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/migration/migration_coordinator.dart';
import 'package:lootr/application/migration/migration_models.dart';

void main() {
  const source = MigrationSourceSelection(
    opaqueToken: 'synthetic-token-never-rendered',
    safeLabel: 'Synthetic Cashew backup',
  );
  const timezone = MigrationTimezoneOption(
    id: 'test-zone',
    label: 'Synthetic timezone',
  );

  test(
    'projects the complete review, reconcile, apply, and rollback flow',
    () async {
      final coordinator = InMemoryMigrationCoordinator(
        stepDelay: Duration.zero,
        now: () => DateTime.utc(2026, 7, 18, 12),
      );
      addTearDown(coordinator.dispose);

      final run = await coordinator.createRun(
        source: source,
        timezone: timezone,
        titlePolicy: MigrationTitlePolicy.preserveAndSuggest,
      );
      expect(run.phase, MigrationRunPhase.selected);

      await coordinator.analyze(run.id);
      var current = await coordinator.watchRun(run.id).first;
      expect(current?.phase, MigrationRunPhase.needsReview);
      expect(current?.schemaVersion, 48);
      expect(current?.partitions.map((item) => item.precision), [2, 4, 12]);
      expect(current?.dispositions.total, greaterThan(0));

      for (final group in current!.reviewGroups.where(
        (item) => !item.resolved,
      )) {
        await coordinator.resolveReviewGroup(run.id, group.id);
      }
      current = await coordinator.watchRun(run.id).first;
      expect(current?.unresolvedReviewCount, 0);

      await coordinator.reconcile(run.id);
      current = await coordinator.watchRun(run.id).first;
      expect(current?.phase, MigrationRunPhase.ready);
      expect(
        current?.partitions.every(
          (item) => item.status == MigrationPartitionStatus.reconciled,
        ),
        isTrue,
      );

      await coordinator.apply(run.id);
      current = await coordinator.watchRun(run.id).first;
      expect(current?.phase, MigrationRunPhase.complete);
      expect(current?.blocksBackNavigation, isFalse);

      await coordinator.rollback(run.id);
      current = await coordinator.watchRun(run.id).first;
      expect(current?.phase, MigrationRunPhase.rolledBack);
    },
  );

  test(
    'cancellation before publication is terminal and blocks later work',
    () async {
      final coordinator = InMemoryMigrationCoordinator(
        stepDelay: const Duration(milliseconds: 20),
      );
      addTearDown(coordinator.dispose);
      final run = await coordinator.createRun(
        source: source,
        timezone: timezone,
        titlePolicy: MigrationTitlePolicy.preserveOnly,
      );

      final analysis = coordinator.analyze(run.id);
      await coordinator.cancel(run.id);
      await analysis;

      final current = await coordinator.watchRun(run.id).first;
      expect(current?.phase, MigrationRunPhase.cancelled);
      expect(current?.cancelRequested, isTrue);
      expect(current?.isTerminal, isTrue);
    },
  );

  test('safe default services never claim to access or change data', () async {
    const coordinator = SafeUnavailableMigrationCoordinator();
    const picker = SafeUnavailableMigrationSourcePicker();
    const portability = SafeUnavailableDataPortabilityCoordinator();

    expect(await coordinator.watchRuns().first, isEmpty);
    await expectLater(
      coordinator.createRun(
        source: source,
        timezone: timezone,
        titlePolicy: MigrationTitlePolicy.preserveOnly,
      ),
      throwsStateError,
    );

    final pickerResult = await picker.chooseCashewFile();
    expect(pickerResult.status, MigrationPickerStatus.unavailable);
    expect(pickerResult.selection, isNull);

    for (final action in <Future<DataPortabilityResult> Function()>[
      portability.createBackup,
      portability.restoreBackup,
      portability.exportTransactionsCsv,
    ]) {
      final result = await action();
      expect(result.succeeded, isFalse);
      expect(result.message, contains('No data was changed'));
    }
  });
}

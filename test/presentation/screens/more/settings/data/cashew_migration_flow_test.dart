import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/migration/migration_coordinator.dart';
import 'package:lootr/application/migration/migration_models.dart';
import 'package:lootr/application/providers/migration_providers.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/presentation/screens/more/settings/data/cashew_import_prepare_screen.dart';
import 'package:lootr/presentation/screens/more/settings/data/cashew_migration_run_screen.dart';
import 'package:lootr/presentation/screens/more/settings/data/data_backup_screen.dart';
import 'package:lootr/presentation/screens/more/settings/data/migration_run_summary_screen.dart';
import 'package:lootr/presentation/screens/more/settings/data/migration_ui.dart';

class _SyntheticPicker implements MigrationSourcePicker {
  const _SyntheticPicker();

  @override
  Future<MigrationPickerResult> chooseCashewFile() async {
    return const MigrationPickerResult.selected(
      MigrationSourceSelection(
        opaqueToken: 'private-synthetic-token',
        safeLabel: 'Synthetic Cashew backup',
      ),
    );
  }
}

class _SyntheticPortability implements DataPortabilityCoordinator {
  const _SyntheticPortability();

  @override
  Future<DataPortabilityResult> createBackup() async {
    return const DataPortabilityResult(
      succeeded: true,
      message: 'Synthetic backup created.',
    );
  }

  @override
  Future<DataPortabilityResult> exportTransactionsCsv() async {
    return const DataPortabilityResult(
      succeeded: true,
      message: 'Synthetic CSV created.',
    );
  }

  @override
  Future<DataPortabilityResult> restoreBackup() async {
    return const DataPortabilityResult(
      succeeded: true,
      message: 'Synthetic backup restored.',
    );
  }
}

class _FixedProjectionCoordinator implements MigrationCoordinator {
  const _FixedProjectionCoordinator(this.run);

  final MigrationRunProjection run;

  @override
  Future<void> analyze(String runId) async {}

  @override
  Future<void> apply(String runId) async {}

  @override
  Future<void> cancel(String runId) async {}

  @override
  Future<MigrationRunProjection> createRun({
    required MigrationSourceSelection source,
    required MigrationTimezoneOption timezone,
    required MigrationTitlePolicy titlePolicy,
  }) async => run;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> reconcile(String runId) async {}

  @override
  Future<void> resolveReviewGroup(String runId, String groupId) async {}

  @override
  Future<void> rollback(String runId) async {}

  @override
  Stream<MigrationRunProjection?> watchRun(String runId) => Stream.value(run);

  @override
  Stream<List<MigrationRunProjection>> watchRuns() => Stream.value([run]);
}

Widget _host({
  required Widget child,
  required MigrationCoordinator coordinator,
  MigrationSourcePicker picker = const _SyntheticPicker(),
  DataPortabilityCoordinator portability = const _SyntheticPortability(),
  double textScale = 1,
  bool disableAnimations = false,
  AppDatabase? database,
}) {
  return ProviderScope(
    overrides: [
      migrationCoordinatorProvider.overrideWithValue(coordinator),
      migrationSourcePickerProvider.overrideWithValue(picker),
      dataPortabilityCoordinatorProvider.overrideWithValue(portability),
      migrationTimezoneOptionsProvider.overrideWithValue(const [
        MigrationTimezoneOption(
          id: 'synthetic-zone',
          label: 'Synthetic timezone',
        ),
        MigrationTimezoneOption(id: 'UTC', label: 'UTC'),
      ]),
      if (database != null) databaseProvider.overrideWithValue(database),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 800),
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: child,
      ),
    ),
  );
}

Future<MigrationRunProjection> _createRun(MigrationCoordinator coordinator) {
  return coordinator.createRun(
    source: const MigrationSourceSelection(
      opaqueToken: 'synthetic-source',
      safeLabel: 'Synthetic Cashew backup',
    ),
    timezone: const MigrationTimezoneOption(
      id: 'synthetic-zone',
      label: 'Synthetic timezone',
    ),
    titlePolicy: MigrationTitlePolicy.preserveAndSuggest,
  );
}

Future<void> _advanceToReady(
  InMemoryMigrationCoordinator coordinator,
  String runId,
) async {
  await coordinator.analyze(runId);
  final reviewed = await coordinator.watchRun(runId).first;
  for (final group in reviewed!.reviewGroups.where((item) => !item.resolved)) {
    await coordinator.resolveReviewGroup(runId, group.id);
  }
  await coordinator.reconcile(runId);
}

void main() {
  testWidgets('data screen loads and clears sample data explicitly', (
    tester,
  ) async {
    final coordinator = InMemoryMigrationCoordinator(stepDelay: Duration.zero);
    final database = AppDatabase.inMemory();
    addTearDown(coordinator.dispose);
    addTearDown(database.close);
    await database
        .into(database.users)
        .insert(UsersCompanion.insert(id: 'local-user-1'));

    await tester.pumpWidget(
      _host(
        child: const DataBackupScreen(),
        coordinator: coordinator,
        database: database,
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sample-data-load')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sample-data-load')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sample-data-clear')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sample-data-clear')));
    await tester.pumpAndSettle();
    expect(find.text('Clear sample data?'), findsOneWidget);
    expect(
      find.text('This removes sample data only. Your personal data will stay.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('sample-data-clear-confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sample-data-load')), findsOneWidget);
    expect(await database.select(database.accounts).get(), isEmpty);
  });

  testWidgets('data screen does not mix samples into a personal ledger', (
    tester,
  ) async {
    final coordinator = InMemoryMigrationCoordinator(stepDelay: Duration.zero);
    final database = AppDatabase.inMemory();
    addTearDown(coordinator.dispose);
    addTearDown(database.close);
    await database
        .into(database.users)
        .insert(UsersCompanion.insert(id: 'local-user-1'));
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'personal-account',
            ownerUserId: 'local-user-1',
            name: 'Personal account',
            accountType: 'bank',
          ),
        );

    await tester.pumpWidget(
      _host(
        child: const DataBackupScreen(),
        coordinator: coordinator,
        database: database,
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sample-data-load')), findsNothing);
    expect(
      find.text(
        'Sample data is available only before you add financial records.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('data screen reviews partial legacy sample data before clear', (
    tester,
  ) async {
    final coordinator = InMemoryMigrationCoordinator(stepDelay: Duration.zero);
    final database = AppDatabase.inMemory();
    addTearDown(coordinator.dispose);
    addTearDown(database.close);
    await database
        .into(database.users)
        .insert(UsersCompanion.insert(id: 'demo-user-1'));
    await database
        .into(database.syncMetadata)
        .insert(
          const SyncMetadataCompanion(
            key: Value('demo_data_seeded'),
            value: Value('true'),
          ),
        );

    await tester.pumpWidget(
      _host(
        child: const DataBackupScreen(),
        coordinator: coordinator,
        database: database,
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sample-data-review')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sample-data-review')));
    await tester.pumpAndSettle();
    expect(find.text('Clear known sample records?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sample-data-review-confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sample-data-load')), findsOneWidget);
    expect(await database.select(database.users).get(), isEmpty);
  });

  testWidgets('prepare screen selects source and exposes policy controls', (
    tester,
  ) async {
    final coordinator = InMemoryMigrationCoordinator(stepDelay: Duration.zero);
    addTearDown(coordinator.dispose);
    await tester.pumpWidget(
      _host(child: const CashewImportPrepareScreen(), coordinator: coordinator),
    );

    expect(find.text('Bring your history with you'), findsOneWidget);
    expect(find.byKey(const ValueKey('migration-timezone')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('choose-cashew-file')));
    await tester.pump();
    expect(find.text('Synthetic Cashew backup'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('title-policy-preserveAndSuggest')),
      300,
    );
    expect(
      find.byKey(const ValueKey('title-policy-preserveAndSuggest')),
      findsOneWidget,
    );

    final continueButton = tester.widget<MigrationPrimaryAction>(
      find.byKey(const ValueKey('start-cashew-import')),
    );
    expect(continueButton.onPressed, isNotNull);
  });

  testWidgets('full wizard reaches review, reconcile, and complete states', (
    tester,
  ) async {
    final coordinator = InMemoryMigrationCoordinator(stepDelay: Duration.zero);
    addTearDown(coordinator.dispose);
    final run = await _createRun(coordinator);

    await tester.pumpWidget(
      _host(
        child: CashewMigrationRunScreen(runId: run.id),
        coordinator: coordinator,
      ),
    );
    await tester.pump();
    expect(find.text('Ready for a dry run'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('analyze-cashew-backup')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(find.text('Review the dry run'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('review-transfer-exceptions')),
      260,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('review-transfer-exceptions'))),
      alignment: 0.5,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('review-transfer-exceptions')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('review-deleted-account-references')),
      260,
    );
    await Scrollable.ensureVisible(
      tester.element(
        find.byKey(const ValueKey('review-deleted-account-references')),
      ),
      alignment: 0.5,
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('review-deleted-account-references')),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('continue-to-reconcile')));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(find.text('Reconciliation passed'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('12 decimal places'),
      220,
    );
    expect(find.textContaining('12 decimal places'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('apply-cashew-import')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Import these records?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('apply-confirm')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }

    expect(find.text('Your import is ready'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-import-summary')), findsOneWidget);
  });

  testWidgets('cancel gate confirms and never publishes', (tester) async {
    final coordinator = InMemoryMigrationCoordinator(
      stepDelay: const Duration(milliseconds: 50),
    );
    addTearDown(coordinator.dispose);
    final run = await _createRun(coordinator);

    await tester.pumpWidget(
      _host(
        child: CashewMigrationRunScreen(runId: run.id),
        coordinator: coordinator,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('analyze-cashew-backup')));
    await tester.pump();
    expect(find.text('Analyzing privately'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cancel-import')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('confirm-cancel-import')));
    await tester.pump();

    expect(find.text('Import cancelled'), findsOneWidget);
    expect(
      (await coordinator.watchRun(run.id).first)?.phase,
      MigrationRunPhase.cancelled,
    );
  });

  testWidgets('atomic publication blocks back navigation and cancellation', (
    tester,
  ) async {
    final seed = InMemoryMigrationCoordinator(stepDelay: Duration.zero);
    addTearDown(seed.dispose);
    final created = await _createRun(seed);
    await _advanceToReady(seed, created.id);
    final ready = (await seed.watchRun(created.id).first)!;
    final applying = ready.copyWith(
      phase: MigrationRunPhase.applying,
      progress: 0.4,
      progressLabel: 'Publishing approved records',
    );
    final coordinator = _FixedProjectionCoordinator(applying);

    await tester.pumpWidget(
      _host(
        child: CashewMigrationRunScreen(runId: applying.id),
        coordinator: coordinator,
      ),
    );
    await tester.pump();

    expect(find.text('Publishing your import'), findsOneWidget);
    expect(find.byKey(const ValueKey('cancel-import')), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.textContaining('finishing the atomic import'), findsOneWidget);
    expect(find.text('Publishing your import'), findsOneWidget);
  });

  testWidgets('hub shows a resume banner for a nonterminal run', (
    tester,
  ) async {
    final coordinator = InMemoryMigrationCoordinator(stepDelay: Duration.zero);
    addTearDown(coordinator.dispose);
    await _createRun(coordinator);

    await tester.pumpWidget(
      _host(child: const DataBackupScreen(), coordinator: coordinator),
    );
    await tester.pump();

    expect(find.text('Continue your import'), findsOneWidget);
    expect(find.byKey(const ValueKey('resume-import')), findsOneWidget);
    expect(find.byKey(const ValueKey('data-import-cashew')), findsOneWidget);
  });

  testWidgets('summary exposes provenance, preserved, backup, and rollback', (
    tester,
  ) async {
    final coordinator = InMemoryMigrationCoordinator(stepDelay: Duration.zero);
    addTearDown(coordinator.dispose);
    final run = await _createRun(coordinator);
    await _advanceToReady(coordinator, run.id);
    await coordinator.apply(run.id);

    await tester.pumpWidget(
      _host(
        child: MigrationRunSummaryScreen(runId: run.id),
        coordinator: coordinator,
      ),
    );
    await tester.pump();

    for (final key in const [
      ValueKey('view-import-provenance'),
      ValueKey('view-preserved-records'),
      ValueKey('summary-create-backup'),
      ValueKey('rollback-import'),
    ]) {
      await tester.scrollUntilVisible(find.byKey(key), 220);
      expect(find.byKey(key), findsOneWidget);
    }

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('view-import-provenance')),
      -220,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('view-import-provenance'))),
      alignment: 0.5,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('view-import-provenance')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('provenance-dialog')), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('rollback-import')),
      220,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('rollback-import'))),
      alignment: 0.5,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rollback-import')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('rollback-confirm')));
    await tester.pump();
    await tester.pump();
    expect(
      (await coordinator.watchRun(run.id).first)?.phase,
      MigrationRunPhase.rolledBack,
    );
  });

  testWidgets('key actions meet tap targets and layout survives 200% text', (
    tester,
  ) async {
    final coordinator = InMemoryMigrationCoordinator(stepDelay: Duration.zero);
    addTearDown(coordinator.dispose);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _host(
        child: const CashewImportPrepareScreen(),
        coordinator: coordinator,
        textScale: 2,
        disableAnimations: true,
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel(RegExp('Privacy notice')), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });
}

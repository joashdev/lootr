import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lootr/application/migration/migration_coordinator.dart';
import 'package:lootr/application/migration/migration_models.dart';
import 'package:lootr/application/providers/migration_providers.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/presentation/screens/more/settings/data/cashew_migration_run_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('device surface completes the redacted migration review path', (
    tester,
  ) async {
    final coordinator = InMemoryMigrationCoordinator(stepDelay: Duration.zero);
    addTearDown(coordinator.dispose);
    final run = await coordinator.createRun(
      source: const MigrationSourceSelection(
        opaqueToken: 'synthetic-device-handle',
        safeLabel: 'Synthetic Cashew backup',
      ),
      timezone: const MigrationTimezoneOption(
        id: 'synthetic-zone',
        label: 'Synthetic timezone',
      ),
      titlePolicy: MigrationTitlePolicy.preserveAndSuggest,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          migrationCoordinatorProvider.overrideWithValue(coordinator),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: CashewMigrationRunScreen(runId: run.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ready for a dry run'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('analyze-cashew-backup')));
    await tester.pumpAndSettle();
    expect(find.text('Review the dry run'), findsOneWidget);

    for (final group in (await coordinator.watchRun(run.id).first)!
        .reviewGroups
        .where((item) => !item.resolved)) {
      await coordinator.resolveReviewGroup(run.id, group.id);
    }
    await coordinator.reconcile(run.id);
    await tester.pumpAndSettle();

    expect(find.text('Reconciliation passed'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('apply-cashew-import')),
      findsOneWidget,
    );
  });
}

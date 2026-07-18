import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/migration/migration_coordinator.dart';
import 'package:lootr/application/migration/migration_models.dart';
import 'package:lootr/application/providers/migration_providers.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/presentation/screens/more/settings/data/cashew_migration_run_screen.dart';

void main() {
  testWidgets('renders a redacted migration review artifact', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final coordinator = InMemoryMigrationCoordinator(
      stepDelay: Duration.zero,
      now: () => DateTime.utc(2026, 7, 18, 12),
    );
    addTearDown(coordinator.dispose);
    final run = await coordinator.createRun(
      source: const MigrationSourceSelection(
        opaqueToken: 'synthetic-private-handle',
        safeLabel: 'Synthetic Cashew backup',
      ),
      timezone: const MigrationTimezoneOption(
        id: 'synthetic-zone',
        label: 'Synthetic timezone',
      ),
      titlePolicy: MigrationTitlePolicy.preserveAndSuggest,
    );
    await coordinator.analyze(run.id);

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

    await expectLater(
      find.byType(CashewMigrationRunScreen),
      matchesGoldenFile('goldens/cashew_migration_review.png'),
    );
  });
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/migration/migration_coordinator.dart';
import 'package:lootr/application/migration/migration_models.dart';
import 'package:lootr/application/providers/migration_providers.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/presentation/screens/more/settings/data/cashew_migration_run_screen.dart';

void main() {
  testWidgets('renders a redacted migration review artifact', (tester) async {
    final previousComparator = goldenFileComparator;
    goldenFileComparator = _TolerantGoldenFileComparator(
      Uri.parse(
        'test/presentation/screens/more/settings/data/'
        'cashew_migration_render_test.dart',
      ),
      precisionTolerance: 0.0015,
    );
    addTearDown(() => goldenFileComparator = previousComparator);

    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await materialIcons.load();

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
      matchesGoldenFile(
        Platform.isLinux
            ? 'goldens/cashew_migration_review_linux.png'
            : 'goldens/cashew_migration_review.png',
      ),
    );
  });
}

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  }) : _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _precisionTolerance) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:lootr/ai/ocr_pipeline.dart';
import 'package:lootr/application/providers/ai_entry_providers.dart';
import 'package:lootr/application/providers/ai_settings_provider.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/onboarding_provider.dart';
import 'package:lootr/core/router/app_router.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/use_cases/run_ocr.dart';
import 'package:lootr/presentation/screens/ocr/ocr_scan_screen.dart';
import 'package:lootr/presentation/sheets/add_transaction_sheet.dart';
import 'package:lootr/presentation/sheets/quick_actions_sheet.dart';

/// Onboarding forced to completed so router construction doesn't depend on
/// SharedPreferences and the redirect leaves '/transactions/new' alone.
class _CompletedOnboarding extends OnboardingNotifier {
  @override
  OnboardingState build() =>
      const OnboardingState(status: OnboardingStatus.completed);
}

void main() {
  late ProviderContainer container;
  late GoRouter router;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        onboardingProvider.overrideWith(_CompletedOnboarding.new),
        aiEnabledProvider.overrideWith((ref) => true),
        runOCRProvider.overrideWith(
          (ref) => RunOCR(
            pipeline: OCRPipeline(
              textExtractor: (_) async => const ['Receipt', 'TOTAL 250.00'],
            ),
          ),
        ),
        databaseProvider.overrideWith((ref) {
          final db = AppDatabase.inMemory();
          ref.onDispose(db.close);
          return db;
        }),
      ],
    );
    router = container.read(appRouterProvider);
  });

  tearDown(() => container.dispose());

  test(
    '/transactions/new matches the Add sheet route, not /transactions/:id',
    () {
      final match = router.configuration.findMatch(
        Uri.parse('/transactions/new'),
      );
      // Regression guard: before the fix, the shell route ':id' captured "new"
      // and rendered the (empty) transaction detail screen.
      expect(match.last.route.path, '/transactions/new');
    },
  );

  test('a real transaction id still resolves to the detail route', () {
    final match = router.configuration.findMatch(
      Uri.parse('/transactions/abc-123'),
    );
    expect(match.last.route.path, ':id');
  });

  Future<void> openScan(WidgetTester tester, {required bool manual}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsLabel('Add transaction, transfer, or scan receipt'),
    );
    await tester.pumpAndSettle();
    if (manual) {
      await tester.tap(find.text('Manual'));
      await tester.pumpAndSettle();
    }

    await tester.enterText(find.byType(TextField).first, draftFor(manual));
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    expect(find.byType(OcrScanScreen), findsOneWidget);
  }

  for (final manual in [false, true]) {
    final sheet = manual ? 'manual editor' : 'Add menu';
    for (final systemBack in [false, true]) {
      final dismissal = systemBack ? 'system back' : 'the close button';
      testWidgets('$dismissal returns to the $sheet with its draft', (
        tester,
      ) async {
        await openScan(tester, manual: manual);

        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byIcon(LucideIcons.x));
        }
        await tester.pumpAndSettle();

        expect(find.byType(OcrScanScreen), findsNothing);
        expect(
          find.byType(manual ? AddTransactionSheet : QuickActionsSheet),
          findsOneWidget,
        );
        expect(find.text(draftFor(manual)), findsOneWidget);
      });
    }

    testWidgets('confirming a scan opens one prefilled editor from $sheet', (
      tester,
    ) async {
      const picker = MethodChannel('plugins.flutter.io/image_picker');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        picker,
        (_) async => '/tmp/test-receipt.jpg',
      );
      addTearDown(() => messenger.setMockMethodCallHandler(picker, null));

      await openScan(tester, manual: manual);
      await tester.tap(find.byTooltip('Pick from gallery'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue to Save'));
      await tester.pumpAndSettle();

      expect(find.byType(OcrScanScreen, skipOffstage: false), findsNothing);
      expect(find.byType(QuickActionsSheet, skipOffstage: false), findsNothing);
      expect(
        find.byType(AddTransactionSheet, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('250.00'), findsOneWidget);
    });
  }
}

String draftFor(bool manual) => manual ? '14.87' : 'Bus fare 25';

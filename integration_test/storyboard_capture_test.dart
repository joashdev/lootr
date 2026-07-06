import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lootr/main.dart' as app;

/// Captures real screenshots of the core Lootr user flows in two states:
///   A) "seeded"  — onboarding finished with the demo-data toggle ON
///   B) "no-seed" — onboarding finished with the demo-data toggle OFF
///
/// Run with:
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/storyboard_capture_test.dart -d <device>
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// On Android the Flutter surface must be converted to an image before
  /// screenshots can be taken. On iOS this is a no-op (and unsupported), so we
  /// guard on the platform.
  Future<void> prepareScreenshots() async {
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }
  }

  /// Reset all persisted state so onboarding shows fresh: clear
  /// SharedPreferences (onboarding status) and delete the drift sqlite file
  /// (`lootr.sqlite` in the app documents directory).
  Future<void> resetAppState() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    try {
      final dir = await getApplicationDocumentsDirectory();
      for (final suffix in ['', '-wal', '-shm']) {
        final f = File('${dir.path}/lootr.sqlite$suffix');
        if (f.existsSync()) {
          await f.delete();
        }
      }
    } catch (_) {
      // Best-effort; if the file can't be resolved we still proceed.
    }
  }

  /// Settle with a timeout fallback. Some screens have persistent paint work
  /// (blurred floating nav) that can make pumpAndSettle time out; in that case
  /// we fall back to a few fixed pumps so capture can continue.
  Future<void> settle(WidgetTester tester) async {
    try {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 8),
      );
    } catch (_) {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    await binding.takeScreenshot(name);
  }

  /// Walks the 4-step onboarding flow. Step 3 fills the name, the currency is
  /// left at the default (PHP) and the demo toggle is set to [demo].
  Future<void> walkOnboarding(
    WidgetTester tester, {
    required bool demo,
    required String prefix,
  }) async {
    await settle(tester);
    // Step 0 — Welcome.
    await shot(tester, '$prefix/01-onboarding-welcome');

    // Advance through the three intro steps via the "Next" button
    // (a FilledButton wrapping a Text('Next')).
    Future<void> tapNext() async {
      await tester.tap(find.text('Next').first, warnIfMissed: false);
      await settle(tester);
    }

    await tapNext();
    await shot(tester, '$prefix/02-onboarding-track');
    await tapNext();
    await shot(tester, '$prefix/03-onboarding-plan');
    await tapNext();
    // Step 3 — setup form.
    await settle(tester);

    // Fill display name.
    final nameField = find.byType(TextField);
    if (nameField.evaluate().isNotEmpty) {
      await tester.enterText(nameField.first, 'Alex');
      await settle(tester);
    }

    // Set the demo-data toggle to the desired state.
    final toggle = find.byKey(const ValueKey('demo-data-toggle'));
    if (toggle.evaluate().isNotEmpty) {
      final sw = tester.widget<Switch>(toggle);
      if (sw.value != demo) {
        await tester.tap(toggle);
        await settle(tester);
      }
    }

    await shot(tester, '$prefix/04-onboarding-setup');

    // Finish — "Get Started".
    final getStarted = find.text('Get Started');
    await tester.tap(getStarted.first);
    // Seeding + navigation; give it generous time.
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
  }

  Future<void> tapNavLabel(WidgetTester tester, String label) async {
    final finder = find.text(label);
    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder.first, warnIfMissed: false);
      await settle(tester);
    }
  }

  /// From the dashboard, capture each core tab/screen.
  Future<void> captureCoreScreens(
    WidgetTester tester, {
    required String prefix,
  }) async {
    // Dashboard (Home is the initial tab after onboarding).
    await shot(tester, '$prefix/05-dashboard');

    // Transactions tab.
    await tapNavLabel(tester, 'Transactions');
    await shot(tester, '$prefix/06-transactions');

    // Budgets tab.
    await tapNavLabel(tester, 'Budgets');
    await shot(tester, '$prefix/07-budgets');

    // More tab.
    await tapNavLabel(tester, 'More');
    await shot(tester, '$prefix/08-more');

    // More -> Accounts.
    await tapNavLabel(tester, 'Accounts');
    await shot(tester, '$prefix/09-accounts');
    // Back to More.
    final backFinder = find.byTooltip('Back');
    if (backFinder.evaluate().isNotEmpty) {
      await tester.tap(backFinder.first, warnIfMissed: false);
      await settle(tester);
    } else {
      await tester.pageBack();
      await settle(tester);
    }

    // More -> Goals.
    await tapNavLabel(tester, 'Goals');
    await shot(tester, '$prefix/10-goals');
    final back2 = find.byTooltip('Back');
    if (back2.evaluate().isNotEmpty) {
      await tester.tap(back2.first, warnIfMissed: false);
      await settle(tester);
    } else {
      await tester.pageBack();
      await settle(tester);
    }

    // More -> Debts & Lending.
    await tapNavLabel(tester, 'Debts & Lending');
    await shot(tester, '$prefix/11-debts');
    final back3 = find.byTooltip('Back');
    if (back3.evaluate().isNotEmpty) {
      await tester.tap(back3.first, warnIfMissed: false);
      await settle(tester);
    } else {
      await tester.pageBack();
      await settle(tester);
    }
  }

  testWidgets('Scenario A — seeded (demo data ON)', (tester) async {
    await prepareScreenshots();
    await resetAppState();

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await settle(tester);

    await walkOnboarding(tester, demo: true, prefix: 'seeded');
    await captureCoreScreens(tester, prefix: 'seeded');
  });

  testWidgets('Scenario B — no-seed (demo data OFF)', (tester) async {
    await prepareScreenshots();
    await resetAppState();

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await settle(tester);

    await walkOnboarding(tester, demo: false, prefix: 'no-seed');
    await captureCoreScreens(tester, prefix: 'no-seed');
  });
}

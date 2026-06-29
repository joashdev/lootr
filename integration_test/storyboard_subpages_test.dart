import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lootr/main.dart' as app;

/// Captures real iOS-simulator screenshots of the app's SUBPAGES in the
/// SEEDED state (demo data ON) for an annotatable storyboard.
///
/// Screenshots land under `docs/storyboard-shots/subpages/<group>/<NN-name>`.
///
/// Run with:
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/storyboard_subpages_test.dart -d `<udid>`
///
/// Each navigation+screenshot is wrapped in try/catch so one failure does not
/// abort the rest. The test reseeds for each group so state stays predictable.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// On Android the Flutter surface must be converted to an image before
  /// screenshots can be taken. On iOS this is a no-op (and unsupported).
  Future<void> prepareScreenshots() async {
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }
  }

  /// Reset all persisted state so onboarding shows fresh.
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
      // Best-effort.
    }
  }

  /// Settle with a timeout fallback for looping animations.
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

  /// Obtain the app's GoRouter from any live BuildContext so we can drive
  /// navigation directly where real taps are not required / not reliable.
  GoRouter router(WidgetTester tester) {
    final ctx = tester.element(find.byType(Navigator).first);
    return GoRouter.of(ctx);
  }

  Future<void> goRoute(WidgetTester tester, String route) async {
    router(tester).go(route);
    await settle(tester);
  }

  Future<void> pushRoute(WidgetTester tester, String route) async {
    // Activate the owning tab branch before pushing so the bottom nav shows the
    // correct active tab (e.g. More for /more/* routes) instead of whatever
    // branch happened to be active. Mirrors how a user reaches these screens.
    if (route.startsWith('/more')) {
      router(tester).go('/more');
      await settle(tester);
    }
    router(tester).push(route);
    await settle(tester);
  }

  /// Pop the top-most route if possible (used after detail screens / sheets).
  Future<void> popIfPossible(WidgetTester tester) async {
    try {
      final r = router(tester);
      if (r.canPop()) {
        r.pop();
        await settle(tester);
      }
    } catch (_) {
      // ignore
    }
  }

  /// Dismiss any open modal bottom sheet by tapping the scrim, then settle.
  Future<void> dismissSheet(WidgetTester tester) async {
    try {
      // Tap near the very top to hit the barrier above the sheet.
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
    } catch (_) {
      // ignore
    }
  }

  /// Walks the 4-step onboarding with demo data ON to reach a seeded app.
  Future<void> walkOnboarding(WidgetTester tester) async {
    await settle(tester);

    Future<void> tapNext() async {
      final next = find.text('Next');
      if (next.evaluate().isNotEmpty) {
        await tester.tap(next.first, warnIfMissed: false);
        await settle(tester);
      }
    }

    await tapNext();
    await tapNext();
    await tapNext();
    await settle(tester);

    final nameField = find.byType(TextField);
    if (nameField.evaluate().isNotEmpty) {
      await tester.enterText(nameField.first, 'Alex');
      await settle(tester);
    }

    // Ensure demo data toggle is ON.
    final toggle = find.byKey(const ValueKey('demo-data-toggle'));
    if (toggle.evaluate().isNotEmpty) {
      final sw = tester.widget<Switch>(toggle);
      if (sw.value != true) {
        await tester.tap(toggle);
        await settle(tester);
      }
    }

    final getStarted = find.text('Get Started');
    if (getStarted.evaluate().isNotEmpty) {
      await tester.tap(getStarted.first, warnIfMissed: false);
    }
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
  }

  Future<void> bootSeeded(WidgetTester tester) async {
    await prepareScreenshots();
    await resetAppState();
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await settle(tester);
    await walkOnboarding(tester);
  }

  /// Tap the floating "+" island in the tab shell (opens Quick Actions sheet).
  Future<bool> tapPlusIsland(WidgetTester tester) async {
    final plus = find.byIcon(LucideIcons.plus);
    if (plus.evaluate().isEmpty) return false;
    await tester.tap(plus.last, warnIfMissed: false);
    await settle(tester);
    return true;
  }

  /// Run a guarded capture step. Logs and swallows any error.
  Future<void> step(String label, Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      // ignore: avoid_print
      print('SUBPAGE SKIP [$label]: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Group: add sheets
  // ---------------------------------------------------------------------------
  testWidgets('subpages — add sheets', (tester) async {
    await bootSeeded(tester);

    // 01 Quick Actions (via + island).
    await step('add/01-quick-actions', () async {
      if (await tapPlusIsland(tester)) {
        await shot(tester, 'subpages/add/01-quick-actions');
      }
    });

    // 02 Full Add Transaction sheet (Manual mode from Quick Actions header).
    await step('add/02-add-transaction', () async {
      final manual = find.text('Manual');
      if (manual.evaluate().isNotEmpty) {
        await tester.tap(manual.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, 'subpages/add/02-add-transaction');
      }
    });
    await popIfPossible(tester);
    await dismissSheet(tester);

    // 03 Budget create — Budgets tab, tap "Create budget".
    await step('add/03-create-budget', () async {
      await goRoute(tester, '/budgets');
      final btn = find.byTooltip('Create budget');
      if (btn.evaluate().isNotEmpty) {
        await tester.tap(btn.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, 'subpages/add/03-create-budget');
      }
    });
    await dismissSheet(tester);

    // 04 Goal create — Goals screen "Add goal".
    await step('add/04-create-goal', () async {
      await pushRoute(tester, '/more/goals');
      final btn = find.byTooltip('Add goal');
      if (btn.evaluate().isNotEmpty) {
        await tester.tap(btn.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, 'subpages/add/04-create-goal');
      }
    });
    await dismissSheet(tester);
    await popIfPossible(tester);

    // 05 Debt create — Debts screen "Add debt".
    await step('add/05-create-debt', () async {
      await pushRoute(tester, '/more/debts');
      final btn = find.byTooltip('Add debt');
      if (btn.evaluate().isNotEmpty) {
        await tester.tap(btn.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, 'subpages/add/05-create-debt');
      }
    });
    await dismissSheet(tester);
    await popIfPossible(tester);

    // 06 Account create — Accounts screen "Add account".
    await step('add/06-create-account', () async {
      await pushRoute(tester, '/more/accounts');
      final btn = find.byTooltip('Add account');
      if (btn.evaluate().isNotEmpty) {
        await tester.tap(btn.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, 'subpages/add/06-create-account');
      }
    });
    await dismissSheet(tester);
    await popIfPossible(tester);

    // 07 Recurring create — Recurring screen "Add recurring item".
    await step('add/07-create-recurring', () async {
      await pushRoute(tester, '/more/recurring');
      final btn = find.byTooltip('Add recurring item');
      if (btn.evaluate().isNotEmpty) {
        await tester.tap(btn.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, 'subpages/add/07-create-recurring');
      }
    });
    await dismissSheet(tester);
    await popIfPossible(tester);
  });

  // ---------------------------------------------------------------------------
  // Group: detail screens (+ edit where reachable)
  // ---------------------------------------------------------------------------
  testWidgets('subpages — detail screens', (tester) async {
    await bootSeeded(tester);

    // 01 Transaction detail — Transactions tab, tap first row.
    await step('detail/01-transaction', () async {
      await goRoute(tester, '/transactions');
      // Tap the first transaction row. Rows are tappable list items; tapping
      // a seeded note/amount text is reliable.
      final row = find.byType(InkWell);
      if (row.evaluate().isNotEmpty) {
        // Find a row in the list body and tap it.
        await tester.tap(row.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, 'subpages/detail/01-transaction');
      }
    });
    // Transaction edit (Edit button -> pushed Add Transaction screen).
    await step('detail/01-transaction-edit', () async {
      final edit = find.text('Edit');
      if (edit.evaluate().isNotEmpty) {
        await tester.tap(edit.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, 'subpages/detail/01-transaction-edit');
        await popIfPossible(tester);
        await dismissSheet(tester);
      }
    });
    await popIfPossible(tester);

    // 02 Account detail.
    await step('detail/02-account', () async {
      await pushRoute(tester, '/more/accounts');
      final row = find.byType(ListTile);
      if (row.evaluate().isNotEmpty) {
        await tester.tap(row.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, 'subpages/detail/02-account');
      }
    });
    // Account edit (bottom "Edit" button -> sheet).
    await step('detail/02-account-edit', () async {
      final edit = find.text('Edit');
      if (edit.evaluate().isNotEmpty) {
        await tester.tap(edit.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, 'subpages/detail/02-account-edit');
        await dismissSheet(tester);
      }
    });
    await popIfPossible(tester); // pop account detail
    await popIfPossible(tester); // pop accounts list

    // 03 Budget detail.
    await step('detail/03-budget', () async {
      await goRoute(tester, '/budgets');
      // Budget cards are tappable; tap the first card-like InkWell.
      final card = find.byType(InkWell);
      if (card.evaluate().isNotEmpty) {
        await tester.tap(card.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, 'subpages/detail/03-budget');
      }
    });
    // Budget edit ("Edit" -> sheet).
    await step('detail/03-budget-edit', () async {
      final edit = find.text('Edit');
      if (edit.evaluate().isNotEmpty) {
        await tester.tap(edit.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, 'subpages/detail/03-budget-edit');
        await dismissSheet(tester);
      }
    });
    await popIfPossible(tester);

    // 04 Goal detail.
    await step('detail/04-goal', () async {
      await pushRoute(tester, '/more/goals');
      final row = find.byType(InkWell);
      if (row.evaluate().isNotEmpty) {
        await tester.tap(row.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, 'subpages/detail/04-goal');
      }
    });
    await popIfPossible(tester);
    await popIfPossible(tester);

    // 05 Debt detail.
    await step('detail/05-debt', () async {
      await pushRoute(tester, '/more/debts');
      final row = find.byType(ListTile);
      if (row.evaluate().isNotEmpty) {
        await tester.tap(row.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, 'subpages/detail/05-debt');
      }
    });
    await popIfPossible(tester);
    await popIfPossible(tester);

    // 06 Recurring detail.
    await step('detail/06-recurring', () async {
      await pushRoute(tester, '/more/recurring');
      final row = find.byType(ListTile);
      if (row.evaluate().isNotEmpty) {
        await tester.tap(row.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, 'subpages/detail/06-recurring');
      }
    });
    // Recurring edit (bottom "Edit" button -> sheet).
    await step('detail/06-recurring-edit', () async {
      final edit = find.text('Edit');
      if (edit.evaluate().isNotEmpty) {
        await tester.tap(edit.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, 'subpages/detail/06-recurring-edit');
        await dismissSheet(tester);
      }
    });
    await popIfPossible(tester);
    await popIfPossible(tester);

    // 07 Payee detail.
    await step('detail/07-payee', () async {
      await pushRoute(tester, '/more/payees');
      final row = find.byType(ListTile);
      if (row.evaluate().isNotEmpty) {
        await tester.tap(row.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, 'subpages/detail/07-payee');
      }
    });
    await popIfPossible(tester);
    await popIfPossible(tester);
  });

  // ---------------------------------------------------------------------------
  // Group: settings
  // ---------------------------------------------------------------------------
  testWidgets('subpages — settings', (tester) async {
    await bootSeeded(tester);

    final settings = <String, String>{
      '01-profile': '/more/settings/profile',
      '02-notifications': '/more/settings/notifications',
      '03-ai': '/more/settings/ai',
      '04-ai-logs': '/more/settings/ai-logs',
      '05-sync': '/more/settings/sync',
      '06-appearance': '/more/settings/appearance',
      '07-security': '/more/settings/security',
      '08-about': '/more/settings/about',
    };

    for (final entry in settings.entries) {
      await step('settings/${entry.key}', () async {
        await pushRoute(tester, entry.value);
        await shot(tester, 'subpages/settings/${entry.key}');
        await popIfPossible(tester);
      });
    }
  });

  // ---------------------------------------------------------------------------
  // Group: secondary screens
  // ---------------------------------------------------------------------------
  testWidgets('subpages — secondary screens', (tester) async {
    await bootSeeded(tester);

    // 01 Categories (+ edit sheet).
    await step('secondary/01-categories', () async {
      await pushRoute(tester, '/more/categories');
      await shot(tester, 'subpages/secondary/01-categories');
      // Category edit — tap a row's trailing pencil to open the edit sheet.
      final pencil = find.byIcon(LucideIcons.pencil);
      if (pencil.evaluate().isNotEmpty) {
        await tester.tap(pencil.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, 'subpages/secondary/06-category-edit');
        await dismissSheet(tester);
      }
      await popIfPossible(tester);
    });

    // 02 Households (no seeded households — capture empty state).
    await step('secondary/02-households', () async {
      await pushRoute(tester, '/more/households');
      await shot(tester, 'subpages/secondary/02-households');
      await popIfPossible(tester);
    });

    // 03 Reports.
    await step('secondary/03-reports', () async {
      await pushRoute(tester, '/more/reports');
      await shot(tester, 'subpages/secondary/03-reports');
      await popIfPossible(tester);
    });

    // 04 Report detail (spending by category).
    await step('secondary/04-report-detail', () async {
      await pushRoute(tester, '/more/reports/spending-category');
      await shot(tester, 'subpages/secondary/04-report-detail');
      await popIfPossible(tester);
    });

    // 05 Insights.
    await step('secondary/05-insights', () async {
      await pushRoute(tester, '/more/insights');
      await shot(tester, 'subpages/secondary/05-insights');
      await popIfPossible(tester);
    });
  });
}

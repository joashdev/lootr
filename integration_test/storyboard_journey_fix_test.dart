import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lootr/main.dart' as app;

/// Fix-up pass for the journey shots that the first run could not capture:
///   28 (filter sheet), 39-41 (budget detail/edit/delete), 47 (account edit),
///   53-54 (goal contribution), 56-61 (debt create/detail/pay — demo data has
///   no debts, so we create one via the empty-state CTA), 63-68 (recurring —
///   same, created via CTA).
///
/// Run with:
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/storyboard_journey_fix_test.dart -d `<udid>`
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> prepareScreenshots() async {
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }
  }

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
    } catch (_) {}
  }

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
    await binding.takeScreenshot('journey/$name');
  }

  GoRouter router(WidgetTester tester) {
    final ctx = tester.element(find.byType(Navigator).first);
    return GoRouter.of(ctx);
  }

  Future<void> goRoute(WidgetTester tester, String route) async {
    router(tester).go(route);
    await settle(tester);
  }

  Future<void> pushRoute(WidgetTester tester, String route) async {
    if (route.startsWith('/more')) {
      router(tester).go('/more');
      await settle(tester);
    }
    router(tester).push(route);
    await settle(tester);
  }

  Future<void> popIfPossible(WidgetTester tester) async {
    try {
      final r = router(tester);
      if (r.canPop()) {
        r.pop();
        await settle(tester);
      }
    } catch (_) {}
  }

  Future<void> dismissSheet(WidgetTester tester) async {
    try {
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
    } catch (_) {}
  }

  Future<bool> tapText(
    WidgetTester tester,
    String text, {
    bool last = false,
  }) async {
    final finder = find.text(text);
    if (finder.evaluate().isEmpty) return false;
    final f = last ? finder.last : finder.first;
    try {
      await tester.ensureVisible(f);
      await settle(tester);
    } catch (_) {}
    await tester.tap(f, warnIfMissed: false);
    await settle(tester);
    return true;
  }

  Future<bool> tapTooltip(WidgetTester tester, String tooltip) async {
    final finder = find.byTooltip(tooltip);
    if (finder.evaluate().isEmpty) return false;
    await tester.tap(finder.first, warnIfMissed: false);
    await settle(tester);
    return true;
  }

  Future<void> walkOnboarding(WidgetTester tester) async {
    await settle(tester);
    for (var i = 0; i < 3; i++) {
      await tapText(tester, 'Next');
    }
    await settle(tester);
    final nameField = find.byType(TextField);
    if (nameField.evaluate().isNotEmpty) {
      await tester.enterText(nameField.first, 'Alex');
      await settle(tester);
    }
    final toggle = find.byKey(const ValueKey('demo-data-toggle'));
    if (toggle.evaluate().isNotEmpty) {
      final sw = tester.widget<Switch>(toggle);
      if (sw.value != true) {
        await tester.tap(toggle);
        await settle(tester);
      }
    }
    await tapText(tester, 'Get Started');
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

  Future<void> step(String label, Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      // ignore: avoid_print
      print('JOURNEY SKIP [$label]: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // A. Transactions filter sheet (28).
  // ---------------------------------------------------------------------------
  testWidgets('fix A — filter sheet', (tester) async {
    await bootSeeded(tester);

    await step('tx-filter-sheet', () async {
      await goRoute(tester, '/transactions');
      if (await tapTooltip(tester, 'Filter transactions')) {
        await shot(tester, '28-transactions-filter-sheet');
        await dismissSheet(tester);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // B. Budget detail / edit / delete-confirm (39-41).
  // ---------------------------------------------------------------------------
  testWidgets('fix B — budget detail and edit', (tester) async {
    await bootSeeded(tester);

    await step('budget-detail', () async {
      await goRoute(tester, '/budgets');
      // Tap the first budget card (InkWell), like the subpages test does.
      final card = find.byType(InkWell);
      if (card.evaluate().isNotEmpty) {
        await tester.tap(card.first, warnIfMissed: false);
        await settle(tester);
        // Give any stream/provider extra time to resolve.
        await tester.pump(const Duration(seconds: 2));
        await shot(tester, '39-budget-detail');
      }
    });

    await step('budget-edit', () async {
      // Edit/Delete sit below the budget's transaction list — scroll down.
      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 8; i++) {
        if (find.text('Edit').evaluate().isNotEmpty) break;
        await tester.drag(scrollable, const Offset(0, -600));
        await settle(tester);
      }
      if (await tapText(tester, 'Edit')) {
        await shot(tester, '40-budget-edit');
        if (await tapText(tester, 'Delete Budget')) {
          await shot(tester, '41-budget-delete-confirm');
          await tapText(tester, 'Cancel');
        }
        await dismissSheet(tester);
      }
      await popIfPossible(tester);
    });
  });

  // ---------------------------------------------------------------------------
  // C. Account edit (47) — Edit now lives in the detail AppBar.
  // ---------------------------------------------------------------------------
  testWidgets('fix C — account edit', (tester) async {
    await bootSeeded(tester);

    await step('account-edit', () async {
      await pushRoute(tester, '/more/accounts');
      if (await tapText(tester, 'GCash')) {
        if (await tapTooltip(tester, 'Edit account')) {
          await shot(tester, '47-account-edit');
          await dismissSheet(tester);
        }
      }
      await popIfPossible(tester);
      await popIfPossible(tester);
    });
  });

  // ---------------------------------------------------------------------------
  // D. Goal contribution (53-54) — button hidden behind the floating nav.
  // ---------------------------------------------------------------------------
  testWidgets('fix D — goal contribution', (tester) async {
    await bootSeeded(tester);

    await step('goal-contribution', () async {
      await pushRoute(tester, '/more/goals');
      if (await tapText(tester, 'Emergency Fund')) {
        final scrollable = find.byType(Scrollable).first;
        await tester.drag(scrollable, const Offset(0, -600));
        await settle(tester);
        if (await tapText(tester, 'Add Contribution')) {
          // Only shoot if the sheet actually opened.
          if (find.text('Contribution Amount').evaluate().isNotEmpty) {
            await shot(tester, '53-goal-add-contribution');
            final amount = find.byType(TextField).first;
            await tester.enterText(amount, '1500');
            await settle(tester);
            await tapText(tester, 'Save Contribution');
            await tester.pump(const Duration(seconds: 1));
            await shot(tester, '54-goal-after-contribution');
          }
        }
      }
      await popIfPossible(tester);
      await popIfPossible(tester);
    });
  });

  // ---------------------------------------------------------------------------
  // E. Debts (56-61) — no demo debts; create via the empty-state CTA.
  // ---------------------------------------------------------------------------
  testWidgets('fix E — debts', (tester) async {
    await bootSeeded(tester);

    await step('debt-create', () async {
      await pushRoute(tester, '/more/debts');
      final opened =
          await tapTooltip(tester, 'Add debt') ||
          await tapText(tester, 'Add Debt');
      if (opened) {
        await shot(tester, '56-debt-create-empty');
        final fields = find.byType(TextField);
        await tester.enterText(fields.first, 'Carlo');
        await settle(tester);
        if (fields.evaluate().length >= 3) {
          await tester.enterText(fields.at(1), '3000');
          await settle(tester);
          await tester.enterText(fields.at(2), '3000');
          await settle(tester);
        }
        await shot(tester, '57-debt-create-filled');
        await tapText(tester, 'Save Debt');
        await tester.pump(const Duration(seconds: 1));
        await shot(tester, '58-debts-after-create');
      }
    });

    await step('debt-detail', () async {
      final row = find.byType(ListTile);
      if (row.evaluate().isNotEmpty) {
        await tester.tap(row.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, '59-debt-detail');
      }
    });

    await step('debt-payment-sheets', () async {
      if (await tapText(tester, 'Partial Pay')) {
        await shot(tester, '60-debt-partial-pay');
        await dismissSheet(tester);
      }
      if (await tapText(tester, 'Settle')) {
        await shot(tester, '61-debt-settle-sheet');
        await dismissSheet(tester);
      }
      await popIfPossible(tester);
      await popIfPossible(tester);
    });
  });

  // ---------------------------------------------------------------------------
  // F. Recurring (63-68) — no demo recurring; create via the empty-state CTA.
  // ---------------------------------------------------------------------------
  testWidgets('fix F — recurring', (tester) async {
    await bootSeeded(tester);

    await step('recurring-create', () async {
      await pushRoute(tester, '/more/recurring');
      final opened =
          await tapTooltip(tester, 'Add recurring item') ||
          await tapText(tester, 'Add Recurring');
      if (opened) {
        await shot(tester, '63-recurring-create-empty');
        final fields = find.byType(TextField);
        await tester.enterText(fields.first, 'Netflix');
        await settle(tester);
        if (fields.evaluate().length >= 2) {
          await tester.enterText(fields.at(1), '549');
          await settle(tester);
        }
        await shot(tester, '64-recurring-create-filled');
        await tapText(tester, 'Save Recurring Item');
        await tester.pump(const Duration(seconds: 1));
        await shot(tester, '65-recurring-after-create');
      }
    });

    await step('recurring-detail', () async {
      final row = find.byType(ListTile);
      if (row.evaluate().isNotEmpty) {
        await tester.tap(row.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, '66-recurring-detail');
      }
    });

    await step('recurring-edit', () async {
      if (await tapText(tester, 'Edit')) {
        await shot(tester, '67-recurring-edit');
        await dismissSheet(tester);
      }
    });

    await step('recurring-delete-confirm', () async {
      if (await tapText(tester, 'Delete')) {
        await shot(tester, '68-recurring-delete-confirm');
        await tapText(tester, 'Cancel');
      }
      await popIfPossible(tester);
      await popIfPossible(tester);
    });
  });
}

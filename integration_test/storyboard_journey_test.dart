import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lootr/main.dart' as app;
import 'package:lootr/presentation/shared/components/buttons/primary_button.dart';

/// Captures a full USER JOURNEY through Lootr — every page AND the
/// intermediate/action states (open pickers, typed forms, confirm dialogs,
/// post-save results) — as numbered screenshots under
/// `docs/storyboard-shots/journey/NN-name.png`.
///
/// Run with:
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/storyboard_journey_test.dart -d `<udid>`
///
/// Every step is guarded (try/catch + logs) so one flaky screen never aborts
/// the rest of the story. Each testWidgets boots the app fresh (seeded demo
/// data) so state stays predictable.
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
    } catch (_) {
      // Best-effort.
    }
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

  /// Walks the 4-step onboarding with demo data ON (no screenshots).
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

  /// Tap the floating "+" island (opens the Quick Actions sheet).
  Future<bool> tapPlusIsland(WidgetTester tester) async {
    await goRoute(tester, '/');
    final plus = find.byIcon(LucideIcons.plus);
    if (plus.evaluate().isEmpty) return false;
    await tester.tap(plus.last, warnIfMissed: false);
    await settle(tester);
    return true;
  }

  /// Open the FULL Add Transaction sheet like a user: + island -> "Manual"
  /// segment (the Quick | Manual | Scan segmented control navigates to
  /// /transactions/new in one tap).
  Future<bool> openManualAddSheet(WidgetTester tester) async {
    if (!await tapPlusIsland(tester)) return false;
    if (!await tapText(tester, 'Manual')) return false;
    return find.text('Amount').evaluate().isNotEmpty;
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
  // 1. Onboarding — every step, plus the setup form empty vs filled.
  // ---------------------------------------------------------------------------
  testWidgets('journey 01 — onboarding', (tester) async {
    await prepareScreenshots();
    await resetAppState();
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await settle(tester);

    await step('onboarding', () async {
      await shot(tester, '01-onboarding-welcome');
      await tapText(tester, 'Next');
      await shot(tester, '02-onboarding-track');
      await tapText(tester, 'Next');
      await shot(tester, '03-onboarding-plan');
      await tapText(tester, 'Next');
      await shot(tester, '04-onboarding-setup-empty');

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
      await shot(tester, '05-onboarding-setup-filled');

      await tapText(tester, 'Get Started');
      await settle(tester);
      await tester.pump(const Duration(seconds: 2));
      await shot(tester, '06-dashboard-first-run');
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Dashboard — initial and scrolled. (The header's search and sync-status
  // actions are hidden until those features ship, so shot 10 is retired.)
  // ---------------------------------------------------------------------------
  testWidgets('journey 02 — dashboard states', (tester) async {
    await bootSeeded(tester);

    await step('dashboard-top', () async {
      await shot(tester, '07-dashboard-top');
    });

    await step('dashboard-scroll', () async {
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -700));
      await shot(tester, '08-dashboard-scrolled-mid');
      await tester.drag(scrollable, const Offset(0, -1400));
      await shot(tester, '09-dashboard-scrolled-bottom');
      await tester.drag(scrollable, const Offset(0, 3000));
      await settle(tester);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Quick Actions + Add Transaction — every intermediate state.
  // ---------------------------------------------------------------------------
  testWidgets('journey 03 — add transaction flow', (tester) async {
    await bootSeeded(tester);

    // Quick Actions island: sheet, typed input, parsed preview.
    await step('quick-actions', () async {
      if (await tapPlusIsland(tester)) {
        await shot(tester, '11-quick-actions-sheet');
        final input = find.byType(TextField).last;
        await tester.enterText(input, 'Coffee at Starbucks 180');
        await shot(tester, '12-quick-actions-typed');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle(tester);
        await tester.pump(const Duration(seconds: 1));
        await shot(tester, '13-quick-add-parsed-preview');
        // Close the quick-mode Add Transaction sheet.
        final close = find.byIcon(Icons.close);
        if (close.evaluate().isNotEmpty) {
          await tester.tap(close.last, warnIfMissed: false);
          await settle(tester);
        }
      }
    });

    // Full manual form: empty + each direction tab. The segmented control at
    // the top now shows Manual selected (one tap from the + sheet).
    await step('add-tx-empty-and-tabs', () async {
      if (await openManualAddSheet(tester)) {
        await shot(tester, '95-entry-mode-manual-selected');
        await shot(tester, '14-add-transaction-empty');
        await tapText(tester, 'Income');
        await shot(tester, '15-add-transaction-income-tab');
        await tapText(tester, 'Transfer');
        await shot(tester, '16-add-transaction-transfer-tab');
        await tapText(tester, 'Expense');
      }
    });

    // Amount typed.
    await step('add-tx-amount', () async {
      final amount = find.byType(TextField).first;
      await tester.enterText(amount, '250');
      await shot(tester, '17-add-transaction-amount-typed');
    });

    // Account dropdown open + select.
    await step('add-tx-account-picker', () async {
      if (await tapText(tester, 'Select an account')) {
        await shot(tester, '18-add-transaction-account-picker');
        await tapText(tester, 'GCash', last: true);
      }
    });

    // Category autocomplete open + select.
    await step('add-tx-category-picker', () async {
      final catField = find.byType(TextField).at(1);
      await tester.tap(catField, warnIfMissed: false);
      await settle(tester);
      await tester.enterText(catField, 'Fo');
      await settle(tester);
      await shot(tester, '19-add-transaction-category-picker');
      await tapText(tester, 'Food & Dining', last: true);
    });

    // Payee autocomplete open + type.
    await step('add-tx-payee-picker', () async {
      final payeeField = find.byType(TextField).at(2);
      await tester.tap(payeeField, warnIfMissed: false);
      await settle(tester);
      await tester.enterText(payeeField, 'Star');
      await settle(tester);
      await shot(tester, '20-add-transaction-payee-picker');
      final option = find.text('Starbucks');
      if (option.evaluate().isNotEmpty) {
        await tester.tap(option.last, warnIfMissed: false);
        await settle(tester);
      }
    });

    // Date picker open, then cancel.
    await step('add-tx-date-picker', () async {
      final calendar = find.byIcon(Icons.calendar_today_outlined);
      if (calendar.evaluate().isNotEmpty) {
        await tester.tap(calendar.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, '21-add-transaction-date-picker');
        await tapText(tester, 'Cancel');
      }
    });

    // Recurring mode reveals the recurrence-rule picker.
    await step('add-tx-recurring-mode', () async {
      await tapText(tester, 'Recurring');
      await shot(tester, '22-add-transaction-mode-recurring');
      await tapText(tester, 'One-time');
    });

    // Fully-filled form, then save.
    await step('add-tx-save', () async {
      await shot(tester, '23-add-transaction-filled');
      final save = find.widgetWithText(PrimaryButton, 'Add Transaction');
      if (save.evaluate().isNotEmpty) {
        await tester.ensureVisible(save.first);
        await tester.tap(save.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, '24-add-transaction-saved-snackbar');
      }
      await goRoute(tester, '/transactions');
      await shot(tester, '25-transactions-after-add');
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Transactions — search, filter, swipe-delete, detail, edit, delete.
  // ---------------------------------------------------------------------------
  testWidgets('journey 04 — transactions', (tester) async {
    await bootSeeded(tester);

    await step('tx-list', () async {
      await goRoute(tester, '/transactions');
      await shot(tester, '26-transactions-list');
    });

    await step('tx-search', () async {
      if (await tapTooltip(tester, 'Search transactions')) {
        final field = find.byType(TextField);
        if (field.evaluate().isNotEmpty) {
          await tester.enterText(field.first, 'jolli');
          await settle(tester);
        }
        await shot(tester, '27-transactions-search');
        // Close search — the search AppBar's leading is a plain back arrow.
        final back = find.byIcon(Icons.arrow_back);
        if (back.evaluate().isNotEmpty) {
          await tester.tap(back.first, warnIfMissed: false);
          await settle(tester);
        } else {
          await tester.enterText(field.first, '');
          await settle(tester);
        }
      }
    });

    await step('tx-filter-sheet', () async {
      await goRoute(tester, '/transactions');
      if (await tapTooltip(tester, 'Filter transactions')) {
        await shot(tester, '28-transactions-filter-sheet');
        await dismissSheet(tester);
      }
    });

    await step('tx-swipe-delete', () async {
      await goRoute(tester, '/transactions');
      final row = find.byType(Dismissible);
      if (row.evaluate().isNotEmpty) {
        await tester.drag(row.first, const Offset(-500, 0));
        await settle(tester);
        await shot(tester, '29-transactions-swipe-delete-confirm');
        await tapText(tester, 'Cancel');
      }
    });

    await step('tx-detail', () async {
      await goRoute(tester, '/transactions');
      final row = find.byType(Dismissible);
      if (row.evaluate().isNotEmpty) {
        await tester.tap(row.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, '30-transaction-detail');
      }
    });

    await step('tx-edit', () async {
      if (await tapText(tester, 'Edit')) {
        await shot(tester, '31-transaction-edit');
        final amount = find.byType(TextField).first;
        await tester.enterText(amount, '999');
        await settle(tester);
        final save = find.widgetWithText(PrimaryButton, 'Save Changes');
        if (save.evaluate().isNotEmpty) {
          await tester.ensureVisible(save.first);
          await tester.tap(save.first, warnIfMissed: false);
          await settle(tester);
        }
        await shot(tester, '32-transaction-after-edit-save');
      }
    });

    await step('tx-delete-confirm', () async {
      if (await tapText(tester, 'Delete')) {
        await shot(tester, '33-transaction-delete-confirm');
        await tapText(tester, 'Cancel');
      }
      await popIfPossible(tester);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Budgets — month nav, create (empty/filled/saved), detail, edit, delete.
  // ---------------------------------------------------------------------------
  testWidgets('journey 05 — budgets', (tester) async {
    await bootSeeded(tester);

    await step('budgets-list', () async {
      await goRoute(tester, '/budgets');
      await shot(tester, '34-budgets-list');
    });

    await step('budgets-prev-month', () async {
      if (await tapTooltip(tester, 'Previous month')) {
        await shot(tester, '35-budgets-previous-month');
        await tapTooltip(tester, 'Next month');
      }
    });

    await step('budget-create', () async {
      await goRoute(tester, '/budgets');
      if (await tapTooltip(tester, 'Create budget')) {
        await shot(tester, '36-budget-create-empty');
        final cat = find.byKey(const Key('budget-category-input'));
        if (cat.evaluate().isNotEmpty) {
          await tester.enterText(cat.first, 'Bills');
          await settle(tester);
          await tapText(tester, 'Bills & Utilities', last: true);
        }
        final amount = find.byType(TextField).last;
        await tester.enterText(amount, '4000');
        await settle(tester);
        await shot(tester, '37-budget-create-filled');

        // Appearance picker (icon grid + color row). Pick an icon override so
        // the "Use category default" reset affordance appears, then capture.
        final iconLabel = find.text('Icon');
        if (iconLabel.evaluate().isNotEmpty) {
          await tester.ensureVisible(iconLabel.first);
          await settle(tester);
          final grid = find.byType(GridView);
          if (grid.evaluate().isNotEmpty) {
            final cells = find.descendant(
              of: grid.first,
              matching: find.byType(InkWell),
            );
            if (cells.evaluate().length > 5) {
              await tester.tap(cells.at(5), warnIfMissed: false);
              await settle(tester);
            }
          }
          final reset = find.text('Use category default');
          if (reset.evaluate().isNotEmpty) {
            await tester.ensureVisible(reset.first);
            await settle(tester);
          }
          await shot(tester, '91-budget-appearance-picker');
        }

        await tapText(tester, 'Save Budget');
        await tester.pump(const Duration(seconds: 1));
        await shot(tester, '38-budgets-after-create');
      }
    });

    await step('budget-detail', () async {
      await goRoute(tester, '/budgets');
      var opened = await tapText(tester, 'Food & Dining');
      if (!opened) {
        final card = find.byType(InkWell);
        if (card.evaluate().isNotEmpty) {
          await tester.tap(card.first, warnIfMissed: false);
          await settle(tester);
          opened = true;
        }
      }
      if (opened) {
        // Let the detail provider resolve before shooting the loaded state.
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
  // 6. Accounts — create (empty/filled/saved), detail, edit.
  // ---------------------------------------------------------------------------
  testWidgets('journey 06 — accounts', (tester) async {
    await bootSeeded(tester);

    await step('accounts-list', () async {
      await pushRoute(tester, '/more/accounts');
      await shot(tester, '42-accounts-list');
    });

    // Swipe an account row partially right to reveal the edit action
    // (SwipeActionRow: right = edit, left = delete/archive). The gesture is
    // held while the shot is taken, then returned so nothing triggers.
    await step('accounts-swipe-reveal', () async {
      final row = find.byType(Dismissible);
      if (row.evaluate().isNotEmpty) {
        final gesture = await tester.startGesture(tester.getCenter(row.first));
        // Incremental moves so the drag recognizer wins the arena and the
        // Dismissible tracks the pointer (a single jump is ignored).
        for (var i = 0; i < 8; i++) {
          await gesture.moveBy(const Offset(18, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pump(const Duration(milliseconds: 250));
        await binding.takeScreenshot('journey/98-accounts-swipe-edit-reveal');
        for (var i = 0; i < 8; i++) {
          await gesture.moveBy(const Offset(-18, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await settle(tester);
      }
    });

    await step('account-create', () async {
      if (await tapTooltip(tester, 'Add account')) {
        await shot(tester, '43-account-create-empty');
        final fields = find.byType(TextField);
        await tester.enterText(fields.first, 'Maya Wallet');
        await settle(tester);
        await tester.enterText(fields.last, '5000');
        await settle(tester);
        await shot(tester, '44-account-create-filled');
        await tapText(tester, 'Save Account');
        await tester.pump(const Duration(seconds: 1));
        await shot(tester, '45-accounts-after-create');
      }
    });

    await step('account-detail', () async {
      if (await tapText(tester, 'GCash')) {
        await shot(tester, '46-account-detail');
      }
    });

    await step('account-edit', () async {
      // Edit now lives in the account detail AppBar as an icon action.
      if (await tapTooltip(tester, 'Edit account')) {
        await shot(tester, '47-account-edit');
        await dismissSheet(tester);
      }
      await popIfPossible(tester);
      await popIfPossible(tester);
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Goals & Debts — create, detail, contribution, payment/settle.
  // ---------------------------------------------------------------------------
  testWidgets('journey 07 — goals and debts', (tester) async {
    await bootSeeded(tester);

    await step('goals-list', () async {
      await pushRoute(tester, '/more/goals');
      await shot(tester, '48-goals-list');
    });

    await step('goal-create', () async {
      if (await tapTooltip(tester, 'Add goal')) {
        await shot(tester, '49-goal-create-empty');
        final fields = find.byType(TextField);
        await tester.enterText(fields.first, 'New Laptop');
        await settle(tester);
        // Target amount is the 2nd text field, current the 3rd.
        if (fields.evaluate().length >= 3) {
          await tester.enterText(fields.at(1), '80000');
          await settle(tester);
          await tester.enterText(fields.at(2), '5000');
          await settle(tester);
        }
        await shot(tester, '50-goal-create-filled');
        await tapText(tester, 'Save Goal');
        await tester.pump(const Duration(seconds: 1));
        await shot(tester, '51-goals-after-create');
      }
    });

    await step('goal-detail', () async {
      // Let the "Goal created." snackbar from the previous step expire.
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
      if (await tapText(tester, 'Emergency Fund')) {
        await shot(tester, '52-goal-detail');
      }
    });

    // Goal detail now has a pencil Edit action in the AppBar.
    await step('goal-edit-sheet', () async {
      if (await tapTooltip(tester, 'Edit goal')) {
        await shot(tester, '96-goal-edit-sheet');
        await dismissSheet(tester);
      }
    });

    await step('goal-contribution', () async {
      final scrollable = find.byType(Scrollable).first;
      if (find.text('Add Contribution').evaluate().isEmpty) {
        await tester.drag(scrollable, const Offset(0, -600));
        await settle(tester);
      }
      if (await tapText(tester, 'Add Contribution')) {
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
      await popIfPossible(tester);
      await popIfPossible(tester);
    });

    await step('debts-list', () async {
      // Let the "Contribution added." snackbar from the previous step expire.
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
      // Demo data now seeds 3 debts, so the list opens populated.
      await pushRoute(tester, '/more/debts');
      await shot(tester, '55-debts-list');
    });

    await step('debt-create', () async {
      if (await tapTooltip(tester, 'Add debt') ||
          await tapText(tester, 'Add Debt')) {
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

    // Debt detail now has a pencil Edit action in the AppBar.
    await step('debt-edit-sheet', () async {
      if (await tapTooltip(tester, 'Edit debt')) {
        await shot(tester, '97-debt-edit-sheet');
        await dismissSheet(tester);
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
  // 8. Recurring, Categories, Payees.
  // ---------------------------------------------------------------------------
  testWidgets('journey 08 — recurring, categories, payees', (tester) async {
    await bootSeeded(tester);

    await step('recurring-list', () async {
      // Demo data now seeds 4 recurring items, so the list opens populated.
      await pushRoute(tester, '/more/recurring');
      await shot(tester, '62-recurring-list');
    });

    await step('recurring-create', () async {
      if (await tapTooltip(tester, 'Add recurring item') ||
          await tapText(tester, 'Add Recurring')) {
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
        await dismissSheet(tester);
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

    await step('categories', () async {
      await pushRoute(tester, '/more/categories');
      await shot(tester, '69-categories-list');
      final pencil = find.byIcon(LucideIcons.pencil);
      if (pencil.evaluate().isNotEmpty) {
        await tester.tap(pencil.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, '70-category-edit');
        // Icon picker grid preselects the category's true icon — capture it.
        final iconLabel = find.text('Icon');
        if (iconLabel.evaluate().isNotEmpty) {
          await tester.ensureVisible(iconLabel.first);
          await settle(tester);
          await shot(tester, '92-category-icon-picker');
        }
        await dismissSheet(tester);
      }
      await popIfPossible(tester);
    });

    await step('payees', () async {
      await pushRoute(tester, '/more/payees');
      await shot(tester, '71-payees-list');
      final row = find.byType(ListTile);
      if (row.evaluate().isNotEmpty) {
        await tester.tap(row.first, warnIfMissed: false);
        await settle(tester);
        await shot(tester, '72-payee-detail');
      }
      await popIfPossible(tester);
      await popIfPossible(tester);
    });
  });

  // ---------------------------------------------------------------------------
  // 9. Settings — every subpage + theme switch (dark mode).
  // ---------------------------------------------------------------------------
  testWidgets('journey 09 — settings and dark mode', (tester) async {
    await bootSeeded(tester);

    await step('more-menu', () async {
      await goRoute(tester, '/more');
      await shot(tester, '73-more-menu');
    });

    final settings = <String, String>{
      '74-settings-profile': '/more/settings/profile',
      '75-settings-notifications': '/more/settings/notifications',
      '76-settings-ai': '/more/settings/ai',
      '77-settings-ai-logs': '/more/settings/ai-logs',
      '78-settings-sync': '/more/settings/sync',
    };
    for (final entry in settings.entries) {
      await step(entry.key, () async {
        await pushRoute(tester, entry.value);
        await shot(tester, entry.key);
        await popIfPossible(tester);
      });
    }

    await step('appearance-and-dark-mode', () async {
      await pushRoute(tester, '/more/settings/appearance');
      await shot(tester, '79-settings-appearance');
      // Open the theme dropdown (trailing control shows current mode label).
      if (await tapText(tester, 'System', last: true)) {
        await shot(tester, '80-appearance-theme-menu');
        await tapText(tester, 'Dark', last: true);
        await shot(tester, '81-settings-appearance-dark');
      }
      await popIfPossible(tester);
      await goRoute(tester, '/');
      await shot(tester, '82-dashboard-dark-mode');
      await goRoute(tester, '/transactions');
      await shot(tester, '83-transactions-dark-mode');
    });

    await step('security-about', () async {
      await pushRoute(tester, '/more/settings/security');
      await shot(tester, '84-settings-security');
      await popIfPossible(tester);
      await pushRoute(tester, '/more/settings/about');
      await shot(tester, '85-settings-about');
      await popIfPossible(tester);
    });
  });

  // ---------------------------------------------------------------------------
  // 10. Secondary — reports, report detail, insights, households.
  // ---------------------------------------------------------------------------
  testWidgets('journey 10 — secondary screens', (tester) async {
    await bootSeeded(tester);

    await step('reports', () async {
      await pushRoute(tester, '/more/reports');
      await shot(tester, '86-reports');
      await popIfPossible(tester);
    });

    await step('report-detail', () async {
      await pushRoute(tester, '/more/reports/spending-category');
      await tester.pump(const Duration(seconds: 2));
      await shot(tester, '87-report-detail');
      await popIfPossible(tester);
    });

    await step('report-detail-income-expenses', () async {
      await pushRoute(tester, '/more/reports/income-vs-expenses');
      await tester.pump(const Duration(seconds: 2));
      await shot(tester, '93-report-detail-income-expenses');
      await popIfPossible(tester);
    });

    await step('report-detail-net-worth', () async {
      await pushRoute(tester, '/more/reports/net-worth');
      await tester.pump(const Duration(seconds: 2));
      await shot(tester, '94-report-detail-net-worth');
      await popIfPossible(tester);
    });

    await step('insights', () async {
      await pushRoute(tester, '/more/insights');
      await shot(tester, '88-insights');
      await popIfPossible(tester);
    });

    await step('households', () async {
      await pushRoute(tester, '/more/households');
      await shot(tester, '89-households-empty');
      // No households exist: the sheet opens via the empty-state CTA.
      if (await tapTooltip(tester, 'Add household') ||
          await tapText(tester, 'Create Household')) {
        await shot(tester, '90-household-create-sheet');
        await dismissSheet(tester);
      }
      await popIfPossible(tester);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/presentation/sheets/add_transaction_sheet.dart';
import 'package:lootr/presentation/sheets/quick_actions_sheet.dart';

void main() {
  Widget host() {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => const QuickActionsSheet(),
                  ),
                  child: const Text('open-sheet'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/transactions/new',
          builder: (context, state) =>
              const Scaffold(body: Text('manual-route')),
        ),
        GoRoute(
          path: '/scan',
          builder: (context, state) => const Scaffold(body: Text('scan-route')),
        ),
      ],
    );
    return MaterialApp.router(theme: AppTheme.light, routerConfig: router);
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open-sheet'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders quick-add input with segmented control defaulting to Quick',
    (tester) async {
      await openSheet(tester);

      expect(find.text('Add Transaction'), findsOneWidget);
      expect(
        find.text('Describe it below, or pick a mode above.'),
        findsOneWidget,
      );
      expect(find.text('Coffee at Starbucks ₱180'), findsOneWidget);

      // All three mode segments are visible up front — no dropdown.
      expect(find.text('Quick'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);

      // The active segment reflects the actual mode: this sheet is quick/NL
      // mode, so Quick must be selected (regression: the old pill said
      // "Manual" while the sheet was in quick mode).
      final tabs = tester.widget<EntryModeTabs>(find.byType(EntryModeTabs));
      expect(tabs.selected, EntryMode.quick);
    },
  );

  testWidgets('tapping Manual opens the full add-transaction flow in one tap', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();

    expect(find.text('manual-route'), findsOneWidget);
  });

  testWidgets('tapping Scan opens the receipt scan flow', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.text('scan-route'), findsOneWidget);
  });
}

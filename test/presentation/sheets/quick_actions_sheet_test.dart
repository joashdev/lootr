import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/presentation/sheets/quick_actions_sheet.dart';

void main() {
  Widget host() => MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: QuickActionsSheet()),
  );

  testWidgets('QuickActionsSheet renders the current quick-add actions', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Add Transaction'), findsOneWidget);
    expect(
      find.text('Describe it below, or pick a mode above.'),
      findsOneWidget,
    );
    expect(find.text('Coffee at Starbucks ₱180'), findsOneWidget);
    // Entry-mode dropdown trigger, with Manual/Scan behind the popup.
    expect(find.text('Manual'), findsOneWidget);

    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();
    expect(find.text('Scan'), findsOneWidget);
  });
}

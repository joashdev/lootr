import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/presentation/sheets/quick_actions_sheet.dart';

void main() {
  Widget host() => MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: QuickActionsSheet()),
      );

  testWidgets('QuickActionsSheet renders its three actions (not an empty box)',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Add Transaction'), findsOneWidget);
    expect(find.text('Quick Add'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
  });
}

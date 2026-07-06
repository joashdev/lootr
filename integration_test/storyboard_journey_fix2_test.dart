import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lootr/main.dart' as app;

/// Captures the one remaining journey shot: the New Household sheet (90),
/// opened via the empty-state "Create Household" CTA.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

  Future<bool> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    if (finder.evaluate().isEmpty) return false;
    await tester.tap(finder.first, warnIfMissed: false);
    await settle(tester);
    return true;
  }

  testWidgets('fix2 — household create sheet', (tester) async {
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }
    await resetAppState();
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await settle(tester);

    for (var i = 0; i < 3; i++) {
      await tapText(tester, 'Next');
    }
    final nameField = find.byType(TextField);
    if (nameField.evaluate().isNotEmpty) {
      await tester.enterText(nameField.first, 'Alex');
      await settle(tester);
    }
    await tapText(tester, 'Get Started');
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);

    final ctx = tester.element(find.byType(Navigator).first);
    GoRouter.of(ctx).go('/more');
    await settle(tester);
    GoRouter.of(ctx).push('/more/households');
    await settle(tester);

    if (await tapText(tester, 'Create Household')) {
      await settle(tester);
      await binding.takeScreenshot('journey/90-household-create-sheet');
    }
  });
}

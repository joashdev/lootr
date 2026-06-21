import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/app.dart';
import 'package:lootr/application/providers/onboarding_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const App(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

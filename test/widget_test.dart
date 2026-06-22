import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lootr/app.dart';
import 'package:lootr/application/providers/onboarding_provider.dart';
import 'package:lootr/main.dart';

void main() {
  testWidgets('AppBootstrap renders startup loading while preferences load', (
    WidgetTester tester,
  ) async {
    final preferences = Completer<SharedPreferences>();

    await tester.pumpWidget(
      AppBootstrap(sharedPreferencesFuture: preferences.future),
    );

    expect(find.text('Starting Lootr...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('App renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const App(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

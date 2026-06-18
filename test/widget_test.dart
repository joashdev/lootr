import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: App(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

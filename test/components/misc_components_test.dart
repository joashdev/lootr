import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/presentation/shared/components/components.dart';

Widget wrapWithTheme(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
    home: Scaffold(body: child),
  );
}

void main() {
  group('EmptyState', () {
    testWidgets('renders in light mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const EmptyState(
          headline: 'No transactions',
          subtext: 'Add your first transaction',
          ctaLabel: 'Add',
        ),
      ));
      expect(find.text('No transactions'), findsOneWidget);
      expect(find.text('Add your first transaction'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const EmptyState(
          headline: 'Empty',
          subtext: 'Nothing here',
          ctaLabel: 'Create',
        ),
        brightness: Brightness.dark,
      ));
      expect(find.text('Empty'), findsOneWidget);
      expect(find.text('Nothing here'), findsOneWidget);
    });

    testWidgets('calls onCtaPressed when CTA tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrapWithTheme(
        EmptyState(
          headline: 'Test',
          subtext: 'Test',
          ctaLabel: 'Go',
          onCtaPressed: () => tapped = true,
        ),
      ));
      await tester.tap(find.text('Go'));
      expect(tapped, true);
    });
  });

  group('SheetHandle', () {
    testWidgets('renders in light mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const Column(children: [SheetHandle()]),
      ));
      expect(find.byType(SheetHandle), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const Column(children: [SheetHandle()]),
        brightness: Brightness.dark,
      ));
      expect(find.byType(SheetHandle), findsOneWidget);
    });
  });
}

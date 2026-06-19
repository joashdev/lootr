import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/presentation/shared/components/cards/cards.dart';

Widget wrapWithTheme(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('StandardCard', () {
    testWidgets('renders child in light mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const StandardCard(child: Text('Content')),
      ));
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('renders child in dark mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const StandardCard(child: Text('Content')),
        brightness: Brightness.dark,
      ));
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrapWithTheme(
        StandardCard(
          child: const Text('Content'),
          onTap: () => tapped = true,
        ),
      ));
      await tester.tap(find.text('Content'));
      expect(tapped, true);
    });
  });

  group('HeroCard', () {
    testWidgets('renders child in light mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const HeroCard(child: Text('Content')),
      ));
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('renders child in dark mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const HeroCard(child: Text('Content')),
        brightness: Brightness.dark,
      ));
      expect(find.text('Content'), findsOneWidget);
    });
  });

  group('CompactRowCard', () {
    testWidgets('renders child in light mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const CompactRowCard(child: Text('Content')),
      ));
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('renders child in dark mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const CompactRowCard(child: Text('Content')),
        brightness: Brightness.dark,
      ));
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrapWithTheme(
        CompactRowCard(
          child: const Text('Content'),
          onTap: () => tapped = true,
        ),
      ));
      await tester.tap(find.text('Content'));
      expect(tapped, true);
    });
  });
}

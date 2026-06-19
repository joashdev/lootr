import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/presentation/shared/components/buttons/buttons.dart';

Widget wrapWithTheme(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('PrimaryButton', () {
    testWidgets('renders label in light mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const PrimaryButton(label: 'Test'),
      ));
      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('renders label in dark mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const PrimaryButton(label: 'Test'),
        brightness: Brightness.dark,
      ));
      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('shows loading indicator', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const PrimaryButton(label: 'Test', isLoading: true),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Test'), findsNothing);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrapWithTheme(
        PrimaryButton(label: 'Test', onPressed: () => tapped = true),
      ));
      await tester.tap(find.text('Test'));
      expect(tapped, true);
    });

    testWidgets('does not call onPressed when disabled', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrapWithTheme(
        PrimaryButton(label: 'Test', onPressed: null),
      ));
      await tester.tap(find.text('Test'));
      expect(tapped, false);
    });
  });

  group('SecondaryButton', () {
    testWidgets('renders label in light mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const SecondaryButton(label: 'Test'),
      ));
      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('renders label in dark mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const SecondaryButton(label: 'Test'),
        brightness: Brightness.dark,
      ));
      expect(find.text('Test'), findsOneWidget);
    });
  });

  group('GhostButton', () {
    testWidgets('renders label in light mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const GhostButton(label: 'Test'),
      ));
      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('renders label in dark mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const GhostButton(label: 'Test'),
        brightness: Brightness.dark,
      ));
      expect(find.text('Test'), findsOneWidget);
    });
  });

  group('AppIconButton', () {
    testWidgets('renders icon in light mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const AppIconButton(icon: Icons.add),
      ));
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('renders icon in dark mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const AppIconButton(icon: Icons.add),
        brightness: Brightness.dark,
      ));
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrapWithTheme(
        AppIconButton(icon: Icons.add, onPressed: () => tapped = true),
      ));
      await tester.tap(find.byIcon(Icons.add));
      expect(tapped, true);
    });
  });
}

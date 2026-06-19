import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/presentation/shared/components/progress/progress.dart';

Widget wrapWithTheme(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('BudgetProgressBar', () {
    testWidgets('renders in light mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const BudgetProgressBar(progress: 0.5),
      ));
      expect(find.byType(BudgetProgressBar), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const BudgetProgressBar(progress: 0.75),
        brightness: Brightness.dark,
      ));
      expect(find.byType(BudgetProgressBar), findsOneWidget);
    });

    testWidgets('handles full progress', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const BudgetProgressBar(progress: 1.0),
      ));
      expect(find.byType(BudgetProgressBar), findsOneWidget);
    });

    testWidgets('handles zero progress', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const BudgetProgressBar(progress: 0.0),
      ));
      expect(find.byType(BudgetProgressBar), findsOneWidget);
    });
  });

  group('Sparkline', () {
    testWidgets('renders in light mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const Sparkline(data: [1.0, 2.0, 3.0, 2.0, 4.0]),
      ));
      expect(find.byType(Sparkline), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const Sparkline(data: [5.0, 3.0, 4.0, 6.0]),
        brightness: Brightness.dark,
      ));
      expect(find.byType(Sparkline), findsOneWidget);
    });

    testWidgets('handles single data point', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const Sparkline(data: [1.0]),
      ));
      expect(find.byType(Sparkline), findsOneWidget);
    });

    testWidgets('handles empty data', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const Sparkline(data: []),
      ));
      expect(find.byType(Sparkline), findsOneWidget);
    });
  });
}

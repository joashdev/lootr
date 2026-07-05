import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/core/constants/enums.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/presentation/shared/components/badges/badges.dart';

Widget wrapWithTheme(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('TransactionRow', () {
    testWidgets('renders in light mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const TransactionRow(
          payee: 'Starbucks',
          amount: 5.50,
          category: 'Food',
          time: '10:30 AM',
          direction: TransactionDirection.expense,
        ),
      ));
      expect(find.text('Starbucks'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('-₱5.50'), findsOneWidget);
      expect(find.text('10:30 AM'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const TransactionRow(
          payee: 'Acme Inc',
          amount: 1000.00,
          direction: TransactionDirection.income,
        ),
        brightness: Brightness.dark,
      ));
      expect(find.text('Acme Inc'), findsOneWidget);
      expect(find.text('+₱1,000.00'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrapWithTheme(
        TransactionRow(
          payee: 'Test',
          amount: 10.0,
          onTap: () => tapped = true,
        ),
      ));
      await tester.tap(find.text('Test'));
      expect(tapped, true);
    });
  });

  group('AppFilterChip', () {
    testWidgets('renders active state in light mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const AppFilterChip(label: 'Active', isActive: true),
      ));
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('renders inactive state in dark mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const AppFilterChip(label: 'Inactive', isActive: false),
        brightness: Brightness.dark,
      ));
      expect(find.text('Inactive'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrapWithTheme(
        AppFilterChip(label: 'Test', isActive: false, onTap: () => tapped = true),
      ));
      await tester.tap(find.text('Test'));
      expect(tapped, true);
    });
  });

  group('StatusBadge', () {
    testWidgets('renders success badge in light mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const StatusBadge(label: 'Active', color: StatusBadgeColor.success),
      ));
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('renders warning badge in dark mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const StatusBadge(label: 'Warning', color: StatusBadgeColor.warning),
        brightness: Brightness.dark,
      ));
      expect(find.text('WARNING'), findsOneWidget);
    });

    testWidgets('renders danger badge', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const StatusBadge(label: 'Error', color: StatusBadgeColor.danger),
      ));
      expect(find.text('ERROR'), findsOneWidget);
    });

    testWidgets('uppercases label', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const StatusBadge(label: 'lowercase'),
      ));
      expect(find.text('LOWERCASE'), findsOneWidget);
    });
  });
}

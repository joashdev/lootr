import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/core/constants/enums.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/presentation/shared/components/inputs/inputs.dart';

Widget wrapWithTheme(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('AppTextField', () {
    testWidgets('renders in light mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const AppTextField(hintText: 'Enter text'),
      ));
      expect(find.text('Enter text'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const AppTextField(hintText: 'Enter text'),
        brightness: Brightness.dark,
      ));
      expect(find.text('Enter text'), findsOneWidget);
    });

    testWidgets('calls onChanged when text entered', (tester) async {
      String changed = '';
      await tester.pumpWidget(wrapWithTheme(
        AppTextField(onChanged: (v) => changed = v),
      ));
      await tester.enterText(find.byType(TextField), 'hello');
      expect(changed, 'hello');
    });
  });

  group('SearchInput', () {
    testWidgets('renders in light mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const SearchInput(),
      ));
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const SearchInput(),
        brightness: Brightness.dark,
      ));
      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });

  group('AmountInput', () {
    testWidgets('renders in light mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const AmountInput(direction: TransactionDirection.expense),
      ));
      expect(find.text('PHP'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const AmountInput(direction: TransactionDirection.income),
        brightness: Brightness.dark,
      ));
      expect(find.text('PHP'), findsOneWidget);
    });

    testWidgets('shows currency prefix', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const AmountInput(direction: TransactionDirection.transfer, currency: 'USD'),
      ));
      expect(find.text('USD'), findsOneWidget);
    });
  });
}

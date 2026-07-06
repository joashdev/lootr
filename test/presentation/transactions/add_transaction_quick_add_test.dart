import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/accounts_provider.dart';
import 'package:lootr/application/providers/categories_provider.dart';
import 'package:lootr/application/providers/debts_provider.dart';
import 'package:lootr/application/providers/filtered_transactions_provider.dart';
import 'package:lootr/application/providers/payees_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/domain/entities/account.dart';
import 'package:lootr/domain/entities/category.dart';
import 'package:lootr/domain/entities/debt_record.dart';
import 'package:lootr/domain/entities/payee.dart';
import 'package:lootr/domain/entities/transaction.dart';
import 'package:lootr/presentation/sheets/add_transaction_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

Widget _wrap(
  Widget child, {
  List<Account> accounts = const [],
  List<Category> categories = const [],
  List<Payee> payees = const [],
}) {
  return ProviderScope(
    overrides: [
      accountsProvider.overrideWith((ref) => Stream.value(accounts)),
      categoriesProvider.overrideWith((ref) => Stream.value(categories)),
      payeesProvider.overrideWith((ref) => Stream.value(payees)),
      debtsProvider.overrideWith((ref) => Stream.value(const <DebtRecord>[])),
      filteredTransactionsProvider.overrideWith(
        (ref) => Stream.value(const <Transaction>[]),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
}

Account _gcash() => Account(
  id: 'acc-gcash',
  ownerUserId: 'user-1',
  name: 'GCash',
  accountType: 'ewallet',
  balance: 500,
  currencyCode: 'PHP',
  isArchived: false,
  isHidden: false,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Category _category(String id, String name, {String group = 'expense'}) =>
    Category(
      id: id,
      name: name,
      categoryGroup: group,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Future<void> _parseQuickInput(WidgetTester tester, String input) async {
  await tester.enterText(find.byType(TextField).first, input);
  await tester.tap(find.byIcon(LucideIcons.arrowRight));
  await tester.pump();
}

void main() {
  group('AddTransactionSheet quick add', () {
    testWidgets('shows mode segments and mic in quick mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AddTransactionSheet(startInQuickMode: true),
          accounts: [_gcash()],
        ),
      );
      await tester.pump();

      // Segmented control shows all three modes; Quick reflects the active
      // mode (regression: the old dropdown pill could display "Manual" while
      // the sheet was in quick mode).
      expect(find.text('Quick'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      final tabs = tester.widget<EntryModeTabs>(find.byType(EntryModeTabs));
      expect(tabs.selected, EntryMode.quick);

      expect(find.text('Describe your transaction...'), findsOneWidget);
      // Mic toggle is visible but non-functional in V1.
      expect(find.byIcon(LucideIcons.mic), findsOneWidget);
    });

    testWidgets('tapping Manual segment switches to the full manual form', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AddTransactionSheet(startInQuickMode: true),
          accounts: [_gcash()],
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Manual'));
      await tester.pumpAndSettle();

      // One tap: full manual form is visible and the segment tracks the mode.
      final tabs = tester.widget<EntryModeTabs>(find.byType(EntryModeTabs));
      expect(tabs.selected, EntryMode.manual);
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('Transaction Mode'), findsOneWidget);
      expect(find.text('Describe your transaction...'), findsNothing);

      // And back: tapping Quick returns to quick mode, selection follows.
      await tester.tap(find.text('Quick'));
      await tester.pumpAndSettle();
      final tabsAfter = tester.widget<EntryModeTabs>(
        find.byType(EntryModeTabs),
      );
      expect(tabsAfter.selected, EntryMode.quick);
      expect(find.text('Describe your transaction...'), findsOneWidget);
    });

    testWidgets('parses "mcdo 250 gcash" into a preview card', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AddTransactionSheet(startInQuickMode: true),
          accounts: [_gcash()],
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'mcdo 250 gcash');
      await tester.tap(find.byIcon(LucideIcons.arrowRight));
      await tester.pump();

      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('₱250.00'), findsOneWidget);
      expect(find.textContaining('mcdo'), findsWidgets);
      expect(find.textContaining('gcash'), findsWidgets);
      expect(find.text('Edit manually'), findsOneWidget);
    });

    testWidgets('"Edit manually" switches to prefilled manual form', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AddTransactionSheet(startInQuickMode: true),
          accounts: [_gcash()],
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'mcdo 250 gcash');
      await tester.tap(find.byIcon(LucideIcons.arrowRight));
      await tester.pump();

      await tester.tap(find.text('Edit manually'));
      await tester.pumpAndSettle();

      // Manual form now visible with amount prefilled, and the segmented
      // control reflects the switch to manual mode.
      expect(find.text('Add Transaction'), findsWidgets);
      expect(find.text('250.00'), findsOneWidget);
      expect(find.text('Transaction Mode'), findsOneWidget);
      final tabs = tester.widget<EntryModeTabs>(find.byType(EntryModeTabs));
      expect(tabs.selected, EntryMode.manual);
    });

    testWidgets('strips "at" connector so preview payee is Starbucks', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AddTransactionSheet(startInQuickMode: true),
          accounts: [_gcash()],
        ),
      );
      await tester.pump();

      await _parseQuickInput(tester, 'Coffee at Starbucks 180');

      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Starbucks'), findsOneWidget);
      expect(find.text('at Starbucks'), findsNothing);
    });

    testWidgets(
      'preview maps parsed category to the real user category by fuzzy match',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const AddTransactionSheet(startInQuickMode: true),
            accounts: [_gcash()],
            categories: [_category('cat-food', 'Food & Dining')],
          ),
        );
        await tester.pump();

        // Parser emits "Dining" for coffee; the user category is
        // "Food & Dining" so the preview must show the real name.
        await _parseQuickInput(tester, 'Coffee at Starbucks 180');

        expect(find.text('Preview'), findsOneWidget);
        expect(find.text('Food & Dining'), findsOneWidget);
        expect(find.text('Dining'), findsNothing);
      },
    );

    testWidgets(
      'preview shows Uncategorized when parsed category matches nothing',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const AddTransactionSheet(startInQuickMode: true),
            accounts: [_gcash()],
            categories: [_category('cat-transport', 'Transport')],
          ),
        );
        await tester.pump();

        await _parseQuickInput(tester, 'Coffee at Starbucks 180');

        expect(find.text('Preview'), findsOneWidget);
        expect(find.text('Uncategorized'), findsOneWidget);
        expect(find.text('Dining'), findsNothing);
      },
    );

    testWidgets(
      'confidence indicator is shown once overall, not per preview row',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const AddTransactionSheet(startInQuickMode: true),
            accounts: [_gcash()],
            categories: [_category('cat-food', 'Food & Dining')],
          ),
        );
        await tester.pump();

        // Multi-field parse: amount, payee, account, category, direction.
        await _parseQuickInput(tester, 'Coffee at Starbucks 180 gcash');

        expect(find.text('Preview'), findsOneWidget);
        expect(find.textContaining('Confidence '), findsOneWidget);
        final dots = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_ConfidenceDot',
        );
        expect(dots, findsOneWidget);
      },
    );
  });
}

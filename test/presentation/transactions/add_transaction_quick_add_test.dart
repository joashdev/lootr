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

void main() {
  group('AddTransactionSheet quick add', () {
    testWidgets('shows mode toggle and mic in quick mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AddTransactionSheet(startInQuickMode: true),
          accounts: [_gcash()],
        ),
      );
      await tester.pump();

      expect(find.text('Quick'), findsOneWidget);
      expect(find.text('Describe your transaction...'), findsOneWidget);
      // Mic toggle is visible but non-functional in V1.
      expect(find.byIcon(LucideIcons.mic), findsOneWidget);
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

      // Manual form now visible with amount prefilled.
      expect(find.text('Add Transaction'), findsWidgets);
      expect(find.text('250.00'), findsOneWidget);
      expect(find.text('Transaction Mode'), findsOneWidget);
    });
  });
}

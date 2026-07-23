import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/period_context_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/presentation/sheets/composite_budget_sheet.dart';

void main() {
  testWidgets(
    'keeps an explicit member visible and removable outside the ledger period',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final now = DateTime(2026, 7, 15);

      await db.users.insertOne(UsersCompanion.insert(id: 'user'));
      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'account',
          ownerUserId: 'user',
          name: 'Wallet',
          accountType: 'cash',
          currencyCode: const Value('PHP'),
        ),
      );
      await db.budgetDefinitions.insertOne(
        BudgetDefinitionsCompanion.insert(
          id: 'budget',
          ownerUserId: 'user',
          name: const Value('Essentials'),
          amountAtoms: '100000',
          amountScale: 2,
          currencyCode: 'PHP',
          membershipMode: const Value('explicit_only'),
        ),
      );
      await db.transactions.insertOne(
        TransactionsCompanion.insert(
          id: 'old-member',
          accountId: 'account',
          amount: 250,
          amountAtoms: const Value('25000'),
          amountScale: const Value(2),
          currencyCode: const Value('PHP'),
          title: const Value('Old membership'),
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2024, 1, 10),
        ),
      );
      await db.transactions.insertOne(
        TransactionsCompanion.insert(
          id: 'recent-option',
          accountId: 'account',
          amount: 75,
          amountAtoms: const Value('7500'),
          amountScale: const Value(2),
          currencyCode: const Value('PHP'),
          title: const Value('Recent groceries'),
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: now,
        ),
      );
      await db.budgetTransactionMemberships.insertOne(
        BudgetTransactionMembershipsCompanion.insert(
          id: 'membership',
          budgetId: 'budget',
          transactionId: const Value('old-member'),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith((ref) => db),
            periodContextClockProvider.overrideWithValue(now),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: CompositeBudgetSheet(budgetId: 'budget'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Explicit transactions'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Explicit transactions'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Old membership'), findsOneWidget);
      expect(find.textContaining('Jan 10, 2024'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('composite-transaction-search')),
        'groceries',
      );
      await tester.pump();

      // Search narrows available choices without hiding durable selections.
      expect(find.textContaining('Old membership'), findsOneWidget);
      expect(find.textContaining('Recent groceries'), findsOneWidget);

      final memberTile = find.byKey(
        const Key('composite-transaction-old-member'),
      );
      await tester.tap(
        find.descendant(
          of: memberTile,
          matching: find.byType(DropdownButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ignore').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Old membership'), findsNothing);
      expect(find.text('0 included · 0 excluded'), findsWidgets);

      await tester.scrollUntilVisible(
        find.text('Save budget'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save budget'));
      await tester.pumpAndSettle();
      expect(
        await (db.select(
          db.budgetTransactionMemberships,
        )..where((row) => row.budgetId.equals('budget'))).get(),
        isEmpty,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));
    },
  );
}

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/presentation/screens/more/recurring_screen.dart';

void main() {
  Future<void> flushStreamCloseTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
  }

  testWidgets(
    'subscription filter shows templates classified from category metadata',
    (tester) async {
      final db = AppDatabase.inMemory();
      addTearDown(() => db.close());

      await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-1',
          ownerUserId: 'usr-1',
          name: 'BDO',
          accountType: 'bank',
        ),
      );
      await db.payees.insertOne(
        PayeesCompanion.insert(
          id: 'pay-1',
          normalizedName: 'acme-music',
          displayName: const Value('Acme Music'),
        ),
      );
      await db.categories.insertOne(
        CategoriesCompanion.insert(
          id: 'cat-1',
          name: 'Subscriptions',
          categoryGroup: 'expense',
        ),
      );
      await db.recurringTemplates.insertOne(
        RecurringTemplatesCompanion.insert(
          id: 'rec-1',
          accountId: 'acc-1',
          payeeId: const Value('pay-1'),
          categoryId: const Value('cat-1'),
          amount: 499,
          amountAtoms: const Value('4990000'),
          amountScale: const Value(4),
          currencyCode: const Value('USD'),
          recurrenceRule: 'monthly',
          nextOccurrenceAt: Value(DateTime(2026, 8, 1, 9)),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWith((ref) => db)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const RecurringScreen(initialFilter: 'subscription'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Acme Music'), findsOneWidget);
      expect(find.text(r'$499.0000'), findsOneWidget);
      expect(find.text('No subscriptions found'), findsNothing);
      await flushStreamCloseTimers(tester);
    },
  );
}

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/period_context_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/presentation/screens/budgets/imported_budget_detail_screen.dart';

void main() {
  testWidgets('shows imported review state and exact inclusion reason', (
    tester,
  ) async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final now = DateTime.now();

    await db.users.insertOne(UsersCompanion.insert(id: 'user'));
    await db.accounts.insertOne(
      AccountsCompanion.insert(
        id: 'account',
        ownerUserId: 'user',
        name: 'Account',
        accountType: 'cash',
        currencyCode: const Value('USD'),
        currencyPrecision: const Value(4),
      ),
    );
    await db.budgetDefinitions.insertOne(
      BudgetDefinitionsCompanion.insert(
        id: 'imported',
        ownerUserId: 'user',
        name: const Value('Imported composite'),
        amountAtoms: '20000',
        amountScale: 4,
        currencyCode: 'USD',
        membershipMode: const Value('explicit_only'),
      ),
    );
    await db.transactions.insertOne(
      TransactionsCompanion.insert(
        id: 'transaction',
        accountId: 'account',
        amount: 0,
        amountAtoms: const Value('1'),
        amountScale: const Value(4),
        currencyCode: const Value('USD'),
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        occurredAt: now,
      ),
    );
    await db.budgetTransactionMemberships.insertOne(
      BudgetTransactionMembershipsCompanion.insert(
        id: 'attached',
        budgetId: 'imported',
        transactionId: const Value('transaction'),
      ),
    );
    await db.budgetDefinitions.insertOne(
      BudgetDefinitionsCompanion.insert(
        id: 'overlap',
        ownerUserId: 'user',
        name: const Value('Flexible spending'),
        amountAtoms: '30000',
        amountScale: 4,
        currencyCode: 'USD',
        membershipMode: const Value('explicit_only'),
      ),
    );
    await db.budgetTransactionMemberships.insertOne(
      BudgetTransactionMembershipsCompanion.insert(
        id: 'overlap-attached',
        budgetId: 'overlap',
        transactionId: const Value('transaction'),
      ),
    );
    await db.budgetPeriods.insertOne(
      BudgetPeriodsCompanion.insert(
        id: 'history',
        budgetId: 'imported',
        startsAt: DateTime(now.year, now.month),
        endsAt: now.month == 12
            ? DateTime(now.year + 1)
            : DateTime(now.year, now.month + 1),
        amountAtoms: '20000',
        amountScale: 4,
        currencyCode: 'USD',
      ),
    );
    await db.budgetAccountMemberships.insertOne(
      BudgetAccountMembershipsCompanion.insert(
        id: 'missing',
        budgetId: 'imported',
        sourceReference: const Value('redacted-reference'),
        reviewState: const Value('missing_reference'),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWith((ref) => db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ImportedBudgetDetailScreen(id: 'imported'),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ImportedBudgetDetailScreen)),
    );
    container.read(periodContextProvider.notifier).selectMonth(now);

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (tester.any(find.text('Imported composite'))) break;
    }

    Future<void> reveal(String text) async {
      for (var i = 0; i < 20 && !tester.any(find.text(text)); i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -250));
        await tester.pump();
      }
    }

    expect(find.text('Imported composite'), findsOneWidget);
    await reveal('Scope and membership');
    expect(find.text('Scope and membership'), findsOneWidget);
    expect(find.text('Attached transactions only'), findsOneWidget);
    await reveal('Unresolved imported members');
    expect(find.text('Unresolved imported members'), findsOneWidget);
    expect(find.text('redacted-reference'), findsOneWidget);
    await reveal('Overlap information');
    expect(find.text('Overlap information'), findsOneWidget);
    expect(find.text('Flexible spending'), findsOneWidget);
    expect(find.text('1 shared transaction(s)'), findsOneWidget);
    await reveal('Needs review');
    expect(find.text('Needs review'), findsOneWidget);
    expect(find.textContaining('1 missing'), findsOneWidget);
    await reveal('Included because this transaction is explicitly attached.');
    expect(
      find.text('Included because this transaction is explicitly attached.'),
      findsOneWidget,
    );
    expect(find.byIcon(LucideIcons.calendarRange), findsWidgets);
    expect(find.textContaining('0.0001'), findsWidgets);
    expect(find.text('Edit'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
  });
}

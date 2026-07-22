import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/entities/transaction.dart';
import 'package:lootr/presentation/screens/transactions/transaction_detail_screen.dart';
import 'package:lootr/presentation/screens/transactions/widgets/transaction_detail_card.dart';

void main() {
  testWidgets('shows both exact amounts for a cross-currency transfer', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    await database.users.insertOne(UsersCompanion.insert(id: 'owner'));
    await database.accounts.insertOne(
      AccountsCompanion.insert(
        id: 'source',
        ownerUserId: 'owner',
        name: 'Source account',
        accountType: 'bank',
        currencyCode: const Value('USD'),
      ),
    );
    await database.accounts.insertOne(
      AccountsCompanion.insert(
        id: 'destination',
        ownerUserId: 'owner',
        name: 'Destination account',
        accountType: 'bank',
        currencyCode: const Value('EUR'),
        currencyPrecision: const Value(4),
      ),
    );
    await database.transfers.insertOne(
      TransfersCompanion.insert(
        id: 'cross-currency',
        sourceAccountId: 'source',
        destinationAccountId: 'destination',
        amount: 12.34,
        sourceAmountAtoms: const Value('1234'),
        sourceAmountScale: const Value(2),
        sourceCurrencyCode: const Value('USD'),
        destinationAmountAtoms: const Value('112345'),
        destinationAmountScale: const Value(4),
        destinationCurrencyCode: const Value('EUR'),
        occurredAt: DateTime(2026, 7, 22, 12),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWith((ref) => database)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const TransactionDetailScreen(id: 'cross-currency'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sent'), findsOneWidget);
    expect(find.text(r'$12.34'), findsNWidgets(2));
    expect(find.text('Received'), findsOneWidget);
    expect(find.text('€11.2345'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('shows a preserved transaction title in details', (tester) async {
    final now = DateTime(2026, 7, 22, 12);
    final transaction = Transaction(
      id: 'transaction',
      accountId: 'account',
      amount: 10,
      title: 'Imported merchant',
      direction: 'expense',
      mode: 'one_time',
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: TransactionDetailCard(
            transaction: transaction,
            accountName: 'Account',
          ),
        ),
      ),
    );

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Imported merchant'), findsOneWidget);
  });
}

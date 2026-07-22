import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/domain/entities/transaction.dart';
import 'package:lootr/presentation/screens/transactions/widgets/transaction_row.dart';

void main() {
  testWidgets('shows the transaction currency at its configured scale', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 22, 12);
    final transaction = Transaction(
      id: 'transaction-1',
      accountId: 'account-1',
      amount: 0.000000000001,
      amountAtoms: '1',
      amountScale: 12,
      currencyCode: 'BTC',
      direction: 'expense',
      mode: 'expense',
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: TransactionRowWidget(
            transaction: transaction,
            accountName: 'Account',
          ),
        ),
      ),
    );

    expect(find.text('-BTC0.000000000001'), findsOneWidget);
  });
}

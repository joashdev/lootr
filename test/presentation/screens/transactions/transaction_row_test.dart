import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  testWidgets('uses a preserved title when no payee is attached', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 22, 12);
    final transaction = Transaction(
      id: 'transaction-title',
      accountId: 'account-1',
      amount: 10,
      title: 'Imported merchant',
      note: 'Imported note',
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
          body: TransactionRowWidget(
            transaction: transaction,
            accountName: 'Account',
          ),
        ),
      ),
    );

    expect(find.text('Imported merchant'), findsOneWidget);
    expect(find.text('Imported note'), findsNothing);
  });

  for (final (width, scale, theme) in [
    (390.0, 1.0, AppTheme.light),
    (320.0, 2.0, AppTheme.dark),
  ]) {
    testWidgets('wraps a long ledger row at ${width}dp and ${scale}x text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const title = 'Metropolitan Market and Community Grocery';
      const subtitle = 'Food and Dining · Everyday Checking Account';
      const amount = '-BTC0.000000000001';
      final date = DateTime(2026, 7, 22, 12);
      final transaction = Transaction(
        id: 'transaction-long',
        accountId: 'account-1',
        amount: 0.000000000001,
        amountAtoms: '1',
        amountScale: 12,
        currencyCode: 'BTC',
        title: title,
        direction: 'expense',
        mode: 'one_time',
        occurredAt: date,
        createdAt: date,
        updatedAt: date,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TransactionRowWidget(
                transaction: transaction,
                accountName: 'Everyday Checking Account',
                categoryName: 'Food and Dining',
                grouped: true,
              ),
            ),
          ),
        ),
      );

      for (final label in [title, subtitle, amount]) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
      }
      if (scale == 2) {
        expect(
          tester.getTopLeft(find.text(amount)).dy,
          greaterThan(tester.getBottomLeft(find.text(subtitle)).dy),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}

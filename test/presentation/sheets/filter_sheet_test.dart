import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/application/providers/accounts_provider.dart';
import 'package:lootr/application/providers/categories_provider.dart';
import 'package:lootr/application/providers/transaction_filters_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/domain/entities/account.dart';
import 'package:lootr/domain/entities/category.dart';
import 'package:lootr/presentation/sheets/filter_sheet.dart';

void main() {
  final now = DateTime(2026, 6, 21);
  final accounts = [
    Account(
      id: 'acc-1',
      ownerUserId: 'usr-1',
      name: 'Wallet',
      accountType: 'cash',
      balance: 1000,
      currencyCode: 'PHP',
      isArchived: false,
      isHidden: false,
      createdAt: now,
      updatedAt: now,
    ),
  ];
  final categories = [
    Category(
      id: 'cat-expense',
      name: 'Groceries',
      categoryGroup: 'expense',
      createdAt: now,
      updatedAt: now,
    ),
    Category(
      id: 'cat-income',
      name: 'Salary',
      categoryGroup: 'income',
      createdAt: now,
      updatedAt: now,
    ),
    Category(
      id: 'cat-transfer',
      name: 'Wallet Transfer',
      categoryGroup: 'transfer',
      createdAt: now,
      updatedAt: now,
    ),
  ];

  Widget buildSheet(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: FilterSheet()),
      ),
    );
  }

  testWidgets('renders all Task 16 sections and footer actions', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        accountsProvider.overrideWith((ref) => Stream.value(accounts)),
        categoriesProvider.overrideWith((ref) => Stream.value(categories)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(buildSheet(container));
    await tester.pumpAndSettle();

    expect(find.text('Direction'), findsOneWidget);
    expect(find.text('Mode'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Amount Range'), findsOneWidget);
    expect(find.text('Date Range'), findsOneWidget);
    expect(find.text('Clear all filters'), findsOneWidget);
    expect(find.text('Apply 0 filters'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Wallet Transfer'), findsOneWidget);
  });

  testWidgets('segmented and list controls update filters immediately', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        accountsProvider.overrideWith((ref) => Stream.value(accounts)),
        categoriesProvider.overrideWith((ref) => Stream.value(categories)),
      ],
    );
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSheet(container));
    await tester.pumpAndSettle();

    final expenseSegment = find.descendant(
      of: find.byType(SegmentedButton<String>),
      matching: find.text('Expense'),
    );
    await tester.ensureVisible(expenseSegment.first);
    await tester.tap(expenseSegment.first);
    await tester.pump();
    expect(container.read(transactionFiltersProvider).direction, 'expense');

    final walletTile = find.widgetWithText(InkWell, 'Wallet');
    await tester.ensureVisible(walletTile);
    await tester.tap(walletTile);
    await tester.pump();
    expect(container.read(transactionFiltersProvider).accountId, 'acc-1');

    final groceriesTile = find.widgetWithText(InkWell, 'Groceries');
    await tester.ensureVisible(groceriesTile);
    await tester.tap(groceriesTile);
    await tester.pump();
    expect(
      container.read(transactionFiltersProvider).categoryId,
      'cat-expense',
    );
  });
}

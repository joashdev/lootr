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
    Account(
      id: 'acc-2',
      ownerUserId: 'usr-1',
      name: 'Digital',
      accountType: 'bank',
      balance: 0,
      currencyCode: 'BTC',
      currencyPrecision: 12,
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
    expect(find.text('Currency'), findsOneWidget);
    expect(find.text('Amount Range'), findsOneWidget);
    expect(find.text('Date Range'), findsOneWidget);
    expect(find.text('Clear all filters'), findsOneWidget);
    // With no filters selected the button is a plain "Apply" — never
    // "Apply 0 filters".
    expect(find.widgetWithText(FilledButton, 'Apply'), findsOneWidget);
    expect(find.text('Apply 0 filters'), findsNothing);
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Wallet Transfer'), findsOneWidget);
  });

  testWidgets(
    'pill controls update filters immediately and allow multiselect',
    (tester) async {
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

      await tester.tap(find.text('Expense').first);
      await tester.pump();
      expect(container.read(transactionFiltersProvider).directions, [
        'expense',
      ]);

      await tester.tap(find.text('Income').first);
      await tester.pump();
      expect(container.read(transactionFiltersProvider).directions, [
        'expense',
        'income',
      ]);

      await tester.tap(find.text('Wallet').first);
      await tester.pump();
      expect(container.read(transactionFiltersProvider).accountIds, ['acc-1']);

      await tester.tap(find.text('Groceries').first);
      await tester.pump();
      expect(container.read(transactionFiltersProvider).categoryIds, [
        'cat-expense',
      ]);
    },
  );

  testWidgets(
    'filter groups stay horizontally scrollable on standard phone width',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          accountsProvider.overrideWith((ref) => Stream.value(accounts)),
          categoriesProvider.overrideWith((ref) => Stream.value(categories)),
        ],
      );
      addTearDown(container.dispose);

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSheet(container));
      await tester.pumpAndSettle();

      expect(find.text('Recurring'), findsOneWidget);

      final horizontalLists = find.byWidgetPredicate(
        (widget) =>
            widget is ListView && widget.scrollDirection == Axis.horizontal,
      );
      await tester.drag(horizontalLists.at(1), const Offset(-240, 0));
      await tester.pumpAndSettle();

      expect(find.text('Installment'), findsOneWidget);

      await tester.tap(find.text('Installment'));
      await tester.pump();

      expect(container.read(transactionFiltersProvider).modes, ['installment']);
    },
  );

  testWidgets('apply button label counts active filters with singular form', (
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

    expect(find.widgetWithText(FilledButton, 'Apply'), findsOneWidget);

    await tester.tap(find.text('Expense').first);
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Apply 1 filter'), findsOneWidget);

    await tester.tap(find.text('Wallet').first);
    await tester.pump();
    expect(
      find.widgetWithText(FilledButton, 'Apply 2 filters'),
      findsOneWidget,
    );
  });

  testWidgets(
    'amount range has no inner apply button and typed amounts are kept',
    (tester) async {
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

      // Only the Date Range section keeps its inline apply link; the Amount
      // Range one is gone (the global Apply covers it).
      expect(find.widgetWithText(TextButton, 'Apply'), findsOneWidget);

      Finder amountField(String hint) => find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == hint,
      );

      await tester.enterText(amountField('Min'), '100');
      await tester.pump();
      await tester.enterText(amountField('Max'), '900');
      await tester.pump();

      // Typed amounts are committed without any inner apply press.
      expect(container.read(transactionFiltersProvider).minAmount, 100);
      expect(container.read(transactionFiltersProvider).maxAmount, 900);
      expect(
        find.widgetWithText(FilledButton, 'Apply 1 filter'),
        findsOneWidget,
      );

      // Global Apply keeps the values and closes the sheet.
      await tester.tap(find.widgetWithText(FilledButton, 'Apply 1 filter'));
      await tester.pumpAndSettle();
      expect(container.read(transactionFiltersProvider).minAmount, 100);
      expect(container.read(transactionFiltersProvider).maxAmount, 900);
    },
  );

  testWidgets('currency selection stores exact decimal coefficient and scale', (
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
    await tester.tap(find.text('BTC'));
    await tester.pump();

    final minimum = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == 'Min',
    );
    await tester.enterText(minimum, '0.000000000001');
    await tester.pump();

    final filters = container.read(transactionFiltersProvider);
    expect(filters.currencyCode, 'BTC');
    expect(filters.minAmountCoefficient, '1');
    expect(filters.minAmountScale, 12);
    expect(filters.minAmount, isNull);
  });
}

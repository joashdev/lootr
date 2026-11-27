import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/application/providers/budget_projection.dart';
import 'package:lootr/application/providers/budgets_tab_provider.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/onboarding_provider.dart';
import 'package:lootr/application/providers/period_context_provider.dart';
import 'package:lootr/core/router/app_router.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/entities/budget.dart';
import 'package:lootr/domain/entities/category.dart';
import 'package:lootr/domain/value_objects/exact_money.dart';
import 'package:lootr/presentation/screens/budgets/imported_budget_detail_screen.dart';
import 'package:lootr/presentation/screens/budgets/widgets/budget_card.dart';
import 'package:lootr/presentation/screens/budgets/widgets/budget_summary_header.dart';
import 'package:lootr/presentation/screens/budgets/widgets/month_navigator.dart';
import 'package:lootr/presentation/sheets/composite_budget_sheet.dart';

class _CompletedOnboarding extends OnboardingNotifier {
  @override
  OnboardingState build() =>
      const OnboardingState(status: OnboardingStatus.completed);
}

BudgetOverview overview(Budget budget) => BudgetOverview(
  id: budget.id,
  name: 'Budget',
  budgeted: budget.exactAmount,
  spent:
      budget.exactSpent ??
      ExactMoney.parse(
        budget.spent.toStringAsFixed(budget.exactAmount.scale),
        budget.exactAmount.currencyCode,
      ),
  startsAt: DateTime(budget.year, budget.month),
  endsAt: DateTime(budget.year, budget.month + 1),
  isImported: false,
  isReadOnly: false,
  needsReview: false,
  missingReferenceCount: 0,
  categoryId: budget.categoryId,
  legacyBudget: budget,
);

void main() {
  final now = DateTime(2026, 6, 21);

  testWidgets('budget overview keeps currency amounts distinct at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          budgetSummaryProvider.overrideWithValue([
            BudgetSummaryPartition(
              currencyCode: 'PHP',
              budgeted: ExactMoney.parse('200.00', 'PHP'),
              spent: ExactMoney.parse('60.00', 'PHP'),
            ),
            BudgetSummaryPartition(
              currencyCode: 'USD',
              budgeted: ExactMoney.parse('100.00', 'USD'),
              spent: ExactMoney.parse('160.00', 'USD'),
            ),
          ]),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: BudgetSummaryHeader(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Left in budgets'), findsOneWidget);
    expect(find.text('₱140.00'), findsOneWidget);
    expect(find.text('30% used'), findsOneWidget);
    expect(find.text('Over budget limits'), findsOneWidget);
    expect(find.text(r'$60.00'), findsOneWidget);
    expect(find.text('160% used'), findsOneWidget);
  });

  testWidgets('selects a period and saves a named budget through the tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    await db.into(db.users).insert(UsersCompanion.insert(id: 'local'));
    final current = DateTime.now();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((_) => db),
        onboardingProvider.overrideWith(_CompletedOnboarding.new),
        periodContextClockProvider.overrideWithValue(current),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider)..go('/budgets');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final create = find.widgetWithText(FilledButton, 'New budget');
    expect(find.text('No budgets for this period'), findsOneWidget);
    expect(create.hitTestable(), findsOneWidget);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(
      container.read(periodContextProvider).startsAt,
      DateTime(current.year, current.month - 1),
    );
    expect(create, findsNothing);

    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(
      container.read(periodContextProvider).startsAt,
      DateTime(current.year, current.month),
    );
    await tester.tap(find.byTooltip('Choose month'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(create);
    await tester.pumpAndSettle();
    final sheet = find.byType(CompositeBudgetSheet);
    expect(sheet, findsOneWidget);
    final fields = find.descendant(of: sheet, matching: find.byType(TextField));
    await tester.enterText(fields.at(0), 'Essentials');
    await tester.enterText(fields.at(1), '500');
    final save = find.widgetWithText(FilledButton, 'Save budget');
    expect(save.hitTestable(), findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final created = await db.select(db.budgetDefinitions).getSingle();
    expect(created.name, 'Essentials');
    expect(sheet, findsNothing);
    expect(create.hitTestable(), findsOneWidget);
    await tester.tap(find.text('Essentials'));
    await tester.pumpAndSettle();
    expect(find.byType(ImportedBudgetDetailScreen), findsOneWidget);
    expect(find.text('Essentials'), findsOneWidget);
  });

  group('BudgetCard', () {
    testWidgets('renders without overflow', (tester) async {
      final budget = Budget(
        id: 'b1',
        ownerUserId: 'usr-1',
        categoryId: 'cat-1',
        amount: 10000,
        month: 6,
        year: 2026,
        spent: 2500,
        createdAt: now,
        updatedAt: now,
      );
      final category = Category(
        id: 'cat-1',
        name: 'Dining Out',
        icon: 'utensils',
        color: '#FF5733',
        categoryGroup: 'expense',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: BudgetCard(budget: overview(budget), category: category),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dining Out'), findsOneWidget);
      expect(find.text('₱2,500.00'), findsOneWidget);
      expect(find.text('of ₱10,000.00'), findsOneWidget);
      expect(find.text('₱7,500.00 left'), findsOneWidget);
    });

    testWidgets('handles over-budget state', (tester) async {
      final budget = Budget(
        id: 'b1',
        ownerUserId: 'usr-1',
        categoryId: 'cat-1',
        amount: 5000,
        month: 6,
        year: 2026,
        spent: 6000,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: BudgetCard(budget: overview(budget), category: null),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Uncategorized'), findsOneWidget);
      expect(find.text('₱1,000.00 over'), findsOneWidget);
    });
  });

  group('MonthNavigator', () {
    testWidgets('renders compact mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: Center(child: MonthNavigator(compact: true))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MonthNavigator), findsOneWidget);
      expect(find.textContaining('2026'), findsOneWidget);
    });

    testWidgets('renders full mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: Center(child: MonthNavigator())),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MonthNavigator), findsOneWidget);
      expect(find.textContaining('2026'), findsOneWidget);
    });

    testWidgets('month picker dialog shows month grid', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: Center(child: MonthNavigator())),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('2026'));
      await tester.pumpAndSettle();

      expect(find.text('Select Month'), findsOneWidget);
      expect(find.text('Jan'), findsOneWidget);
      expect(find.text('June'), findsOneWidget);
      expect(find.text('Dec'), findsOneWidget);
    });

    testWidgets('picking a month closes dialog', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: Center(child: MonthNavigator())),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('2026'));
      await tester.pumpAndSettle();

      expect(find.text('Select Month'), findsOneWidget);
      await tester.tap(find.text('Jan'));
      await tester.pumpAndSettle();

      expect(find.text('Select Month'), findsNothing);
    });
  });
}

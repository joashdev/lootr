import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lootr/application/providers/dashboard_layout_provider.dart';
import 'package:lootr/application/providers/dashboard_provider.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/period_context_provider.dart';
import 'package:lootr/application/providers/sync_providers.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/entities/account.dart';
import 'package:lootr/domain/use_cases/calculate_safe_to_spend.dart';
import 'package:lootr/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:lootr/presentation/screens/dashboard/widgets/budget_progress_rings.dart';

void main() {
  testWidgets('renders loading affordance before dashboard data arrives', (
    tester,
  ) async {
    final controller = StreamController<DashboardData>();
    addTearDown(controller.close);

    await tester.pumpWidget(_wrapWithDashboardStream(controller.stream));
    await tester.pump();

    expect(find.text('Loading your dashboard...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('creates the first account directly from the empty dashboard', (
    tester,
  ) async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    await tester.pumpWidget(
      _wrapWithApp(
        DashboardData(
          greeting: 'Good morning',
          displayName: 'Joash',
          currentDate: DateTime(2026, 6, 21),
          currencyCode: 'PHP',
          safeToSpend: const SafeToSpendResult(
            amount: 0,
            basis: SafeToSpendBasis.liquidBalances,
            monthlyIncome: 0,
            spentThisMonth: 0,
            committedOutflows: 0,
            liquidBalance: 0,
          ),
          monthlyIncome: 0,
          monthlyExpense: 0,
          netWorth: 0,
          netWorthSeries: List<double>.filled(30, 0),
          netWorthChangePercent: 0,
          accounts: const [],
          budgets: const [],
          recentTransactions: const [],
          upcomingRecurring: const [],
          spendingByCategory: const [],
          insights: const [],
        ),
        database: db,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Lootr'), findsOneWidget);
    expect(find.text('Add your first account'), findsOneWidget);
    await tester.tap(find.text('Add your first account'));
    await tester.pumpAndSettle();
    expect(find.text('New Account'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Wallet');
    await tester.tap(find.text('Save Account'));
    await tester.pumpAndSettle();

    expect(find.text('New Account'), findsNothing);
    expect((await db.select(db.accounts).getSingle()).name, 'Wallet');
  });

  testWidgets('renders dashboard sections in order when data exists', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapWithApp(_sampleDashboardData()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text('SAFE TO SPEND'), findsOneWidget);
    expect(find.text('Net worth'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Income vs expense'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Income vs expense'), findsOneWidget);
    expect(find.text('Budgets'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Spending by category'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Spending by category'), findsOneWidget);
    expect(find.text('Recent transactions'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Upcoming recurring'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Upcoming recurring'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Insights'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Insights'), findsOneWidget);
  });

  testWidgets('safe-to-spend breakdown links truthful source components', (
    tester,
  ) async {
    final stream = Stream.value(_sampleDashboardData());
    final container = ProviderContainer(
      overrides: [
        dashboardProvider.overrideWith((ref) => stream),
        syncStatusIconProvider.overrideWith((ref) => SyncIconState.synced),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: _dashboardApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('View breakdown'));
    await tester.pumpAndSettle();

    final income = find.text('Income this month');
    final committed = find.text('Committed before month end');
    expect(
      find.ancestor(of: income, matching: find.byType(InkWell)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: committed, matching: find.byType(InkWell)),
      findsOneWidget,
    );

    await tester.tap(income);
    await tester.pumpAndSettle();

    expect(find.text('Transactions destination'), findsOneWidget);
    final query = container.read(activeLedgerQueryProvider);
    expect(query?.directions, const ['income']);
    expect(query?.period.startsAt, DateTime(2026, 6));
  });

  testWidgets('dashboard cards open their lists, reports and details', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapWithApp(_sampleDashboardData()));
    await tester.pumpAndSettle();

    final actions = <(Finder, String)>[
      (find.text('Net worth'), '/more/reports/net-worth'),
      (find.text('GCash'), '/more/accounts/acc-1'),
      (_action('See all accounts'), '/more/accounts'),
      (
        _action('View income and expense report'),
        '/more/reports/income-vs-expenses',
      ),
      (
        find.descendant(
          of: find.byType(BudgetProgressRings),
          matching: find.text('Dining Out'),
        ),
        '/budgets/bud-1',
      ),
      (_action('See all budgets'), '/budgets'),
      (
        _action('View spending by category report'),
        '/more/reports/spending-category',
      ),
      (find.text('McDo'), '/transactions/txn-1'),
      (_action('See all transactions'), '/transactions'),
      (find.text('Internet Bill'), '/more/recurring/rec-1'),
      (_action('See all recurring items'), '/more/recurring'),
    ];

    for (final (action, path) in actions) {
      final scrollable = find.byType(Scrollable).first;
      final router = GoRouter.of(tester.element(scrollable));
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(action, 180, scrollable: scrollable);
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(tester.element(action), alignment: 0.35);
      await tester.pumpAndSettle();
      expect(action.hitTestable(), findsOneWidget, reason: path);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(path)), findsOneWidget, reason: path);
      router.go('/');
      await tester.pumpAndSettle();
    }

    final hero = find.text('View breakdown');
    await tester.scrollUntilVisible(
      hero,
      -180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(hero);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Committed before month end'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('/more/recurring')), findsOneWidget);
  });

  testWidgets('customize can hide, reorder and restore dashboard modules', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapWithApp(_sampleDashboardData()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Customize'));
    await tester.pumpAndSettle();
    final settings = find.byType(ReorderableListView);
    final container = ProviderScope.containerOf(tester.element(settings));
    final netWorth = find.byKey(const ValueKey('netWorth'));

    await tester.tap(
      find.descendant(of: netWorth, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(dashboardLayoutProvider).visible,
      isNot(contains(DashboardModule.netWorth)),
    );

    final drag = await tester.startGesture(
      tester.getCenter(
        find.descendant(of: netWorth, matching: find.byIcon(Icons.drag_handle)),
      ),
    );
    await tester.pump();
    await drag.moveBy(const Offset(0, 20));
    await tester.pump();
    await drag.moveBy(const Offset(0, 65));
    await tester.pump(const Duration(milliseconds: 250));
    await drag.up();
    await tester.pumpAndSettle();
    expect(
      container.read(dashboardLayoutProvider).order.first,
      DashboardModule.accounts,
    );

    await tester.tap(find.text('Restore defaults'));
    await tester.pumpAndSettle();
    expect(
      container.read(dashboardLayoutProvider),
      DashboardLayoutState.defaults,
    );
  });

  testWidgets('dashboard fits a narrow screen with large text in dark mode', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _wrapWithApp(_sampleDashboardData(), theme: AppTheme.dark, textScale: 2),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Customize dashboard'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('View breakdown').hitTestable(),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View breakdown'));
    await tester.pumpAndSettle();
    expect(find.text('Safe-to-spend breakdown'), findsOneWidget);
    final navigator = Navigator.of(
      tester.element(find.text('Safe-to-spend breakdown')),
    );
    navigator.pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Insights'),
      225,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}

Finder _action(String label) => find.byWidgetPredicate(
  (widget) => widget is Text && widget.semanticsLabel == label,
);

Widget _wrapWithApp(
  DashboardData data, {
  ThemeData? theme,
  double textScale = 1,
  AppDatabase? database,
}) {
  return _wrapWithDashboardStream(
    Stream.value(data),
    theme: theme,
    textScale: textScale,
    database: database,
  );
}

Widget _wrapWithDashboardStream(
  Stream<DashboardData> stream, {
  ThemeData? theme,
  double textScale = 1,
  AppDatabase? database,
}) {
  return ProviderScope(
    overrides: [
      dashboardProvider.overrideWith((ref) => stream),
      syncStatusIconProvider.overrideWith((ref) => SyncIconState.synced),
      if (database != null) databaseProvider.overrideWithValue(database),
    ],
    child: _dashboardApp(theme: theme, textScale: textScale),
  );
}

Widget _dashboardApp({ThemeData? theme, double textScale = 1}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
      GoRoute(path: '/transactions/new', builder: (_, _) => const Scaffold()),
      GoRoute(
        path: '/transactions',
        builder: (_, _) => const Scaffold(
          key: ValueKey('/transactions'),
          body: Text('Transactions destination'),
        ),
      ),
      for (final path in [
        '/transactions/:id',
        '/budgets',
        '/budgets/:id',
        '/more/accounts',
        '/more/accounts/:id',
        '/more/recurring',
        '/more/recurring/:id',
        '/more/reports/:id',
        '/more/insights/:id',
      ])
        GoRoute(
          path: path,
          builder: (_, state) => Scaffold(key: ValueKey(state.uri.path)),
        ),
    ],
  );

  return MaterialApp.router(
    theme: theme ?? AppTheme.light,
    routerConfig: router,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
  );
}

DashboardData _sampleDashboardData() {
  final now = DateTime(2026, 6, 21);
  return DashboardData(
    greeting: 'Good afternoon',
    displayName: 'Joash',
    currentDate: now,
    currencyCode: 'PHP',
    safeToSpend: const SafeToSpendResult(
      amount: 12450,
      basis: SafeToSpendBasis.monthlyIncome,
      monthlyIncome: 50000,
      spentThisMonth: 37550,
      committedOutflows: 0,
      liquidBalance: 12450,
    ),
    monthlyIncome: 50000,
    monthlyExpense: 37550,
    netWorth: 24000,
    netWorthSeries: List<double>.generate(30, (index) => 20000 + (index * 150)),
    netWorthChangePercent: 3.2,
    accounts: [
      Account(
        id: 'acc-1',
        ownerUserId: 'usr-1',
        name: 'GCash',
        accountType: 'ewallet',
        balance: 12450,
        currencyCode: 'PHP',
        isArchived: false,
        isHidden: false,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    budgets: const [
      DashboardBudgetSummary(
        id: 'bud-1',
        name: 'Dining Out',
        icon: 'D',
        color: Colors.red,
        budgeted: 8000,
        spent: 2500,
      ),
    ],
    recentTransactions: [
      DashboardTransactionItem(
        id: 'txn-1',
        payeeName: 'McDo',
        accountName: 'GCash',
        categoryName: 'Dining Out',
        categoryIcon: 'utensils',
        categoryColor: '#FF0000',
        amount: 2500,
        direction: 'expense',
        occurredAt: now.subtract(const Duration(days: 1)),
      ),
    ],
    upcomingRecurring: [
      DashboardRecurringItem(
        id: 'rec-1',
        payeeName: 'Internet Bill',
        amount: 1699,
        nextOccurrenceAt: now.add(const Duration(days: 3)),
      ),
    ],
    spendingByCategory: const [
      DashboardSpendingSlice(
        categoryId: 'cat-1',
        name: 'Dining Out',
        color: Colors.red,
        amount: 2500,
        percentage: 0.4,
      ),
    ],
    insights: const [
      DashboardInsight(
        id: 'ins-1',
        title: 'Dining Out is leading this month',
        body: '40% of your spending is in dining out.',
      ),
    ],
  );
}

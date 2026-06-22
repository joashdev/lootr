import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lootr/application/providers/dashboard_provider.dart';
import 'package:lootr/application/providers/safe_to_spend_provider.dart';
import 'package:lootr/application/providers/sync_providers.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/domain/entities/account.dart';
import 'package:lootr/presentation/screens/dashboard/dashboard_screen.dart';

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

  testWidgets('renders empty state when there is no data', (tester) async {
    await tester.pumpWidget(
      _wrapWithApp(
        DashboardData(
          greeting: 'Good morning',
          displayName: 'Joash',
          currentDate: DateTime(2026, 6, 21),
          currencyCode: 'PHP',
          safeToSpend: 0,
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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Lootr'), findsOneWidget);
    expect(find.text('Add your first account'), findsOneWidget);
  });

  testWidgets('renders dashboard sections in order when data exists', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapWithApp(_sampleDashboardData()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text('Safe to spend'), findsOneWidget);
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
}

Widget _wrapWithApp(DashboardData data) {
  return _wrapWithDashboardStream(
    Stream.value(data),
    safeToSpend: data.safeToSpend,
  );
}

Widget _wrapWithDashboardStream(
  Stream<DashboardData> stream, {
  double safeToSpend = 0,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
      GoRoute(path: '/transactions/new', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/transactions/:id', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/budgets/:id', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/more/accounts/:id', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/more/recurring', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/more/recurring/:id', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/more/reports/:id', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/more/insights/:id', builder: (_, _) => const Scaffold()),
    ],
  );

  return ProviderScope(
    overrides: [
      dashboardProvider.overrideWith((ref) => stream),
      safeToSpendProvider.overrideWith((ref) => Stream.value(safeToSpend)),
      syncStatusIconProvider.overrideWith((ref) => SyncIconState.synced),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

DashboardData _sampleDashboardData() {
  final now = DateTime(2026, 6, 21);
  return DashboardData(
    greeting: 'Good afternoon',
    displayName: 'Joash',
    currentDate: now,
    currencyCode: 'PHP',
    safeToSpend: 12450,
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

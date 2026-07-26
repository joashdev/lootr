import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lootr/application/providers/dashboard_provider.dart';
import 'package:lootr/application/providers/period_context_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/domain/value_objects/ledger_query.dart';
import 'package:lootr/domain/value_objects/period_context.dart';
import 'package:lootr/presentation/screens/dashboard/widgets/insights_section.dart';

void main() {
  testWidgets('computed insight without a destination is visually static', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const InsightsSection(
          insights: [
            DashboardInsight(
              id: 'safe-to-spend',
              title: 'You still have room this month',
              body: '25% of this month\'s income is still safe to spend.',
            ),
          ],
        ),
      ),
    );

    final title = find.text('You still have room this month');
    expect(
      find.ancestor(of: title, matching: find.byType(InkWell)),
      findsNothing,
    );
  });

  testWidgets('category insight opens its exact structured ledger query', (
    tester,
  ) async {
    final period = PeriodContext.calendarMonth(DateTime(2026, 6, 21));
    final query = LedgerQuery(
      explanation: 'Dining Out expenses this month · PHP',
      period: period,
      directions: const ['expense'],
      categoryIds: const ['cat-1'],
      currencyCode: 'PHP',
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _wrap(
          InsightsSection(
            insights: [
              DashboardInsight(
                id: 'top-category',
                title: 'Dining Out is leading this month',
                body: '40% of your spending is in dining out.',
                ledgerQuery: query,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Dining Out is leading this month'));
    await tester.pumpAndSettle();

    expect(find.text('Ledger destination'), findsOneWidget);
    expect(container.read(activeLedgerQueryProvider), same(query));
  });

  testWidgets('budget insight opens the matching budget destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const InsightsSection(
          insights: [
            DashboardInsight(
              id: 'budget-watch',
              title: 'Dining Out is close to the limit',
              body: 'You have 80% of the dining out budget used.',
              destinationRoute: '/budgets/bud-1',
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Dining Out is close to the limit'));
    await tester.pumpAndSettle();

    expect(find.text('Budget destination'), findsOneWidget);
  });
}

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/transactions',
        builder: (_, _) => const Scaffold(body: Text('Ledger destination')),
      ),
      GoRoute(
        path: '/budgets/:id',
        builder: (_, _) => const Scaffold(body: Text('Budget destination')),
      ),
    ],
  );
  return MaterialApp.router(theme: AppTheme.light, routerConfig: router);
}

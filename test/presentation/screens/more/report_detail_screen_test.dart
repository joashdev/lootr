import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lootr/application/providers/period_context_provider.dart';
import 'package:lootr/application/providers/reports_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/presentation/screens/more/report_detail_screen.dart';
import 'package:lootr/presentation/shared/components/period_selector.dart';

void main() {
  testWidgets('category report drills into the canonical transaction route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const ReportDetailScreen(type: 'spending-category'),
        ),
        GoRoute(
          path: '/transactions',
          builder: (_, _) =>
              const Scaffold(body: Text('Canonical transactions')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          periodContextClockProvider.overrideWithValue(DateTime(2026, 6, 15)),
          categorySpendingReportProvider.overrideWith(
            (ref) => Stream.value(const [
              CategorySpendingReport(
                currencyCode: 'PHP',
                periodLabel: 'June 2026',
                total: 120,
                slices: [
                  ReportCategorySlice(
                    categoryId: 'food',
                    name: 'Food',
                    color: Colors.amber,
                    amount: 120,
                    percentage: 1,
                  ),
                ],
              ),
            ]),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PeriodSelector), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReportDetailScreen)),
    );

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    expect(find.text('Canonical transactions'), findsOneWidget);
    final query = container.read(activeLedgerQueryProvider);
    expect(query?.explanation, 'Food expenses in June 2026 · PHP');
    expect(query?.categoryIds, ['food']);
    expect(query?.directions, ['expense']);
    expect(query?.currencyCode, 'PHP');
  });
}

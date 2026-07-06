import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/domain/entities/budget.dart';
import 'package:lootr/domain/entities/category.dart';
import 'package:lootr/presentation/screens/budgets/widgets/budget_card.dart';
import 'package:lootr/presentation/screens/budgets/widgets/month_navigator.dart';

void main() {
  final now = DateTime(2026, 6, 21);

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
                child: BudgetCard(budget: budget, category: category),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dining Out'), findsOneWidget);
      expect(find.text('₱2,500'), findsOneWidget);
      expect(find.text('of ₱10,000'), findsOneWidget);
      expect(find.text('₱7,500 left'), findsOneWidget);
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
                child: BudgetCard(budget: budget, category: null),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Uncategorized'), findsOneWidget);
      expect(find.text('₱1,000 over'), findsOneWidget);
    });
  });

  group('MonthNavigator', () {
    testWidgets('renders compact mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Center(child: MonthNavigator(compact: true)),
            ),
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
            home: Scaffold(
              body: Center(child: MonthNavigator()),
            ),
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
            home: Scaffold(
              body: Center(child: MonthNavigator()),
            ),
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
            home: Scaffold(
              body: Center(child: MonthNavigator()),
            ),
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

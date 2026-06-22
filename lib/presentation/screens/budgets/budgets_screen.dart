import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/budgets_tab_provider.dart';
import '../../../application/providers/categories_provider.dart';
import '../../../core/extensions/async_value_x.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../sheets/budget_create_sheet.dart';
import 'widgets/budget_card.dart';
import 'widgets/budget_shimmer.dart';
import 'widgets/budget_summary_header.dart';
import 'widgets/month_navigator.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsTabProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final month = ref.watch(budgetMonthProvider);
    final year = ref.watch(budgetYearProvider);
    final isReadOnly = isPastBudgetPeriod(month, year);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: AppSpacing.pagePaddingMobile,
        title: Row(
          children: [
            Text('Budgets', style: Theme.of(context).textTheme.headlineMedium),
            const Spacer(),
            const MonthNavigator(compact: true),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isReadOnly ? 'Past months are read-only' : 'Create budget',
            icon: const Icon(LucideIcons.plus),
            onPressed: isReadOnly ? null : () => _showCreateSheet(context),
          ),
          const SizedBox(width: AppSpacing.space2),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: budgetsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.pagePaddingMobile),
                child: BudgetShimmer(),
              ),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.alertCircle,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    Text(
                      'Failed to load budgets',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    TextButton(
                      onPressed: () => ref.invalidate(budgetsTabProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (budgets) {
                if (budgets.isEmpty) {
                  return _EmptyBudgetsState(
                    month: month,
                    year: year,
                    onCreateBudget: isReadOnly
                        ? null
                        : () => _showCreateSheet(context),
                  );
                }

                final categories = categoriesAsync.valueOrNull ?? [];
                final categoryMap = {for (final c in categories) c.id: c};

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePaddingMobile,
                    AppSpacing.space2,
                    AppSpacing.pagePaddingMobile,
                    AppSpacing.pagePaddingMobile + 80,
                  ),
                  itemCount: budgets.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return const BudgetSummaryHeader();

                    final budget = budgets[index - 1];
                    final category = categoryMap[budget.categoryId];
                    return BudgetCard(
                      budget: budget,
                      category: category,
                      onTap: () => context.push('/budgets/${budget.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const BudgetCreateSheet(),
    );
  }
}

class _EmptyBudgetsState extends StatelessWidget {
  const _EmptyBudgetsState({
    required this.month,
    required this.year,
    required this.onCreateBudget,
  });

  final int month;
  final int year;
  final VoidCallback? onCreateBudget;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.pieChart,
              size: 64,
              color: lootrColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              'No budgets set for ${_monthNames[month - 1]} $year',
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              'Set spending limits to stay on track',
              style: TextStyle(fontSize: 15, color: lootrColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.space4),
            if (onCreateBudget == null)
              Text(
                'Past months are read-only',
                style: TextStyle(color: lootrColors.textTertiary),
              )
            else
              ElevatedButton(
                onPressed: onCreateBudget,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
                child: const Text(
                  'Create Budget',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/budgets_tab_provider.dart';
import '../../../application/providers/categories_provider.dart';
import '../../../application/providers/period_context_provider.dart';
import '../../../core/extensions/async_value_x.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../shared/components/buttons/primary_button.dart';
import '../../shared/components/period_selector.dart';
import '../../sheets/composite_budget_sheet.dart';
import 'widgets/budget_card.dart';
import 'widgets/budget_shimmer.dart';
import 'widgets/budget_summary_header.dart';

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
    final period = ref.watch(periodContextProvider);
    final month = period.startsAt.month;
    final year = period.startsAt.year;
    final isReadOnly = isPastBudgetPeriod(month, year);
    final hasBudgets = budgetsAsync.asData?.value.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 64,
        titleSpacing: AppSpacing.pagePaddingMobile,
        title: Text(
          'Budgets',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        actions: [
          if (hasBudgets)
            IconButton(
              tooltip: isReadOnly
                  ? 'Past months are read-only'
                  : 'Create budget',
              icon: const Icon(LucideIcons.plus),
              onPressed: isReadOnly ? null : () => _showCreateSheet(context),
            ),
          const SizedBox(width: AppSpacing.space2),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePaddingMobile,
              ),
              child: PeriodSelector(compact: true),
            ),
          ),
        ),
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
                      onTap: () => context.push(
                        budget.isComposite
                            ? '/budgets/imported/${budget.id}'
                                  '?year=$year&month=$month'
                            : '/budgets/${budget.id}',
                      ),
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
      builder: (_) => const CompositeBudgetSheet(),
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Icon(
                LucideIcons.pieChart,
                size: 64,
                color: lootrColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              'No budgets set for ${_monthNames[month - 1]} $year',
              style: AppTypography.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              'Set spending limits to stay on track',
              style: AppTypography.body.copyWith(
                color: lootrColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.space4),
            if (onCreateBudget == null)
              Text(
                'Past months are read-only',
                style: TextStyle(color: lootrColors.textTertiary),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 220),
                child: PrimaryButton(
                  label: 'Create Budget',
                  onPressed: onCreateBudget,
                  isExpanded: false,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

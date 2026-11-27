import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/budgets_tab_provider.dart';
import '../../../application/providers/categories_provider.dart';
import '../../../application/providers/period_context_provider.dart';
import '../../../core/extensions/async_value_x.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../shared/components/buttons/primary_button.dart';
import '../../shared/components/period_selector.dart';
import '../../shared/components/primary_screen_header.dart';
import '../../sheets/composite_budget_sheet.dart';
import 'widgets/budget_card.dart';
import 'widgets/budget_shimmer.dart';
import 'widgets/budget_summary_header.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsTabProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final period = ref.watch(periodContextProvider);
    final month = period.startsAt.month;
    final year = period.startsAt.year;
    final canCreate = !isPastBudgetPeriod(month, year);

    return Scaffold(
      appBar: PrimaryScreenHeader(
        title: 'Budgets',
        actions: [
          if (canCreate && budgetsAsync.hasValue)
            PrimaryButton(
              label: 'New budget',
              isExpanded: false,
              onPressed: () => _showCreateSheet(context),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.pageMaxWidth),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePaddingMobile,
                  vertical: AppSpacing.space2,
                ),
                child: Column(
                  children: [
                    const PeriodSelector(compact: true),
                    if (!canCreate)
                      Text(
                        'Choose a current or future period to add a budget.',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          color: context.lootrColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: budgetsAsync.when(
                  loading: () => const SingleChildScrollView(
                    padding: EdgeInsets.all(AppSpacing.pagePaddingMobile),
                    child: BudgetShimmer(),
                  ),
                  error: (error, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.alertCircle,
                          size: 48,
                          color: Theme.of(context).colorScheme.error,
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
                      return const _EmptyBudgetsState();
                    }

                    final categories = categoriesAsync.valueOrNull ?? [];
                    final categoryMap = {for (final c in categories) c.id: c};

                    return ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.pagePaddingMobile,
                        AppSpacing.space2,
                        AppSpacing.pagePaddingMobile,
                        AppSpacing.bottomNavClearance +
                            MediaQuery.paddingOf(context).bottom,
                      ),
                      itemCount: budgets.length + 1,
                      separatorBuilder: (_, index) => index == 0
                          ? const SizedBox(height: AppSpacing.space3)
                          : const Divider(indent: 52),
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
        ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => const CompositeBudgetSheet(),
    );
  }
}

class _EmptyBudgetsState extends StatelessWidget {
  const _EmptyBudgetsState();

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space4,
          AppSpacing.space4,
          AppSpacing.space4,
          AppSpacing.bottomNavClearance,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Icon(
                LucideIcons.chartPie,
                size: 28,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              'No budgets for this period',
              style: AppTypography.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              'Budgets track spending against a limit you set.',
              style: AppTypography.body.copyWith(
                color: lootrColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

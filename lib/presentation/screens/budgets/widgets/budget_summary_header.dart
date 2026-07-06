import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/budgets_tab_provider.dart';
import '../../../../core/format/money_format.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../shared/components/progress/budget_progress_bar.dart';

class BudgetSummaryHeader extends ConsumerWidget {
  const BudgetSummaryHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(budgetSummaryProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;

    final progress = summary.budgeted > 0
        ? (summary.spent / summary.budgeted).clamp(0.0, 1.5)
        : 0.0;
    final percent = summary.budgeted > 0
        ? (summary.spent / summary.budgeted * 100).round()
        : 0;

    Color progressColor() {
      if (progress >= 1.0) return lootrColors.danger;
      if (progress >= 0.8) return lootrColors.warning;
      return lootrColors.success;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingStandard),
      margin: const EdgeInsets.only(bottom: AppSpacing.space3),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: colorScheme.outline)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Summary',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: lootrColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${MoneyFormat.display(summary.spent, 'PHP')} of ${MoneyFormat.display(summary.budgeted, 'PHP')}',
                style: AppTypography.mono.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$percent%',
                style: AppTypography.mono.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: progressColor(),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          BudgetProgressBar(
            progress: progress.clamp(0.0, 1.0),
            color: progressColor(),
          ),
        ],
      ),
    );
  }
}

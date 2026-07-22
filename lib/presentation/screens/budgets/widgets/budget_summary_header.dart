import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/budget_projection.dart';
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
    final summaries = ref.watch(budgetSummaryProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;

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
            'Monthly Summary by currency',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: lootrColors.textSecondary,
            ),
          ),
          for (final summary in summaries) ...[
            const SizedBox(height: AppSpacing.space3),
            _CurrencySummary(summary: summary),
          ],
        ],
      ),
    );
  }
}

class _CurrencySummary extends StatelessWidget {
  const _CurrencySummary({required this.summary});

  final BudgetSummaryPartition summary;

  @override
  Widget build(BuildContext context) {
    final progress = summary.progress.clamp(0.0, 1.5);
    final lootrColors = context.lootrColors;
    final color = progress >= 1
        ? lootrColors.danger
        : progress >= 0.8
        ? lootrColors.warning
        : lootrColors.success;
    final symbol = MoneyFormat.symbolFor(summary.currencyCode);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '$symbol${summary.spent.toDecimalString()} of '
                '$symbol${summary.budgeted.toDecimalString()} '
                '${summary.currencyCode}',
                style: AppTypography.mono.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: AppTypography.mono.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space2),
        BudgetProgressBar(progress: progress.clamp(0.0, 1.0), color: color),
      ],
    );
  }
}

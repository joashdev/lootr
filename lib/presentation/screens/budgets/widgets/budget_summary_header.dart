import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/budget_projection.dart';
import '../../../../application/providers/budgets_tab_provider.dart';
import '../../../../core/format/money_format.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../shared/components/progress/budget_progress_bar.dart';

class BudgetSummaryHeader extends ConsumerWidget {
  const BudgetSummaryHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(budgetSummaryProvider);
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, summary) in summaries.indexed) ...[
              if (index > 0)
                Divider(
                  height: AppSpacing.space8,
                  color: colors.onPrimaryContainer.withValues(alpha: 0.22),
                ),
              _CurrencySummary(summary: summary),
            ],
          ],
        ),
      ),
    );
  }
}

class _CurrencySummary extends StatelessWidget {
  const _CurrencySummary({required this.summary});

  final BudgetSummaryPartition summary;

  @override
  Widget build(BuildContext context) {
    final progress = summary.progress;
    final percent = progress * 100;
    final remaining = summary.budgeted - summary.spent;
    final hasLimit = !summary.budgeted.isZero;
    final status = !hasLimit
        ? 'Spent with no limit'
        : remaining.isNegative
        ? 'Over budget limits'
        : 'Left in budgets';
    final amount = hasLimit ? remaining.abs() : summary.spent;
    final ink = Theme.of(context).colorScheme.onPrimaryContainer;
    final labelStyle = AppTypography.captionMedium.copyWith(color: ink);
    final lootrColors = context.lootrColors;
    final color = progress > 1
        ? lootrColors.danger
        : progress >= 0.8
        ? lootrColors.warning
        : lootrColors.success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: AppSpacing.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                header: true,
                child: Text(
                  status,
                  style: AppTypography.bodyMedium.copyWith(color: ink),
                ),
              ),
              Text(summary.currencyCode, style: labelStyle),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space1),
        Text(
          MoneyFormat.exactMoney(amount),
          style: AppTypography.displayMono.copyWith(color: ink),
        ),
        if (hasLimit) ...[
          const SizedBox(height: AppSpacing.space4),
          ExcludeSemantics(
            child: BudgetProgressBar(
              progress: progress.clamp(0.0, 1.0),
              color: color,
              trackColor: ink.withValues(alpha: 0.16),
              height: 6,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AppSpacing.space2,
              runSpacing: AppSpacing.space1,
              children: [
                Text(
                  '${MoneyFormat.exactMoney(summary.spent)} of '
                  '${MoneyFormat.exactMoney(summary.budgeted)} spent',
                  style: labelStyle,
                ),
                if (percent.isFinite)
                  Text('${percent.round()}% used', style: labelStyle),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

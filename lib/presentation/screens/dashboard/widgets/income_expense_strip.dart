import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../application/providers/dashboard_provider.dart';
import '../../../../core/format/money_format.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../shared/components/cards/standard_card.dart';
import 'dashboard_section_header.dart';

class IncomeExpenseStrip extends StatelessWidget {
  const IncomeExpenseStrip({super.key, required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final colors = context.lootrColors;
    final total = data.monthlyIncome + data.monthlyExpense;
    final incomeShare = total <= 0 ? 0.0 : data.monthlyIncome / total;
    final incomeFlex = (incomeShare * 1000).round().clamp(0, 1000);

    return StandardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardSectionHeader(
            title: 'Income vs expense',
            actionText: 'Report',
            actionLabel: 'View income and expense report',
            onPressed: () => context.push('/more/reports/income-vs-expenses'),
          ),
          const SizedBox(height: AppSpacing.space2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _FlowFigure(
                  label: 'Income',
                  value: MoneyFormat.display(
                    data.monthlyIncome,
                    data.currencyCode,
                  ),
                  color: colors.income,
                ),
              ),
              const SizedBox(width: AppSpacing.space4),
              Expanded(
                child: _FlowFigure(
                  label: 'Expenses',
                  value: MoneyFormat.display(
                    data.monthlyExpense,
                    data.currencyCode,
                  ),
                  color: colors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: SizedBox(
              height: 6,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (incomeFlex > 0)
                      Expanded(
                        flex: incomeFlex,
                        child: ColoredBox(color: colors.income),
                      ),
                    if (incomeFlex < 1000 && total > 0)
                      Expanded(
                        flex: 1000 - incomeFlex,
                        child: ColoredBox(color: colors.expense),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowFigure extends StatelessWidget {
  const _FlowFigure({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.captionMedium.copyWith(
            color: context.lootrColors.textSecondary,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            style: AppTypography.h3Mono.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

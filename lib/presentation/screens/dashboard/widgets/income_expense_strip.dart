import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../application/providers/dashboard_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../shared/components/cards/standard_card.dart';

class IncomeExpenseStrip extends StatelessWidget {
  const IncomeExpenseStrip({super.key, required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final total = data.monthlyIncome + data.monthlyExpense;
    final incomeShare = total == 0 ? 0.5 : data.monthlyIncome / total;
    final expenseShare = total == 0 ? 0.5 : data.monthlyExpense / total;
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_PH',
      symbol: '₱',
    );

    return StandardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Income vs expense', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.space2),
          Container(
            padding: const EdgeInsets.all(AppSpacing.space1),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: (incomeShare * 1000).round().clamp(1, 1000),
                      child: Container(color: context.lootrColors.income),
                    ),
                    Expanded(
                      flex: (expenseShare * 1000).round().clamp(1, 1000),
                      child: Container(color: context.lootrColors.expense),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: currencyFormatter.format(data.monthlyIncome),
                  style: AppTypography.bodyMedium.copyWith(
                    color: context.lootrColors.income,
                  ),
                ),
                TextSpan(
                  text: ' income',
                  style: AppTypography.body.copyWith(
                    color: context.lootrColors.textSecondary,
                  ),
                ),
                TextSpan(
                  text: '  ·  ',
                  style: AppTypography.body.copyWith(
                    color: context.lootrColors.textTertiary,
                  ),
                ),
                TextSpan(
                  text: currencyFormatter.format(data.monthlyExpense),
                  style: AppTypography.bodyMedium.copyWith(
                    color: context.lootrColors.expense,
                  ),
                ),
                TextSpan(
                  text: ' expenses',
                  style: AppTypography.body.copyWith(
                    color: context.lootrColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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

    return StandardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Income vs expense', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.space3),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: SizedBox(
              height: 12,
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
          const SizedBox(height: AppSpacing.space3),
          Text(
            '${NumberFormat.currency(locale: 'en_PH', symbol: '₱').format(data.monthlyIncome)} income · ${NumberFormat.currency(locale: 'en_PH', symbol: '₱').format(data.monthlyExpense)} expenses',
            style: AppTypography.body.copyWith(
              color: context.lootrColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

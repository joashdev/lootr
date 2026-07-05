import 'package:flutter/material.dart';
import '../../../../core/format/money_format.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../domain/entities/budget.dart';
import '../../../../domain/entities/category.dart';
import '../../../shared/category_visuals.dart';
import '../../../shared/components/progress/budget_progress_bar.dart';

class BudgetCard extends StatelessWidget {
  const BudgetCard({
    super.key,
    required this.budget,
    required this.category,
    this.onTap,
  });

  final Budget budget;
  final Category? category;
  final VoidCallback? onTap;

  Color _progressColor(BuildContext context) {
    if (budget.amount <= 0) return context.lootrColors.success;
    final ratio = budget.spent / budget.amount;
    if (ratio >= 1.0) return context.lootrColors.danger;
    if (ratio >= 0.8) return context.lootrColors.warning;
    return context.lootrColors.success;
  }

  String _statusLabel() {
    if (budget.amount <= 0) return 'No budget set';
    final remaining = budget.amount - budget.spent;
    if (remaining >= 0) {
      return '${MoneyFormat.display(remaining, 'PHP')} left';
    }
    return '${MoneyFormat.display(-remaining, 'PHP')} over';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;
    final progress = budget.amount > 0
        ? (budget.spent / budget.amount).clamp(0.0, 1.5)
        : 0.0;

    final iconValue = resolveBudgetIconValue(budget, category);
    final budgetColor = resolveBudgetColor(budget, category);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.cardPaddingStandard),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Theme.of(context).brightness == Brightness.dark
                    ? Border.all(color: colorScheme.outline)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: budgetColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: buildCategoryVisual(
                            iconValue,
                            color: budgetColor,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space3),
                      Expanded(
                        child: Text(
                          category?.name ?? 'Uncategorized',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            MoneyFormat.display(budget.spent, 'PHP'),
                            style: AppTypography.mono.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: _progressColor(context),
                            ),
                          ),
                          Text(
                            'of ${MoneyFormat.display(budget.amount, 'PHP')}',
                            style: AppTypography.mono.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: lootrColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  BudgetProgressBar(
                    progress: progress.clamp(0.0, 1.0),
                    color: _progressColor(context),
                  ),
                  const SizedBox(height: AppSpacing.space1),
                  Text(
                    _statusLabel(),
                    style: AppTypography.mono.copyWith(
                      fontSize: 13,
                      color: _progressColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

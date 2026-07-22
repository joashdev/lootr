import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../application/providers/budget_projection.dart';
import '../../../../core/format/money_format.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../domain/entities/category.dart';
import '../../../../domain/value_objects/exact_money.dart';
import '../../../shared/category_visuals.dart';
import '../../../shared/components/progress/budget_progress_bar.dart';

class BudgetCard extends StatelessWidget {
  const BudgetCard({
    super.key,
    required this.budget,
    required this.category,
    this.onTap,
  });

  final BudgetOverview budget;
  final Category? category;
  final VoidCallback? onTap;

  Color _progressColor(BuildContext context) {
    if (budget.budgeted.isZero) return context.lootrColors.success;
    final ratio = budget.progress;
    if (ratio >= 1.0) return context.lootrColors.danger;
    if (ratio >= 0.8) return context.lootrColors.warning;
    return context.lootrColors.success;
  }

  String _statusLabel() {
    if (budget.budgeted.isZero) return 'No budget set';
    final remaining = budget.remaining;
    if (!remaining.isNegative) {
      return '${_exact(remaining)} left';
    }
    return '${_exact(remaining.abs())} over';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;
    final progress = !budget.budgeted.isZero
        ? budget.progress.clamp(0.0, 1.5)
        : 0.0;

    final legacy = budget.legacyBudget;
    final iconValue = legacy == null
        ? null
        : resolveBudgetIconValue(legacy, category);
    final budgetColor = legacy == null
        ? colorScheme.primary
        : resolveBudgetColor(legacy, category);

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
                          child: iconValue == null
                              ? Icon(
                                  LucideIcons.layers3,
                                  color: budgetColor,
                                  size: 18,
                                )
                              : buildCategoryVisual(
                                  iconValue,
                                  color: budgetColor,
                                  size: 18,
                                ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              budget.isImported
                                  ? budget.name
                                  : category?.name ?? 'Uncategorized',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                            if (budget.isImported)
                              Text(
                                budget.needsReview
                                    ? 'Imported · Needs review'
                                    : 'Imported · Read-only',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: budget.needsReview
                                      ? lootrColors.warning
                                      : lootrColors.textTertiary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _exact(budget.spent),
                            style: AppTypography.mono.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: _progressColor(context),
                            ),
                          ),
                          Text(
                            'of ${_exact(budget.budgeted)}',
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

  static String _exact(ExactMoney money) => MoneyFormat.exactMoney(money);
}

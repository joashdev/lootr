import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../application/providers/budget_projection.dart';
import '../../../../core/format/money_format.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
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

  final BudgetOverview budget;
  final Category? category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;
    final legacy = budget.legacyBudget;
    final iconValue = legacy == null
        ? null
        : resolveBudgetIconValue(legacy, category);
    final categoryColor = legacy == null
        ? colors.primary
        : resolveBudgetColor(legacy, category);
    final progress = budget.progress;
    final progressColor = progress > 1
        ? lootrColors.danger
        : progress >= 0.8
        ? lootrColors.warning
        : lootrColors.success;
    final remaining = budget.remaining;
    final status = budget.budgeted.isZero
        ? 'No budget set'
        : '${MoneyFormat.exactMoney(remaining.abs())} '
              '${remaining.isNegative ? 'over' : 'left'}';
    final supportingStyle = AppTypography.caption.copyWith(
      color: lootrColors.textSecondary,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.space3,
            horizontal: AppSpacing.space1,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: iconValue == null
                      ? Icon(
                          LucideIcons.layers3,
                          color: categoryColor,
                          size: 18,
                        )
                      : buildCategoryVisual(
                          iconValue,
                          color: categoryColor,
                          size: 18,
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.space2,
                        children: [
                          Text(
                            budget.isComposite || budget.isImported
                                ? budget.name
                                : category?.name ?? 'Uncategorized',
                            style: AppTypography.h3,
                          ),
                          Text(status, style: AppTypography.captionMedium),
                        ],
                      ),
                    ),
                    if (budget.isImported)
                      Text(
                        budget.needsReview
                            ? 'Imported · Needs review'
                            : 'Imported · Read-only',
                        style: supportingStyle,
                      ),
                    const SizedBox(height: AppSpacing.space1),
                    BudgetProgressBar(
                      progress: progress.clamp(0.0, 1.0),
                      color: progressColor,
                      trackColor: colors.outline.withValues(alpha: 0.6),
                      height: 4,
                    ),
                    const SizedBox(height: AppSpacing.space1),
                    Wrap(
                      spacing: AppSpacing.space1,
                      children: [
                        Text(
                          MoneyFormat.exactMoney(budget.spent),
                          style: supportingStyle,
                        ),
                        Text(
                          'of ${MoneyFormat.exactMoney(budget.budgeted)}',
                          style: supportingStyle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.space2),
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: lootrColors.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

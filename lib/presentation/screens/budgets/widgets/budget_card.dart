import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../domain/entities/budget.dart';
import '../../../../domain/entities/category.dart';
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
    if (remaining >= 0) return 'P${remaining.toStringAsFixed(0)} left';
    return 'P${(-remaining).toStringAsFixed(0)} over';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;
    final progress = budget.amount > 0 ? (budget.spent / budget.amount).clamp(0.0, 1.5) : 0.0;

    final iconName = category?.icon ?? 'shopping-bag';
    final iconData = _iconForName(iconName);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space2),
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
                        color: _parseCategoryColor(category?.color)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(iconData, size: 18, color: _progressColor(context)),
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
                          'P${budget.spent.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: _progressColor(context),
                          ),
                        ),
                        Text(
                          'of P${budget.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
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
                  style: TextStyle(
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
    );
  }

  Color _parseCategoryColor(String? hexColor) {
    if (hexColor == null) return AppColors.primary600;
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.primary600;
    }
  }
}

IconData _iconForName(String name) {
  switch (name) {
    case 'home': return LucideIcons.home;
    case 'car': return LucideIcons.car;
    case 'utensils': return LucideIcons.utensils;
    case 'shopping-cart': return LucideIcons.shoppingCart;
    case 'shopping-bag': return LucideIcons.shoppingBag;
    case 'film': return LucideIcons.film;
    case 'tv': return LucideIcons.tv;
    case 'phone': return LucideIcons.phone;
    case 'heart': return LucideIcons.heart;
    case 'gift': return LucideIcons.gift;
    case 'wifi': return LucideIcons.wifi;
    case 'book': return LucideIcons.book;
    case 'music': return LucideIcons.music;
    case 'camera': return LucideIcons.camera;
    case 'briefcase': return LucideIcons.briefcase;
    case 'credit-card': return LucideIcons.creditCard;
    case 'dollar-sign': return LucideIcons.dollarSign;
    case 'trending-up': return LucideIcons.trendingUp;
    case 'trending-down': return LucideIcons.trendingDown;
    case 'zap': return LucideIcons.zap;
    case 'coffee': return LucideIcons.coffee;
    case 'smartphone': return LucideIcons.smartphone;
    default: return LucideIcons.shoppingBag;
  }
}

import 'package:flutter/material.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/format/money_format.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/shadows.dart';
import '../../../../core/theme/typography.dart';

class TransactionRow extends StatelessWidget {
  const TransactionRow({
    super.key,
    required this.payee,
    required this.amount,
    this.category,
    this.time,
    this.direction = TransactionDirection.expense,
    this.onTap,
  });

  final String payee;
  final double amount;
  final String? category;
  final String? time;
  final TransactionDirection direction;
  final VoidCallback? onTap;

  Color _directionColor(BuildContext context) {
    final colors = Theme.of(context).extension<LootrColorScheme>()!;
    switch (direction) {
      case TransactionDirection.expense:
        return colors.expense;
      case TransactionDirection.income:
        return colors.income;
      case TransactionDirection.transfer:
        return colors.transfer;
    }
  }

  String _amountPrefix() {
    switch (direction) {
      case TransactionDirection.expense:
        return '-';
      case TransactionDirection.income:
        return '+';
      case TransactionDirection.transfer:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final directionColor = _directionColor(context);
    final initials = payee.isNotEmpty ? payee[0].toUpperCase() : '?';

    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: isDark ? AppShadows.none : AppShadows.sm,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: AppTypography.captionMedium.copyWith(
                color: lootrColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payee,
                  style: AppTypography.h3.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                if (category != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    category!,
                    style: AppTypography.caption.copyWith(
                      color: lootrColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_amountPrefix()}${MoneyFormat.exact(amount, 'PHP')}',
                style: AppTypography.h3.copyWith(color: directionColor),
              ),
              if (time != null) ...[
                const SizedBox(height: 2),
                Text(
                  time!,
                  style: AppTypography.caption.copyWith(
                    color: lootrColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: row,
        ),
      );
    }

    return row;
  }
}

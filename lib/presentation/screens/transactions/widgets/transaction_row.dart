import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/format/money_format.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../domain/entities/transaction.dart';

class TransactionRowWidget extends StatelessWidget {
  const TransactionRowWidget({
    super.key,
    required this.transaction,
    this.categoryName,
    this.payeeName,
    required this.accountName,
    this.leading,
    this.onTap,
    this.showDate = false,
  });

  final Transaction transaction;
  final String? categoryName;
  final String? payeeName;
  final String accountName;
  final Widget? leading;
  final VoidCallback? onTap;

  /// When true, the trailing block prefixes the time with a short `MM/dd` date
  /// (e.g. "05/26 · 4:42 PM"). Defaults to false so date-grouped lists stay
  /// unchanged.
  final bool showDate;

  Color _directionColor(BuildContext context) {
    final lotrColors = context.lootrColors;
    switch (transaction.direction) {
      case 'expense':
        return lotrColors.expense;
      case 'income':
        return lotrColors.income;
      case 'transfer':
        return lotrColors.transfer;
      default:
        return lotrColors.expense;
    }
  }

  String _amountPrefix() {
    switch (transaction.direction) {
      case 'expense':
        return '-';
      case 'income':
        return '+';
      case 'transfer':
        return '';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lotrColors = context.lootrColors;
    final directionColor = _directionColor(context);
    final initials = accountName.isNotEmpty
        ? accountName[0].toUpperCase()
        : '?';
    final time = showDate
        ? '${DateFormat('MM/dd').format(transaction.occurredAt)} · '
              '${DateFormat('h:mm a').format(transaction.occurredAt)}'
        : DateFormat('h:mm a').format(transaction.occurredAt);

    final parts = <String>[];
    if (categoryName != null) parts.add(categoryName!);
    parts.add(accountName);
    final categoryLabel = parts.join(' \u00b7 ');
    final preservedTitle = transaction.title?.trim();
    final title = transaction.direction == 'transfer'
        ? payeeName == null
              ? 'Transfer'
              : 'Transfer to $payeeName'
        : payeeName ??
              (preservedTitle?.isNotEmpty == true ? preservedTitle : null) ??
              transaction.note ??
              accountName;

    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          leading ??
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: AppTypography.captionMedium.copyWith(
                    color: lotrColors.textSecondary,
                  ),
                ),
              ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.h3.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  categoryLabel,
                  style: AppTypography.caption.copyWith(
                    color: lotrColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_amountPrefix()}${MoneyFormat.exactMoney(transaction.exactAmount)}',
                style: AppTypography.h3Mono.copyWith(color: directionColor),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: AppTypography.caption.copyWith(
                  color: lotrColors.textTertiary,
                ),
              ),
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

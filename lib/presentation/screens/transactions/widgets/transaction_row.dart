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
    this.onLongPress,
    this.isSelected = false,
    this.showSelectionIndicator = false,
    this.showDate = false,
    this.grouped = false,
  });

  final Transaction transaction;
  final String? categoryName;
  final String? payeeName;
  final String accountName;
  final Widget? leading;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool showSelectionIndicator;

  /// When true, the trailing block prefixes the time with a short `MM/dd` date
  /// (e.g. "05/26 · 4:42 PM"). Defaults to false so date-grouped lists stay
  /// unchanged.
  final bool showDate;
  final bool grouped;

  Color _directionColor(BuildContext context) {
    final lootrColors = context.lootrColors;
    switch (transaction.direction) {
      case 'expense':
        return lootrColors.expense;
      case 'income':
        return lootrColors.income;
      case 'transfer':
        return lootrColors.transfer;
      default:
        return lootrColors.expense;
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
    final lootrColors = context.lootrColors;
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
    final amount =
        '${_amountPrefix()}${MoneyFormat.exactMoney(transaction.exactAmount)}';
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.h3.copyWith(
            color: colorScheme.onSurface,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          categoryLabel,
          style: AppTypography.caption.copyWith(
            color: lootrColors.textSecondary,
            height: 1.35,
          ),
        ),
      ],
    );

    final amountStyle = AppTypography.h3Mono.copyWith(
      color: directionColor,
      fontSize: grouped ? 15 : null,
      height: 1.25,
    );
    final amountLabel = Text(amount, style: amountStyle);
    final timeLabel = Text(
      time,
      style: AppTypography.caption.copyWith(
        color: lootrColors.textSecondary,
        height: 1.35,
      ),
    );
    final shape = grouped
        ? BorderRadius.zero
        : BorderRadius.circular(AppRadius.md);

    return Semantics(
      selected: isSelected,
      button: onTap != null,
      child: Material(
        color: isSelected ? colorScheme.primaryContainer : colorScheme.surface,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: AppSpacing.space3,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showSelectionIndicator)
                  SizedBox.square(
                    dimension: 36,
                    child: Icon(
                      isSelected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: isSelected
                          ? colorScheme.primary
                          : lootrColors.textSecondary,
                      size: 22,
                    ),
                  )
                else
                  leading ??
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
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
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final textScaler = MediaQuery.textScalerOf(context);
                      final amountPainter = TextPainter(
                        text: TextSpan(text: amount, style: amountStyle),
                        textDirection: Directionality.of(context),
                        textScaler: textScaler,
                        maxLines: 1,
                      )..layout();
                      // Leave enough room for a name before splitting the row.
                      final titleMinWidth = textScaler.scale(17) * 7.5;
                      final amountMaxWidth =
                          constraints.maxWidth -
                          titleMinWidth -
                          AppSpacing.space3;
                      final stackAmount = amountPainter.width > amountMaxWidth;
                      amountPainter.dispose();

                      if (stackAmount) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleBlock,
                            const SizedBox(height: AppSpacing.space2),
                            Wrap(
                              spacing: AppSpacing.space3,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [amountLabel, timeLabel],
                            ),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: titleBlock),
                          const SizedBox(width: AppSpacing.space3),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: amountMaxWidth,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                amountLabel,
                                const SizedBox(height: 2),
                                timeLabel,
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

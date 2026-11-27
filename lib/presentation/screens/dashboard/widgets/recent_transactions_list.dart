import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../application/providers/dashboard_provider.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/format/money_format.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../shared/category_visuals.dart';
import '../../../shared/components/cards/standard_card.dart';
import 'dashboard_section_header.dart';

class RecentTransactionsList extends StatelessWidget {
  const RecentTransactionsList({super.key, required this.transactions});

  final List<DashboardTransactionItem> transactions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return StandardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardSectionHeader(
            title: 'Recent transactions',
            actionLabel: 'See all transactions',
            onPressed: () => context.go('/transactions'),
          ),
          const SizedBox(height: AppSpacing.space2),
          if (transactions.isEmpty)
            Text(
              'No transactions yet.',
              style: AppTypography.body.copyWith(
                color: context.lootrColors.textSecondary,
              ),
            ),
          for (var index = 0; index < transactions.length; index++) ...[
            _TransactionRow(txn: transactions[index]),
            if (index != transactions.length - 1)
              Divider(color: colorScheme.outlineVariant, height: 1),
          ],
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.txn});

  final DashboardTransactionItem txn;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    final direction = txn.direction == 'income'
        ? TransactionDirection.income
        : txn.direction == 'transfer'
        ? TransactionDirection.transfer
        : TransactionDirection.expense;

    final directionColor = direction == TransactionDirection.income
        ? lootrColors.income
        : direction == TransactionDirection.transfer
        ? lootrColors.transfer
        : lootrColors.expense;
    final prefix = direction == TransactionDirection.income
        ? '+'
        : direction == TransactionDirection.transfer
        ? ''
        : '-';
    final time = DateFormat('MMM d').format(txn.occurredAt);
    final categoryColor = parseCategoryColor(txn.categoryColor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/transactions/${txn.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: buildCategoryVisual(
                    txn.categoryIcon,
                    color: categoryColor,
                    size: 18,
                    categoryName: txn.categoryName,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn.payeeName,
                      style: AppTypography.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${txn.categoryName} \u00b7 ${txn.accountName}',
                      style: AppTypography.caption.copyWith(
                        color: lootrColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$prefix${MoneyFormat.exact(txn.amount, txn.currencyCode)}',
                      textAlign: TextAlign.end,
                      style: AppTypography.mono.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: directionColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      textAlign: TextAlign.end,
                      style: AppTypography.captionMedium.copyWith(
                        color: lootrColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

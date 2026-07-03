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

class RecentTransactionsList extends StatelessWidget {
  const RecentTransactionsList({
    super.key,
    required this.transactions,
    required this.currencyCode,
  });

  final List<DashboardTransactionItem> transactions;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return StandardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Recent transactions', style: AppTypography.h2),
              ),
              TextButton(
                onPressed: () => context.go('/transactions'),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          for (var index = 0; index < transactions.length; index++) ...[
            _TransactionRow(
              txn: transactions[index],
              currencyCode: currencyCode,
            ),
            if (index != transactions.length - 1)
              Divider(
                color: colorScheme.outlineVariant,
                height: AppSpacing.space4,
              ),
          ],
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.txn, required this.currencyCode});

  final DashboardTransactionItem txn;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final lotrColors = context.lootrColors;
    final direction = txn.direction == 'income'
        ? TransactionDirection.income
        : txn.direction == 'transfer'
        ? TransactionDirection.transfer
        : TransactionDirection.expense;

    final directionColor = direction == TransactionDirection.income
        ? lotrColors.income
        : direction == TransactionDirection.transfer
        ? lotrColors.transfer
        : lotrColors.expense;
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
                    txn.categoryIcon ?? 'shopping-bag',
                    color: categoryColor,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                        color: lotrColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$prefix${MoneyFormat.exact(txn.amount, currencyCode)}',
                    style: AppTypography.mono.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: directionColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: AppTypography.captionMedium.copyWith(
                      color: lotrColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

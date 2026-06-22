import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../application/providers/dashboard_provider.dart';
import '../../../../core/constants/enums.dart';
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

  Color _directionColor(BuildContext context, String direction) {
    final lotrColors = context.lootrColors;
    switch (direction) {
      case 'income':
        return lotrColors.income;
      case 'transfer':
        return lotrColors.transfer;
      default:
        return lotrColors.expense;
    }
  }

  String _amountPrefix(String direction) {
    switch (direction) {
      case 'income':
        return '+';
      case 'transfer':
        return '';
      default:
        return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
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
          for (final txn in transactions)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space2),
              child: _TransactionCard(txn: txn),
            ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.txn});

  final DashboardTransactionItem txn;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
    final time = DateFormat('dd/MM/yyyy').format(txn.occurredAt);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/transactions/${txn.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
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
                  color: parseCategoryColor(txn.categoryColor)
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: buildCategoryVisual(
                    txn.categoryIcon ?? 'shopping-bag',
                    color: directionColor,
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
                      style: AppTypography.h3.copyWith(
                        color: colorScheme.onSurface,
                      ),
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
                    '$prefix${NumberFormat("#,##0.00").format(txn.amount)}',
                    style: AppTypography.h3.copyWith(color: directionColor),
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
        ),
      ),
    );
  }
}

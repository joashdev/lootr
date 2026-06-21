import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../application/providers/dashboard_provider.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../shared/components/badges/transaction_row.dart';
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
              child: TransactionRow(
                payee: txn.payeeName,
                amount: txn.amount,
                category: '${txn.categoryName} · ${txn.accountName}',
                time: DateFormat('MMM d').format(txn.occurredAt),
                direction: _directionFrom(txn.direction),
                onTap: () => context.push('/transactions/${txn.id}'),
              ),
            ),
        ],
      ),
    );
  }

  TransactionDirection _directionFrom(String direction) {
    switch (direction) {
      case 'income':
        return TransactionDirection.income;
      case 'transfer':
        return TransactionDirection.transfer;
      default:
        return TransactionDirection.expense;
    }
  }
}

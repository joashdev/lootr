import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/payee_detail_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../shared/components/empty_state.dart';

class PayeeDetailScreen extends ConsumerWidget {
  const PayeeDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(payeeDetailProvider(id));

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Payee')),
      body: detailAsync.when(
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Payee not found'));
          }
          final payee = detail.payee;
          final transactions = detail.transactions;
          if (transactions.isEmpty) {
            return EmptyState(
              headline: payee.displayName ?? payee.normalizedName,
              subtext: 'Transactions for this payee will appear here.',
              ctaLabel: 'Add Transaction',
              onCtaPressed: () => context.push('/transactions/new'),
            );
          }

          final lootrColors = context.lootrColors;
          return ListView.separated(
            padding: const EdgeInsets.only(
              top: AppSpacing.space2,
              bottom: AppSpacing.space8,
            ),
            itemCount: transactions.length + 1,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              indent: AppSpacing.pagePaddingMobile,
              color: lootrColors.borderSubtle,
            ),
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  title: Text(
                    payee.displayName ?? payee.normalizedName,
                    style: AppTypography.h3,
                  ),
                  subtitle: Text('${transactions.length} transactions'),
                );
              }
              final transaction = transactions[index - 1];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePaddingMobile,
                ),
                title: Text(transaction.note ?? 'Transaction'),
                subtitle: Text(
                  '${transaction.occurredAt.month}/${transaction.occurredAt.day}/${transaction.occurredAt.year}',
                ),
                trailing: Text(
                  '₱${transaction.amount.toStringAsFixed(2)}',
                  style: AppTypography.mono,
                ),
                onTap: () => context.push('/transactions/${transaction.id}'),
              );
            },
          );
        },
        error: (err, _) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

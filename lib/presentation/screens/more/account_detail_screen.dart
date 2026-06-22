import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/account_detail_provider.dart';
import '../../../application/providers/repo_providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/value_objects/field_types.dart';
import '../../shared/components/app_snackbar.dart';
import '../../shared/components/empty_state.dart';
import 'more_form_sheets.dart';

class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(accountDetailProvider(id));
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Account'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.pencil),
            onPressed: detailAsync.value == null
                ? null
                : () => showAccountSheet(
                    context,
                    ref,
                    initial: detailAsync.value!.account,
                  ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.archive),
            onPressed: detailAsync.value == null
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Archive account?'),
                        content: const Text(
                          'Archived accounts are hidden from the main list but remain in history.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            child: const Text('Archive'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    await ref
                        .read(accountRepoProvider)
                        .archive(detailAsync.value!.account.id);
                    if (!context.mounted) return;
                    AppSnackBar.show(context, 'Account archived.');
                    context.pop();
                  },
          ),
        ],
      ),
      body: detailAsync.when(
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Account not found'));
          }
          final account = detail.account;
          final transactions = detail.transactions;
          final isCreditOrLoan =
              account.accountType == AccountType.creditCard ||
              account.accountType == AccountType.loan ||
              account.accountType == AccountType.bnpl;

          final balanceColor = isCreditOrLoan && account.balance != 0
              ? account.balance < 0
                    ? lootrColors.danger
                    : lootrColors.success
              : account.balance < 0
              ? lootrColors.danger
              : null;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.pagePaddingMobile),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: AppTypography.h1.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space1),
                      Text(
                        AccountDetailScreen._typeLabel(account.accountType),
                        style: AppTypography.captionMedium.copyWith(
                          color: lootrColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space4),
                      Text(
                        '${account.balance < 0 ? '-' : ''}₱${account.balance.abs().toStringAsFixed(2)}',
                        style: AppTypography.display.copyWith(
                          color: balanceColor ?? colorScheme.onSurface,
                        ),
                      ),
                      if (isCreditOrLoan)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.space1,
                          ),
                          child: Text(
                            account.balance < 0
                                ? 'Outstanding balance'
                                : 'Available credit',
                            style: AppTypography.caption.copyWith(
                              color: lootrColors.textTertiary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  color: colorScheme.surfaceContainerLow,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePaddingMobile,
                    AppSpacing.space3,
                    AppSpacing.pagePaddingMobile,
                    AppSpacing.space1,
                  ),
                  child: Text(
                    'Transactions',
                    style: AppTypography.captionMedium.copyWith(
                      color: lootrColors.textSecondary,
                    ),
                  ),
                ),
              ),
              if (transactions.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    headline: 'No transactions',
                    subtext: 'Transactions for this account will appear here.',
                    ctaLabel: 'Add Transaction',
                    onCtaPressed: () => context.push('/transactions/new'),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final tx = transactions[index];
                    return _TransactionRow(transaction: tx);
                  }, childCount: transactions.length),
                ),
            ],
          );
        },
        error: (err, _) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  static String _typeLabel(String type) {
    switch (type) {
      case AccountType.cash:
        return 'Cash';
      case AccountType.bank:
        return 'Bank Account';
      case AccountType.ewallet:
        return 'E-Wallet';
      case AccountType.savings:
        return 'Savings';
      case AccountType.investment:
        return 'Investment';
      case AccountType.crypto:
        return 'Crypto';
      case AccountType.creditCard:
        return 'Credit Card';
      case AccountType.loan:
        return 'Loan';
      case AccountType.bnpl:
        return 'BNPL';
      default:
        return type;
    }
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;
    final isExpense = transaction.direction == TransactionDirection.expense;
    final isIncome = transaction.direction == TransactionDirection.income;

    final amountColor = isExpense
        ? lootrColors.expense
        : isIncome
        ? lootrColors.income
        : lootrColors.transfer;

    final prefix = isExpense
        ? '-'
        : isIncome
        ? '+'
        : '';
    final dateFmt = DateFormat('MMM d');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingMobile,
      ),
      title: Text(
        transaction.note ?? transaction.categoryId ?? 'Transaction',
        style: AppTypography.bodyMedium.copyWith(color: colorScheme.onSurface),
      ),
      subtitle: Text(
        dateFmt.format(transaction.occurredAt),
        style: AppTypography.caption.copyWith(color: lootrColors.textSecondary),
      ),
      trailing: Text(
        '$prefix₱${transaction.amount.toStringAsFixed(2)}',
        style: AppTypography.mono.copyWith(color: amountColor),
      ),
      onTap: () => context.push('/transactions/${transaction.id}'),
    );
  }
}

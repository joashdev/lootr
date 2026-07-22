import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/account_detail_provider.dart';
import '../../../application/providers/categories_provider.dart';
import '../../../application/providers/payees_provider.dart';
import '../../../application/providers/repo_providers.dart';
import '../../../core/format/money_format.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/entities/payee.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/value_objects/field_types.dart';
import '../../shared/category_visuals.dart';
import '../../shared/components/app_snackbar.dart';
import '../../shared/components/empty_state.dart';
import '../transactions/widgets/transaction_row.dart';
import 'more_form_sheets.dart';

class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(accountDetailProvider(id));
    final categories =
        ref.watch(categoriesProvider).asData?.value ?? const <Category>[];
    final payees = ref.watch(payeesProvider).asData?.value ?? const <Payee>[];
    final categoryMap = {for (final c in categories) c.id: c};
    final payeeNames = {for (final p in payees) p.id: p.resolvedName};
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;
    final loadedAccount = detailAsync.asData?.value?.account;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Account'),
        // Keep Edit/Archive reachable without scrolling past the
        // transaction list.
        actions: [
          if (loadedAccount != null) ...[
            IconButton(
              tooltip: 'Edit account',
              icon: const Icon(LucideIcons.pencil, size: 20),
              onPressed: () =>
                  showAccountSheet(context, ref, initial: loadedAccount),
            ),
            IconButton(
              tooltip: 'Archive account',
              icon: const Icon(LucideIcons.archive, size: 20),
              onPressed: () => _archiveAccount(context, ref, loadedAccount),
            ),
          ],
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
                        MoneyFormat.exactMoney(account.exactBalance),
                        style: AppTypography.displayMono.copyWith(
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
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space2,
                    vertical: AppSpacing.space1,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final tx = transactions[index];
                      final category = tx.categoryId == null
                          ? null
                          : categoryMap[tx.categoryId];
                      return TransactionRowWidget(
                        transaction: tx,
                        accountName: account.name,
                        categoryName: category?.name,
                        payeeName: tx.payeeId == null
                            ? null
                            : payeeNames[tx.payeeId],
                        showDate: true,
                        leading: _TransactionLeading(
                          transaction: tx,
                          category: category,
                        ),
                        onTap: () => context.push('/transactions/${tx.id}'),
                      );
                    }, childCount: transactions.length),
                  ),
                ),
              // Keep the last row clear of the floating bottom nav.
              SliverToBoxAdapter(
                child: SizedBox(
                  height:
                      AppSpacing.bottomNavClearance +
                      MediaQuery.paddingOf(context).bottom,
                ),
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

  Future<void> _archiveAccount(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive account?'),
        content: const Text(
          'Archived accounts are hidden from the main list but remain in history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(accountRepoProvider).archive(account.id);
    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      'Account archived.',
      variant: AppSnackBarVariant.success,
    );
    context.pop();
  }
}

/// Category-coloured circle leading for [TransactionRowWidget], matching the
/// main Transactions list.
class _TransactionLeading extends StatelessWidget {
  const _TransactionLeading({required this.transaction, this.category});

  final Transaction transaction;
  final Category? category;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    final Color foreground;
    if (transaction.direction == TransactionDirection.transfer) {
      foreground = lootrColors.transfer;
    } else if (transaction.direction == TransactionDirection.income) {
      foreground = lootrColors.income;
    } else {
      foreground = lootrColors.expense;
    }

    final hasCategory = category != null;
    final background = hasCategory
        ? foreground.withValues(alpha: 0.12)
        : colorScheme.surfaceContainerHighest;
    final iconColor = hasCategory ? foreground : colorScheme.onSurfaceVariant;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: hasCategory
          ? buildCategoryVisualFor(category, color: iconColor, size: 18)
          : Icon(
              transaction.direction == TransactionDirection.transfer
                  ? Icons.swap_horiz_rounded
                  : Icons.receipt_long_outlined,
              color: iconColor,
              size: 18,
            ),
    );
  }
}

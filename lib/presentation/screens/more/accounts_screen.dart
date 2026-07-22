import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/accounts_provider.dart';
import '../../../application/providers/repo_providers.dart';
import '../../../core/format/money_format.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/value_objects/field_types.dart';
import '../../shared/components/app_snackbar.dart';
import '../../shared/components/empty_state.dart';
import '../../shared/components/swipe_action_row.dart';
import 'more_form_sheets.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  static const _accountTypeIcons = <String, IconData>{
    AccountType.cash: LucideIcons.banknote,
    AccountType.bank: LucideIcons.building2,
    AccountType.ewallet: LucideIcons.smartphone,
    AccountType.savings: LucideIcons.piggyBank,
    AccountType.investment: LucideIcons.trendingUp,
    AccountType.crypto: LucideIcons.bitcoin,
    AccountType.creditCard: LucideIcons.creditCard,
    AccountType.loan: LucideIcons.landmark,
    AccountType.bnpl: LucideIcons.split,
  };

  static const _typeLabels = <String, String>{
    AccountType.cash: 'Cash',
    AccountType.bank: 'Banks',
    AccountType.ewallet: 'E-Wallets',
    AccountType.savings: 'Savings',
    AccountType.investment: 'Investments',
    AccountType.crypto: 'Crypto',
    AccountType.creditCard: 'Credit Cards',
    AccountType.loan: 'Loans',
    AccountType.bnpl: 'BNPL',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final hasAccounts = accountsAsync.asData?.value.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Accounts'),
        actions: [
          if (hasAccounts)
            IconButton(
              tooltip: 'Add account',
              onPressed: () => showAccountSheet(context, ref),
              icon: const Icon(LucideIcons.plus),
            ),
        ],
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return EmptyState(
              headline: 'No accounts yet',
              subtext: 'Add your first account to start tracking your money.',
              ctaLabel: 'Add Account',
              onCtaPressed: () => showAccountSheet(context, ref),
            );
          }
          return _AccountList(
            accounts: accounts,
            typeIcons: _accountTypeIcons,
            typeLabels: _typeLabels,
          );
        },
        error: (err, _) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _AccountList extends StatelessWidget {
  const _AccountList({
    required this.accounts,
    required this.typeIcons,
    required this.typeLabels,
  });

  final List<Account> accounts;
  final Map<String, IconData> typeIcons;
  final Map<String, String> typeLabels;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Account>>{};
    for (final acc in accounts) {
      grouped.putIfAbsent(acc.accountType, () => []).add(acc);
    }

    final orderedTypes = <String>[
      AccountType.cash,
      AccountType.bank,
      AccountType.ewallet,
      AccountType.savings,
      AccountType.investment,
      AccountType.crypto,
      AccountType.creditCard,
      AccountType.loan,
      AccountType.bnpl,
    ];

    final sections = <Widget>[];
    for (final type in orderedTypes) {
      final items = grouped[type];
      if (items == null || items.isEmpty) continue;
      sections.add(
        _AccountSection(
          typeLabel: typeLabels[type] ?? type,
          typeIcon: typeIcons[type] ?? LucideIcons.wallet,
          accounts: items,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.space10),
      children: sections,
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.typeLabel,
    required this.typeIcon,
    required this.accounts,
  });

  final String typeLabel;
  final IconData typeIcon;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePaddingMobile,
            AppSpacing.space3,
            AppSpacing.pagePaddingMobile,
            AppSpacing.space1,
          ),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              Icon(typeIcon, size: 16, color: lootrColors.textSecondary),
              const SizedBox(width: AppSpacing.space2),
              Text(
                typeLabel,
                style: AppTypography.captionMedium.copyWith(
                  color: lootrColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        ...accounts.map((acc) => _AccountRow(account: acc, typeIcon: typeIcon)),
      ],
    );
  }
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow({required this.account, required this.typeIcon});

  final Account account;
  final IconData typeIcon;

  bool get _isCreditOrLoan =>
      account.accountType == AccountType.creditCard ||
      account.accountType == AccountType.loan ||
      account.accountType == AccountType.bnpl;

  /// Same confirm + archive flow as the account detail screen.
  Future<void> _archiveAccount(BuildContext context, WidgetRef ref) async {
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
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;
    final balanceColor = _isCreditOrLoan && account.balance != 0
        ? account.balance < 0
              ? lootrColors.danger
              : lootrColors.success
        : account.balance < 0
        ? lootrColors.danger
        : null;

    return SwipeActionRow(
      rowKey: Key(account.id),
      onEdit: () => showAccountSheet(context, ref, initial: account),
      onDelete: () => _archiveAccount(context, ref),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePaddingMobile,
        ),
        leading: Icon(typeIcon, size: 18, color: colorScheme.primary),
        title: Text(
          account.name,
          style: AppTypography.bodyMedium.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: account.isArchived
            ? Text(
                'Archived',
                style: AppTypography.caption.copyWith(
                  color: lootrColors.textTertiary,
                ),
              )
            : null,
        trailing: Text(
          MoneyFormat.exactMoney(account.exactBalance),
          style: AppTypography.mono.copyWith(
            color: balanceColor ?? colorScheme.onSurface,
          ),
        ),
        onTap: () => context.push('/more/accounts/${account.id}'),
      ),
    );
  }
}

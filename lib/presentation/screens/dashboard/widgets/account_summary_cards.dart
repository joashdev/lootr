import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/format/money_format.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../domain/entities/account.dart';
import '../../../shared/components/cards/cards.dart';

class AccountSummaryCards extends StatelessWidget {
  const AccountSummaryCards({
    super.key,
    required this.accounts,
    required this.currencyCode,
  });

  final List<Account> accounts;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Accounts', style: AppTypography.h2),
        const SizedBox(height: AppSpacing.space3),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: accounts.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppSpacing.space3),
            itemBuilder: (context, index) {
              final account = accounts[index];
              return SizedBox(
                width: 188,
                child: CompactRowCard(
                  onTap: () => context.push('/more/accounts/${account.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withValues(
                                alpha: 0.8,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _accountIcon(account.accountType),
                              size: 16,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space2),
                          Expanded(
                            child: Text(
                              account.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space3),
                      Text(
                        MoneyFormat.display(
                          account.balance,
                          account.currencyCode,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.mono.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space1),
                      Text(
                        _accountLabel(account.accountType),
                        style: AppTypography.caption.copyWith(
                          color: lootrColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _accountIcon(String type) {
    switch (type) {
      case 'bank':
        return LucideIcons.landmark;
      case 'ewallet':
        return LucideIcons.wallet;
      case 'savings':
        return LucideIcons.piggyBank;
      case 'investment':
        return LucideIcons.chartColumn;
      case 'crypto':
        return LucideIcons.coins;
      case 'credit_card':
        return LucideIcons.creditCard;
      case 'loan':
        return LucideIcons.handCoins;
      case 'bnpl':
        return LucideIcons.calendarClock;
      default:
        return LucideIcons.walletCards;
    }
  }

  String _accountLabel(String type) {
    final label = type.replaceAll('_', ' ');
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _accountIcon(account.accountType),
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.space2),
                          Expanded(
                            child: Text(
                              account.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.h3,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        NumberFormat.currency(
                          locale: 'en_PH',
                          symbol: '₱',
                          name: currencyCode,
                        ).format(account.balance),
                        style: AppTypography.h2,
                      ),
                      Text(
                        _accountLabel(account.accountType),
                        style: AppTypography.caption.copyWith(
                          color: context.lootrColors.textSecondary,
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
    return type.replaceAll('_', ' ');
  }
}

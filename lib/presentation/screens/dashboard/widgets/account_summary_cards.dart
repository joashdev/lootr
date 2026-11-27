import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/format/money_format.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../domain/entities/account.dart';
import '../../../shared/components/cards/cards.dart';
import 'dashboard_section_header.dart';

class AccountSummaryCards extends StatelessWidget {
  const AccountSummaryCards({super.key, required this.accounts});

  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;
    final extraScale = (MediaQuery.textScalerOf(context).scale(15) / 15 - 1)
        .clamp(0, 1)
        .toDouble();
    final availableWidth =
        MediaQuery.sizeOf(context).width - 2 * AppSpacing.pagePaddingMobile;
    final tileWidth = ((availableWidth - AppSpacing.space3) / 2)
        .clamp(132.0, 208.0)
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardSectionHeader(
          title: 'Accounts',
          actionLabel: 'See all accounts',
          onPressed: () => context.push('/more/accounts'),
        ),
        if (accounts.isEmpty)
          const StandardCard(child: Text('No accounts yet.'))
        else
          SizedBox(
            height: 108.0 + 68 * extraScale,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: accounts.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppSpacing.space3),
              itemBuilder: (context, index) {
                final account = accounts[index];
                return SizedBox(
                  width: accounts.length == 1
                      ? availableWidth
                      : tileWidth + 64 * extraScale,
                  child: CompactRowCard(
                    onTap: () => context.push('/more/accounts/${account.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space3,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _accountIcon(account.accountType),
                              size: 17,
                              color: colorScheme.primary,
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
                            Icon(
                              LucideIcons.chevronRight,
                              size: 14,
                              color: lootrColors.textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.space2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            MoneyFormat.display(
                              account.balance,
                              account.currencyCode,
                            ),
                            style: AppTypography.h3Mono.copyWith(
                              color: colorScheme.onSurface,
                            ),
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
    if (type == 'ewallet') return 'E-wallet';
    if (type == 'bnpl') return 'BNPL';
    final label = type.replaceAll('_', ' ');
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }
}

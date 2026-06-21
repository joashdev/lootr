import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/typography.dart';
import '../../../../domain/entities/account.dart';

/// Dropdown selector for accounts that shows each account's current balance.
class AccountDropdown extends StatelessWidget {
  const AccountDropdown({
    super.key,
    required this.accounts,
    required this.selectedAccountId,
    required this.onChanged,
  });

  final List<Account> accounts;
  final String? selectedAccountId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;
    final formatter = NumberFormat.currency(
      symbol: '₱',
      decimalDigits: 2,
      locale: 'en_PH',
    );
    final selectedExists = accounts.any(
      (account) => account.id == selectedAccountId,
    );

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colorScheme.outline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedExists ? selectedAccountId : null,
          hint: Text(
            accounts.isEmpty ? 'No accounts available' : 'Select an account',
            style: AppTypography.body.copyWith(color: lootrColors.textTertiary),
          ),
          items: accounts
              .map(
                (account) => DropdownMenuItem<String>(
                  value: account.id,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        account.name,
                        style: AppTypography.bodyMedium.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        formatter.format(account.balance),
                        style: AppTypography.caption.copyWith(
                          color: lootrColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: accounts.isEmpty ? null : onChanged,
        ),
      ),
    );
  }
}

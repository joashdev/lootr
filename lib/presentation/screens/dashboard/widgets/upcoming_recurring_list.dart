import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../application/providers/dashboard_provider.dart';
import '../../../../core/format/money_format.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../shared/components/cards/cards.dart';
import 'dashboard_section_header.dart';

class UpcomingRecurringList extends StatelessWidget {
  const UpcomingRecurringList({
    super.key,
    required this.items,
    required this.currencyCode,
  });

  final List<DashboardRecurringItem> items;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return StandardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardSectionHeader(
            title: 'Upcoming recurring',
            actionLabel: 'See all recurring items',
            onPressed: () => context.push('/more/recurring'),
          ),
          const SizedBox(height: AppSpacing.space2),
          if (items.isEmpty)
            Text(
              'No recurring bills coming up.',
              style: AppTypography.body.copyWith(
                color: context.lootrColors.textSecondary,
              ),
            )
          else
            for (var index = 0; index < items.length; index++) ...[
              _RecurringRow(item: items[index], currencyCode: currencyCode),
              if (index != items.length - 1)
                Divider(
                  color: colorScheme.outlineVariant,
                  height: AppSpacing.space4,
                ),
            ],
        ],
      ),
    );
  }
}

class _RecurringRow extends StatelessWidget {
  const _RecurringRow({required this.item, required this.currencyCode});

  final DashboardRecurringItem item;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/more/recurring/${item.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.payeeName, style: AppTypography.bodyMedium),
                    const SizedBox(height: 2),
                    Text(
                      _relativeDue(item.nextOccurrenceAt),
                      style: AppTypography.caption.copyWith(
                        color: context.lootrColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Expanded(
                child: Text(
                  MoneyFormat.exact(item.amount, currencyCode),
                  textAlign: TextAlign.end,
                  style: AppTypography.mono.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space1),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: context.lootrColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _relativeDue(DateTime date) {
  final today = DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);
  final startOfTarget = DateTime(date.year, date.month, date.day);
  final days = startOfTarget.difference(startOfToday).inDays;

  if (days <= 0) {
    return 'Today';
  }
  if (days == 1) {
    return 'Tomorrow';
  }
  return 'in $days days';
}

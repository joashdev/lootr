import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../application/providers/dashboard_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../shared/components/cards/cards.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Upcoming recurring', style: AppTypography.h2),
            ),
            TextButton(
              onPressed: () => context.push('/more/recurring'),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space3),
        if (items.isEmpty)
          CompactRowCard(
            child: Text(
              'No recurring bills coming up.',
              style: AppTypography.body.copyWith(
                color: context.lootrColors.textSecondary,
              ),
            ),
          )
        else
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space2),
              child: CompactRowCard(
                onTap: () => context.push('/more/recurring/${item.id}'),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.payeeName, style: AppTypography.h3),
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
                    Text(
                      NumberFormat.currency(
                        locale: 'en_PH',
                        symbol: '₱',
                        name: currencyCode,
                      ).format(item.amount),
                      style: AppTypography.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
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
}

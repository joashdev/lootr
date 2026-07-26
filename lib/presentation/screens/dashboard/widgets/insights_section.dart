import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../application/providers/dashboard_provider.dart';
import '../../../../application/providers/period_context_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../shared/components/cards/cards.dart';

class InsightsSection extends ConsumerWidget {
  const InsightsSection({super.key, required this.insights});

  final List<DashboardInsight> insights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Insights', style: AppTypography.h2),
        const SizedBox(height: AppSpacing.space3),
        for (final insight in insights)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space2),
            child: StandardCard(
              onTap: insight.isDrillable
                  ? () => _openInsight(context, ref, insight)
                  : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.sparkles,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(insight.title, style: AppTypography.h3),
                        const SizedBox(height: 2),
                        Text(
                          insight.body,
                          style: AppTypography.body.copyWith(
                            color: context.lootrColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openInsight(
    BuildContext context,
    WidgetRef ref,
    DashboardInsight insight,
  ) async {
    final ledgerQuery = insight.ledgerQuery;
    if (ledgerQuery != null) {
      ref.read(activeLedgerQueryProvider.notifier).open(ledgerQuery);
      await context.push('/transactions');
      if (ref.read(activeLedgerQueryProvider) == ledgerQuery) {
        ref.read(activeLedgerQueryProvider.notifier).clear();
      }
      return;
    }

    final route = insight.destinationRoute;
    if (route != null) {
      await context.push(route);
    }
  }
}

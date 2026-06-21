import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../application/providers/dashboard_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../shared/components/cards/standard_card.dart';
import '../../../shared/components/progress/progress.dart';

class NetWorthSparkline extends StatelessWidget {
  const NetWorthSparkline({super.key, required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    final changeColor = data.netWorthChangePercent >= 0
        ? lootrColors.success
        : lootrColors.danger;

    return StandardCard(
      onTap: () => context.push('/more/reports/net-worth'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net worth', style: AppTypography.captionMedium),
          const SizedBox(height: AppSpacing.space1),
          Text(
            NumberFormat.currency(
              locale: 'en_PH',
              symbol: '₱',
            ).format(data.netWorth),
            style: AppTypography.h1,
          ),
          const SizedBox(height: AppSpacing.space3),
          Sparkline(
            data: data.netWorthSeries,
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
            semanticLabel: '30-day net worth chart',
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            '${data.netWorthChangePercent >= 0 ? '+' : ''}${data.netWorthChangePercent.toStringAsFixed(1)}% this month',
            style: AppTypography.captionMedium.copyWith(color: changeColor),
          ),
        ],
      ),
    );
  }
}

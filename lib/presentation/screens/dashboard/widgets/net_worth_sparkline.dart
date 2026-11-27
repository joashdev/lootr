import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../application/providers/dashboard_provider.dart';
import '../../../../core/format/money_format.dart';
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
    final theme = Theme.of(context);
    final colors = context.lootrColors;
    final change = data.netWorthChangePercent;
    final changeColor = change >= 0 ? colors.income : colors.danger;
    final figures = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            MoneyFormat.display(data.netWorth, data.currencyCode),
            style: AppTypography.h1Mono.copyWith(fontSize: 24),
          ),
        ),
        const SizedBox(height: AppSpacing.space1),
        Text.rich(
          TextSpan(
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
            children: [
              TextSpan(
                text: '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: changeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: ' over 30 days'),
            ],
          ),
        ),
      ],
    );
    final chart = Sparkline(
      data: data.netWorthSeries,
      color: theme.colorScheme.primary,
      height: 34,
      semanticLabel: '30-day net worth chart',
    );

    return StandardCard(
      onTap: () => context.push('/more/reports/net-worth'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Net worth', style: AppTypography.h3)),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          LayoutBuilder(
            builder: (context, constraints) {
              final useColumns =
                  constraints.maxWidth >= 260 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 18;
              if (useColumns) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(flex: 3, child: figures),
                    const SizedBox(width: AppSpacing.space3),
                    Expanded(flex: 2, child: chart),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  figures,
                  const SizedBox(height: AppSpacing.space3),
                  chart,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

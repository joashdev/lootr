import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../application/providers/dashboard_provider.dart';
import '../../../../application/providers/safe_to_spend_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../shared/components/cards/cards.dart';

class SafeToSpendHero extends ConsumerWidget {
  const SafeToSpendHero({super.key, required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safeToSpend = ref.watch(safeToSpendProvider);
    final lootrColors = context.lootrColors;

    return safeToSpend.when(
      loading: () => const SizedBox(height: 180),
      error: (error, _) => Text('Unable to load safe-to-spend: $error'),
      data: (value) {
        final remainingShare = data.monthlyIncome <= 0
            ? 1.0
            : value / data.monthlyIncome;
        final semanticColor = remainingShare > 0.5
            ? lootrColors.success
            : remainingShare > 0.2
            ? lootrColors.warning
            : lootrColors.danger;
        final bgColor = semanticColor.withValues(alpha: 0.10);

        return InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          onTap: () => _showBreakdown(context, value),
          child: HeroCard(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                gradient: LinearGradient(
                  colors: [bgColor, Theme.of(context).colorScheme.surface],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    NumberFormat.currency(
                      locale: 'en_PH',
                      symbol: '₱',
                    ).format(value),
                    style: AppTypography.display.copyWith(color: semanticColor),
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  Text('Safe to spend', style: AppTypography.h2),
                  const SizedBox(height: AppSpacing.space1),
                  Text(
                    'out of ${NumberFormat.currency(locale: 'en_PH', symbol: '₱').format(data.monthlyIncome)} monthly income',
                    style: AppTypography.body.copyWith(
                      color: lootrColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: remainingShare.clamp(0, 1),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLow,
                      valueColor: AlwaysStoppedAnimation<Color>(semanticColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBreakdown(BuildContext context, double safeToSpend) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Safe-to-spend breakdown', style: AppTypography.h2),
              const SizedBox(height: AppSpacing.space4),
              _BreakdownRow(
                label: 'Safe to spend now',
                value: NumberFormat.currency(
                  locale: 'en_PH',
                  symbol: '₱',
                ).format(safeToSpend),
              ),
              _BreakdownRow(
                label: 'Monthly income',
                value: NumberFormat.currency(
                  locale: 'en_PH',
                  symbol: '₱',
                ).format(data.monthlyIncome),
              ),
              _BreakdownRow(
                label: 'This month\'s expenses',
                value: NumberFormat.currency(
                  locale: 'en_PH',
                  symbol: '₱',
                ).format(data.monthlyExpense),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                color: lootrColors.textSecondary,
              ),
            ),
          ),
          Text(value, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

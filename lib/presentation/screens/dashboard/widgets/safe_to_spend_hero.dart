import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/dashboard_provider.dart';
import '../../../../application/providers/safe_to_spend_provider.dart';
import '../../../../core/format/money_format.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    return safeToSpend.when(
      loading: () => const SizedBox(height: 180),
      error: (error, _) => Text('Unable to load safe-to-spend: $error'),
      data: (value) {
        final remainingShare = data.monthlyIncome <= 0
            ? 1.0
            : value / data.monthlyIncome;
        final clampedShare = remainingShare.clamp(0.0, 1.0).toDouble();
        final semanticColor = remainingShare > 0.5
            ? lootrColors.success
            : remainingShare > 0.2
            ? lootrColors.warning
            : lootrColors.danger;

        return InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => _showBreakdown(context, value),
          child: HeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SAFE TO SPEND',
                            style: AppTypography.micro.copyWith(
                              color: lootrColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space2),
                          Text(
                            MoneyFormat.display(value, data.currencyCode),
                            style: AppTypography.displayMono.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _HeroStatusPill(
                      label: _statusLabel(remainingShare),
                      color: semanticColor,
                    ),
                  ],
                ),
                Text('Safe to spend', style: AppTypography.h2),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  'From ${MoneyFormat.display(data.monthlyIncome, data.currencyCode)} monthly income after planned expenses.',
                  style: AppTypography.body.copyWith(
                    color: lootrColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space3),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'Remaining this month',
                            style: AppTypography.captionMedium.copyWith(
                              color: lootrColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(clampedShare * 100).round()}%',
                            style: AppTypography.mono.copyWith(
                              fontSize: 13,
                              color: semanticColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: clampedShare,
                          backgroundColor: colorScheme.surfaceContainerLow,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            semanticColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                value: MoneyFormat.exact(safeToSpend, data.currencyCode),
              ),
              _BreakdownRow(
                label: 'Monthly income',
                value: MoneyFormat.exact(data.monthlyIncome, data.currencyCode),
              ),
              _BreakdownRow(
                label: 'This month\'s expenses',
                value: MoneyFormat.exact(
                  data.monthlyExpense,
                  data.currencyCode,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(double remainingShare) {
    if (remainingShare > 0.5) {
      return 'Comfortable';
    }
    if (remainingShare > 0.2) {
      return 'Watch';
    }
    return 'Tight';
  }
}

class _HeroStatusPill extends StatelessWidget {
  const _HeroStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: AppTypography.captionMedium.copyWith(color: color),
      ),
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

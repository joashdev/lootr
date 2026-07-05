import 'package:flutter/material.dart';

import '../../../../application/providers/dashboard_provider.dart';
import '../../../../core/format/money_format.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../domain/use_cases/calculate_safe_to_spend.dart';
import '../../../shared/components/cards/cards.dart';

class SafeToSpendHero extends StatelessWidget {
  const SafeToSpendHero({super.key, required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final result = data.safeToSpend;
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    final baseline = result.basis == SafeToSpendBasis.monthlyIncome
        ? result.monthlyIncome
        : result.liquidBalance;
    final remainingShare = baseline <= 0
        ? 0.0
        : result.amount / baseline;
    final clampedShare = remainingShare.clamp(0.0, 1.0).toDouble();
    final semanticColor = result.isOverCommitted
        ? lootrColors.danger
        : remainingShare > 0.5
        ? lootrColors.success
        : remainingShare > 0.2
        ? lootrColors.warning
        : lootrColors.danger;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () => _showBreakdown(context, result),
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
                        MoneyFormat.display(result.amount, data.currencyCode),
                        style: AppTypography.displayMono.copyWith(
                          color: result.isOverCommitted
                              ? lootrColors.danger
                              : colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                _HeroStatusPill(
                  label: _statusLabel(result, remainingShare),
                  color: semanticColor,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space1),
            Text(
              _subtitle(result),
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
                      valueColor: AlwaysStoppedAnimation<Color>(semanticColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Explains the figure using the basis that actually produced it, so the
  /// copy never contradicts the number (e.g. never "from ₱0 monthly income"
  /// next to a balance-derived amount).
  String _subtitle(SafeToSpendResult result) {
    final currency = data.currencyCode;
    if (result.basis == SafeToSpendBasis.monthlyIncome) {
      return 'From ${MoneyFormat.display(result.monthlyIncome, currency)} '
          'income this month, minus '
          '${MoneyFormat.display(result.spentThisMonth, currency)} spent and '
          '${MoneyFormat.display(result.committedOutflows, currency)} still '
          'committed.';
    }
    return 'No income recorded this month — based on '
        '${MoneyFormat.display(result.liquidBalance, currency)} across liquid '
        'accounts minus '
        '${MoneyFormat.display(result.committedOutflows, currency)} in '
        'upcoming commitments.';
  }

  void _showBreakdown(BuildContext context, SafeToSpendResult result) {
    final currency = data.currencyCode;
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
                value: MoneyFormat.exact(result.amount, currency),
              ),
              if (result.basis == SafeToSpendBasis.monthlyIncome) ...[
                _BreakdownRow(
                  label: 'Income this month',
                  value: MoneyFormat.exact(result.monthlyIncome, currency),
                ),
                _BreakdownRow(
                  label: 'Spent this month',
                  value: MoneyFormat.exact(result.spentThisMonth, currency),
                ),
              ] else
                _BreakdownRow(
                  label: 'Liquid account balances',
                  value: MoneyFormat.exact(result.liquidBalance, currency),
                ),
              _BreakdownRow(
                label: 'Committed before month end',
                value: MoneyFormat.exact(result.committedOutflows, currency),
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(SafeToSpendResult result, double remainingShare) {
    if (result.isOverCommitted) {
      return 'Over-committed';
    }
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

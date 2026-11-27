import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../application/providers/dashboard_provider.dart';
import '../../../../application/providers/period_context_provider.dart';
import '../../../../core/format/money_format.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../domain/use_cases/calculate_safe_to_spend.dart';
import '../../../../domain/value_objects/ledger_query.dart';
import '../../../../domain/value_objects/period_context.dart';

class SafeToSpendHero extends ConsumerWidget {
  const SafeToSpendHero({super.key, required this.data});

  final DashboardData data;

  static const _ink = Color(0xFFFFFDF5);
  static const _quietInk = Color(0xFFC2D5C7);
  static const _mint = Color(0xFFA1D5B2);
  static const _amber = Color(0xFFF5D098);
  static const _coral = Color(0xFFFFB8A7);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = data.safeToSpend;
    final fromIncome = result.basis == SafeToSpendBasis.monthlyIncome;
    final baseline = fromIncome ? result.monthlyIncome : result.liquidBalance;
    final remainingShare = baseline <= 0 ? 0.0 : result.amount / baseline;
    final clampedShare = remainingShare.clamp(0.0, 1.0).toDouble();
    final statusColor = result.isOverCommitted || remainingShare <= 0.2
        ? _coral
        : remainingShare <= 0.5
        ? _amber
        : _mint;
    final borderRadius = BorderRadius.circular(AppRadius.lg);
    final enlargedText = MediaQuery.textScalerOf(context).scale(14) > 18;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF123327), Color(0xFF244936)],
        ),
        border: Border.all(color: _mint.withValues(alpha: 0.22)),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showBreakdown(context, ref, result),
          hoverColor: _mint.withValues(alpha: 0.08),
          highlightColor: _mint.withValues(alpha: 0.10),
          splashColor: _mint.withValues(alpha: 0.18),
          focusColor: _mint.withValues(alpha: 0.15),
          child: Padding(
            padding: EdgeInsets.all(
              enlargedText ? AppSpacing.space4 : AppSpacing.space5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SpotlightStatus(
                  label: _statusLabel(result, remainingShare),
                  color: statusColor,
                ),
                const SizedBox(height: AppSpacing.space2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    MoneyFormat.display(result.amount, data.currencyCode),
                    style: AppTypography.displayMono.copyWith(
                      fontSize: 46,
                      color: result.isOverCommitted ? _coral : _ink,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  fromIncome
                      ? 'After spending and commitments'
                      : 'Liquid balances after commitments',
                  style: AppTypography.caption.copyWith(color: _quietInk),
                ),
                const SizedBox(height: AppSpacing.space4),
                LinearProgressIndicator(
                  minHeight: 4,
                  value: clampedShare,
                  color: statusColor,
                  backgroundColor: _mint.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  stopIndicatorColor: Colors.transparent,
                  trackGap: 0,
                  semanticsLabel: 'Remaining this month',
                ),
                const SizedBox(height: AppSpacing.space2),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.space2,
                    runSpacing: AppSpacing.space1,
                    children: [
                      Text(
                        '${(clampedShare * 100).round()}% left this month',
                        style: AppTypography.captionMedium.copyWith(
                          color: _quietInk,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'View breakdown',
                              style: AppTypography.captionMedium.copyWith(
                                color: _ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space2),
                          const Icon(
                            LucideIcons.arrowRight,
                            size: 16,
                            color: _mint,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBreakdown(
    BuildContext context,
    WidgetRef ref,
    SafeToSpendResult result,
  ) {
    final currency = data.currencyCode;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await _openLedger(
                        context,
                        ref,
                        directions: const ['income'],
                        explanation: 'Income this month · $currency',
                      );
                    },
                  ),
                  _BreakdownRow(
                    label: 'Spent this month',
                    value: MoneyFormat.exact(result.spentThisMonth, currency),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await _openLedger(
                        context,
                        ref,
                        directions: const ['expense'],
                        explanation: 'Expenses this month · $currency',
                      );
                    },
                  ),
                ] else
                  _BreakdownRow(
                    label: 'Liquid account balances',
                    value: MoneyFormat.exact(result.liquidBalance, currency),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      context.push('/more/accounts');
                    },
                  ),
                _BreakdownRow(
                  label: 'Committed before month end',
                  value: MoneyFormat.exact(result.committedOutflows, currency),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.push('/more/recurring');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openLedger(
    BuildContext context,
    WidgetRef ref, {
    required List<String> directions,
    required String explanation,
  }) async {
    final query = LedgerQuery(
      explanation: explanation,
      period: PeriodContext.calendarMonth(data.currentDate),
      directions: directions,
      currencyCode: data.currencyCode,
    );
    ref.read(activeLedgerQueryProvider.notifier).open(query);
    await context.push('/transactions');
    if (ref.read(activeLedgerQueryProvider) == query) {
      ref.read(activeLedgerQueryProvider.notifier).clear();
    }
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

class _SpotlightStatus extends StatelessWidget {
  const _SpotlightStatus({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.space3,
        runSpacing: AppSpacing.space1,
        children: [
          Text(
            'SAFE TO SPEND',
            style: AppTypography.micro.copyWith(
              color: SafeToSpendHero._ink,
              letterSpacing: 1.1,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 6, color: color),
              const SizedBox(width: AppSpacing.space2),
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.captionMedium.copyWith(color: color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
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
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Text(
                value,
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.end,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.space1),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: lootrColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: row,
    );
  }
}

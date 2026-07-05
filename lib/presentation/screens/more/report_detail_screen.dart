import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/reports_provider.dart';
import '../../../core/format/money_format.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../shared/components/cards/standard_card.dart';
import '../../shared/components/empty_state.dart';
import '../../shared/components/progress/budget_progress_bar.dart';
import '../../shared/components/progress/sparkline.dart';

/// Clearance so scrollable content ends above the floating bottom nav pill.
const double _bottomNavClearance = 120;

class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({super.key, required this.type});

  final String type;

  String get _title {
    switch (type) {
      case 'spending-category':
        return 'Spending by Category';
      case 'income-vs-expenses':
        return 'Income vs Expenses';
      case 'net-worth':
        return 'Net Worth Over Time';
      case 'budget-performance':
        return 'Budget Performance';
      case 'cash-flow':
        return 'Cash Flow';
      default:
        return 'Report';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(centerTitle: false, title: Text(_title)),
      body: switch (type) {
        'spending-category' => const _CategorySpendingReportBody(),
        'income-vs-expenses' => const _MonthlyFlowReportBody(
          mode: _FlowMode.incomeVsExpenses,
        ),
        'cash-flow' => const _MonthlyFlowReportBody(mode: _FlowMode.cashFlow),
        'net-worth' => const _NetWorthReportBody(),
        'budget-performance' => const _BudgetPerformanceReportBody(),
        _ => EmptyState(
          headline: 'Report not found',
          subtext: 'This report type is not available.',
          ctaLabel: 'Back to Reports',
          onCtaPressed: () => context.pop(),
          illustration: const Icon(LucideIcons.chartBarBig, size: 64),
        ),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared scaffolding
// ---------------------------------------------------------------------------

EdgeInsets _reportPadding(BuildContext context) => EdgeInsets.fromLTRB(
  AppSpacing.pagePaddingMobile,
  AppSpacing.space4,
  AppSpacing.pagePaddingMobile,
  _bottomNavClearance + MediaQuery.of(context).padding.bottom,
);

Widget _reportLoading() => const Center(child: CircularProgressIndicator());

Widget _reportError(BuildContext context, Object error) => Center(
  child: Padding(
    padding: const EdgeInsets.all(AppSpacing.space8),
    child: Text(
      'Something went wrong loading this report.',
      style: AppTypography.body.copyWith(
        color: context.lootrColors.textSecondary,
      ),
      textAlign: TextAlign.center,
    ),
  ),
);

class _ReportSummaryStat extends StatelessWidget {
  const _ReportSummaryStat({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: context.lootrColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.h3Mono.copyWith(
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Spending by Category
// ---------------------------------------------------------------------------

class _CategorySpendingReportBody extends ConsumerWidget {
  const _CategorySpendingReportBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(categorySpendingReportProvider);

    return report.when(
      loading: _reportLoading,
      error: (error, _) => _reportError(context, error),
      data: (data) {
        if (data.isEmpty) {
          return EmptyState(
            headline: 'No spending yet',
            subtext:
                'Expenses you add in ${data.periodLabel} will be broken down by category here.',
            ctaLabel: 'Add Transaction',
            onCtaPressed: () => context.push('/transactions/new'),
            illustration: const Icon(LucideIcons.pieChart, size: 64),
          );
        }

        final lootrColors = context.lootrColors;
        return ListView(
          padding: _reportPadding(context),
          children: [
            Text(
              data.periodLabel,
              style: AppTypography.captionMedium.copyWith(
                color: lootrColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            StandardCard(
              child: Column(
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: CustomPaint(
                      painter: _DonutPainter(slices: data.slices),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Total spent',
                              style: AppTypography.captionMedium.copyWith(
                                color: lootrColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              MoneyFormat.display(
                                data.total,
                                data.currencyCode,
                              ),
                              style: AppTypography.h2Mono,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  for (final slice in data.slices)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSpacing.space2,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: slice.color,
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space2),
                          Expanded(
                            child: Text(
                              slice.name,
                              style: AppTypography.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            MoneyFormat.display(
                              slice.amount,
                              data.currencyCode,
                            ),
                            style: AppTypography.mono,
                          ),
                          const SizedBox(width: AppSpacing.space2),
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${(slice.percentage * 100).round()}%',
                              textAlign: TextAlign.right,
                              style: AppTypography.mono.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: lootrColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.slices});

  final List<ReportCategorySlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 20.0;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );
    var startAngle = -math.pi / 2;

    for (final slice in slices) {
      final sweepAngle = 2 * math.pi * slice.percentage;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.slices != slices;
  }
}

// ---------------------------------------------------------------------------
// Income vs Expenses / Cash Flow (shared monthly flow data)
// ---------------------------------------------------------------------------

enum _FlowMode { incomeVsExpenses, cashFlow }

class _MonthlyFlowReportBody extends ConsumerWidget {
  const _MonthlyFlowReportBody({required this.mode});

  final _FlowMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(monthlyFlowReportProvider);

    return report.when(
      loading: _reportLoading,
      error: (error, _) => _reportError(context, error),
      data: (data) {
        if (data.isEmpty) {
          return EmptyState(
            headline: mode == _FlowMode.cashFlow
                ? 'No cash flow yet'
                : 'Nothing to compare yet',
            subtext:
                'Add income and expense transactions to see your last six months here.',
            ctaLabel: 'Add Transaction',
            onCtaPressed: () => context.push('/transactions/new'),
            illustration: Icon(
              mode == _FlowMode.cashFlow
                  ? LucideIcons.arrowLeftRight
                  : LucideIcons.barChart3,
              size: 64,
            ),
          );
        }

        final lootrColors = context.lootrColors;
        return ListView(
          padding: _reportPadding(context),
          children: [
            Text(
              'Last 6 months',
              style: AppTypography.captionMedium.copyWith(
                color: lootrColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            StandardCard(
              child: Row(
                children: [
                  _ReportSummaryStat(
                    label: 'Income',
                    value: MoneyFormat.display(
                      data.totalIncome,
                      data.currencyCode,
                    ),
                    valueColor: lootrColors.income,
                  ),
                  _ReportSummaryStat(
                    label: 'Expenses',
                    value: MoneyFormat.display(
                      data.totalExpense,
                      data.currencyCode,
                    ),
                    valueColor: lootrColors.expense,
                  ),
                  _ReportSummaryStat(
                    label: 'Net',
                    value: MoneyFormat.display(
                      data.totalNet,
                      data.currencyCode,
                    ),
                    valueColor: data.totalNet >= 0
                        ? lootrColors.success
                        : lootrColors.danger,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            StandardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final month in data.months)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSpacing.space3,
                      ),
                      child: mode == _FlowMode.incomeVsExpenses
                          ? _IncomeExpenseMonthRow(
                              point: month,
                              maxValue: _maxFlowValue(data),
                              currencyCode: data.currencyCode,
                            )
                          : _CashFlowMonthRow(
                              point: month,
                              maxAbsNet: _maxAbsNet(data),
                              currencyCode: data.currencyCode,
                            ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  double _maxFlowValue(MonthlyFlowReport data) => data.months.fold<double>(
    0,
    (max, m) => math.max(max, math.max(m.income, m.expense)),
  );

  double _maxAbsNet(MonthlyFlowReport data) =>
      data.months.fold<double>(0, (max, m) => math.max(max, m.net.abs()));
}

class _IncomeExpenseMonthRow extends StatelessWidget {
  const _IncomeExpenseMonthRow({
    required this.point,
    required this.maxValue,
    required this.currencyCode,
  });

  final MonthlyFlowPoint point;
  final double maxValue;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${point.label} ${point.year}',
          style: AppTypography.captionMedium.copyWith(
            color: lootrColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.space1),
        _FlowBar(
          value: point.income,
          maxValue: maxValue,
          color: lootrColors.income,
          label: MoneyFormat.display(point.income, currencyCode),
        ),
        const SizedBox(height: AppSpacing.space1),
        _FlowBar(
          value: point.expense,
          maxValue: maxValue,
          color: lootrColors.expense,
          label: MoneyFormat.display(point.expense, currencyCode),
        ),
      ],
    );
  }
}

class _CashFlowMonthRow extends StatelessWidget {
  const _CashFlowMonthRow({
    required this.point,
    required this.maxAbsNet,
    required this.currencyCode,
  });

  final MonthlyFlowPoint point;
  final double maxAbsNet;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    final positive = point.net >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${point.label} ${point.year}',
                style: AppTypography.captionMedium.copyWith(
                  color: lootrColors.textSecondary,
                ),
              ),
            ),
            Text(
              '${positive ? '+' : ''}${MoneyFormat.display(point.net, currencyCode)}',
              style: AppTypography.mono.copyWith(
                fontSize: 13,
                color: positive ? lootrColors.success : lootrColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space1),
        _FlowBar(
          value: point.net.abs(),
          maxValue: maxAbsNet,
          color: positive ? lootrColors.success : lootrColors.danger,
        ),
      ],
    );
  }
}

class _FlowBar extends StatelessWidget {
  const _FlowBar({
    required this.value,
    required this.maxValue,
    required this.color,
    this.label,
  });

  final double value;
  final double maxValue;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final factor = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            Container(color: colorScheme.surfaceContainerLow),
            FractionallySizedBox(
              widthFactor: factor,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (label == null) return bar;

    return Row(
      children: [
        Expanded(child: bar),
        const SizedBox(width: AppSpacing.space2),
        SizedBox(
          width: 88,
          child: Text(
            label!,
            textAlign: TextAlign.right,
            style: AppTypography.mono.copyWith(fontSize: 13, color: color),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Net Worth Over Time
// ---------------------------------------------------------------------------

class _NetWorthReportBody extends ConsumerWidget {
  const _NetWorthReportBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(netWorthReportProvider);

    return report.when(
      loading: _reportLoading,
      error: (error, _) => _reportError(context, error),
      data: (data) {
        if (data.isEmpty) {
          return EmptyState(
            headline: 'No accounts yet',
            subtext:
                'Add your accounts to start tracking your net worth over time.',
            ctaLabel: 'Add Account',
            onCtaPressed: () => context.push('/more/accounts'),
            illustration: const Icon(LucideIcons.trendingUp, size: 64),
          );
        }

        final lootrColors = context.lootrColors;
        final colorScheme = Theme.of(context).colorScheme;
        final positiveChange = data.changePercent >= 0;
        final rangeLabel =
            '${DateFormat.MMMd().format(data.startDate)} – ${DateFormat.MMMd().format(data.endDate)}';

        return ListView(
          padding: _reportPadding(context),
          children: [
            Text(
              'Last 90 days · $rangeLabel',
              style: AppTypography.captionMedium.copyWith(
                color: lootrColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            StandardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current net worth',
                    style: AppTypography.caption.copyWith(
                      color: lootrColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space1),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          MoneyFormat.display(data.current, data.currencyCode),
                          style: AppTypography.h1Mono,
                        ),
                      ),
                      Text(
                        '${positiveChange ? '+' : ''}${data.changePercent.toStringAsFixed(1)}%',
                        style: AppTypography.mono.copyWith(
                          color: positiveChange
                              ? lootrColors.success
                              : lootrColors.danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Sparkline(
                    data: data.series,
                    height: 160,
                    color: colorScheme.primary,
                    semanticLabel: 'Net worth over the last 90 days',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Budget Performance
// ---------------------------------------------------------------------------

class _BudgetPerformanceReportBody extends ConsumerWidget {
  const _BudgetPerformanceReportBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(budgetPerformanceReportProvider);

    return report.when(
      loading: _reportLoading,
      error: (error, _) => _reportError(context, error),
      data: (data) {
        if (data.isEmpty) {
          return EmptyState(
            headline: 'No budgets yet',
            subtext:
                'Create budgets to see how your spending tracks against them.',
            ctaLabel: 'Set Up Budgets',
            onCtaPressed: () => context.push('/budgets'),
            illustration: const Icon(LucideIcons.target, size: 64),
          );
        }

        final lootrColors = context.lootrColors;
        return ListView(
          padding: _reportPadding(context),
          children: [
            Text(
              data.periodLabel,
              style: AppTypography.captionMedium.copyWith(
                color: lootrColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            StandardCard(
              child: Row(
                children: [
                  _ReportSummaryStat(
                    label: 'Budgeted',
                    value: MoneyFormat.display(
                      data.totalBudgeted,
                      data.currencyCode,
                    ),
                  ),
                  _ReportSummaryStat(
                    label: 'Spent',
                    value: MoneyFormat.display(
                      data.totalSpent,
                      data.currencyCode,
                    ),
                    valueColor: lootrColors.expense,
                  ),
                  _ReportSummaryStat(
                    label: 'Used',
                    value: '${(data.progress * 100).round()}%',
                    valueColor: data.progress >= 1
                        ? lootrColors.danger
                        : data.progress >= 0.85
                        ? lootrColors.warning
                        : lootrColors.success,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            StandardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final row in data.rows)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSpacing.space3,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: row.color,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.full,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.space2),
                              Expanded(
                                child: Text(
                                  row.name,
                                  style: AppTypography.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: MoneyFormat.display(
                                        row.spent,
                                        data.currencyCode,
                                      ),
                                      style: AppTypography.mono.copyWith(
                                        fontSize: 13,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          ' / ${MoneyFormat.display(row.budgeted, data.currencyCode)}',
                                      style: AppTypography.mono.copyWith(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: lootrColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.space2),
                          BudgetProgressBar(
                            progress: row.progress,
                            semanticLabel: '${row.name} budget usage',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

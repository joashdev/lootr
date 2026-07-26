import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/reports_provider.dart';
import '../../../application/providers/period_context_provider.dart';
import '../../../core/format/money_format.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/value_objects/ledger_query.dart';
import '../../../domain/value_objects/period_context.dart';
import '../../shared/components/cards/standard_card.dart';
import '../../shared/components/empty_state.dart';
import '../../shared/components/period_selector.dart';
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
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePaddingMobile,
            ),
            child: PeriodSelector(),
          ),
          Expanded(
            child: switch (type) {
              'spending-category' => const _CategorySpendingReportBody(),
              'income-vs-expenses' => const _MonthlyFlowReportBody(
                mode: _FlowMode.incomeVsExpenses,
              ),
              'cash-flow' => const _MonthlyFlowReportBody(
                mode: _FlowMode.cashFlow,
              ),
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
          ),
        ],
      ),
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

Future<void> _openLedger(
  BuildContext context,
  WidgetRef ref,
  LedgerQuery query,
) async {
  ref.read(activeLedgerQueryProvider.notifier).open(query);
  await context.push('/transactions');
  if (ref.read(activeLedgerQueryProvider) == query) {
    ref.read(activeLedgerQueryProvider.notifier).clear();
  }
}

class _ReportSummaryStat extends StatelessWidget {
  const _ReportSummaryStat({
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
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
    );
    return Expanded(
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.space1,
                ),
                child: content,
              ),
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
      data: (reports) {
        final visibleReports = reports.where((data) => !data.isEmpty).toList();
        if (visibleReports.isEmpty) {
          return EmptyState(
            headline: 'No spending yet',
            subtext:
                'Expenses you add will be broken down by category and currency here.',
            ctaLabel: 'Add Transaction',
            onCtaPressed: () => context.push('/transactions/new'),
            illustration: const Icon(LucideIcons.pieChart, size: 64),
          );
        }

        return ListView(
          padding: _reportPadding(context),
          children: [
            for (final data in visibleReports) ...[
              _CategoryCurrencySection(data: data),
              const SizedBox(height: AppSpacing.space4),
            ],
          ],
        );
      },
    );
  }
}

class _CategoryCurrencySection extends ConsumerWidget {
  const _CategoryCurrencySection({required this.data});

  final CategorySpendingReport data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lootrColors = context.lootrColors;
    final period = ref.watch(periodContextProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${data.periodLabel} · ${data.currencyCode}',
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
                    child: InkWell(
                      onTap: () => _openLedger(
                        context,
                        ref,
                        LedgerQuery(
                          explanation:
                              'Expenses in ${period.description} · ${data.currencyCode}',
                          period: period,
                          directions: const ['expense'],
                          currencyCode: data.currencyCode,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.full),
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
                            MoneyFormat.display(data.total, data.currencyCode),
                            style: AppTypography.h2Mono,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              for (final slice in data.slices)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.space2),
                  child: InkWell(
                    onTap: () => _openLedger(
                      context,
                      ref,
                      LedgerQuery(
                        explanation:
                            '${slice.name} expenses in ${period.description} · ${data.currencyCode}',
                        period: period,
                        directions: const ['expense'],
                        categoryIds: slice.categoryId == null
                            ? const []
                            : [slice.categoryId!],
                        currencyCode: data.currencyCode,
                        uncategorizedOnly: slice.categoryId == null,
                      ),
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
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
                  ),
                ),
            ],
          ),
        ),
      ],
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
      data: (reports) {
        final visibleReports = reports.where((data) => !data.isEmpty).toList();
        if (visibleReports.isEmpty) {
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

        return ListView(
          padding: _reportPadding(context),
          children: [
            for (final data in visibleReports) ...[
              _MonthlyFlowCurrencySection(data: data, mode: mode),
              const SizedBox(height: AppSpacing.space4),
            ],
          ],
        );
      },
    );
  }
}

class _MonthlyFlowCurrencySection extends ConsumerWidget {
  const _MonthlyFlowCurrencySection({required this.data, required this.mode});

  final MonthlyFlowReport data;
  final _FlowMode mode;

  double get _maxFlowValue => data.months.fold<double>(
    0,
    (max, m) => math.max(max, math.max(m.income, m.expense)),
  );

  double get _maxAbsNet =>
      data.months.fold<double>(0, (max, m) => math.max(max, m.net.abs()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lootrColors = context.lootrColors;
    final sixMonthPeriod = PeriodContext.customCycle(
      id: 'report-six-months',
      name: 'Last 6 months',
      startsAt: DateTime(data.months.first.year, data.months.first.month),
      endsAt: DateTime(data.months.last.year, data.months.last.month + 1),
    );
    void open(List<String> directions, String label, PeriodContext period) {
      _openLedger(
        context,
        ref,
        LedgerQuery(
          explanation: '$label · ${period.description} · ${data.currencyCode}',
          period: period,
          directions: directions,
          currencyCode: data.currencyCode,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last 6 months · ${data.currencyCode}',
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
                value: MoneyFormat.display(data.totalIncome, data.currencyCode),
                valueColor: lootrColors.income,
                onTap: () => open(const ['income'], 'Income', sixMonthPeriod),
              ),
              _ReportSummaryStat(
                label: 'Expenses',
                value: MoneyFormat.display(
                  data.totalExpense,
                  data.currencyCode,
                ),
                valueColor: lootrColors.expense,
                onTap: () =>
                    open(const ['expense'], 'Expenses', sixMonthPeriod),
              ),
              _ReportSummaryStat(
                label: 'Net',
                value: MoneyFormat.display(data.totalNet, data.currencyCode),
                valueColor: data.totalNet >= 0
                    ? lootrColors.success
                    : lootrColors.danger,
                onTap: () => open(
                  const ['income', 'expense'],
                  'Income and expenses',
                  sixMonthPeriod,
                ),
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
                  padding: const EdgeInsets.only(bottom: AppSpacing.space3),
                  child: mode == _FlowMode.incomeVsExpenses
                      ? _IncomeExpenseMonthRow(
                          point: month,
                          maxValue: _maxFlowValue,
                          currencyCode: data.currencyCode,
                          onIncomeTap: () => open(
                            const ['income'],
                            'Income',
                            PeriodContext.calendarMonth(
                              DateTime(month.year, month.month),
                            ),
                          ),
                          onExpenseTap: () => open(
                            const ['expense'],
                            'Expenses',
                            PeriodContext.calendarMonth(
                              DateTime(month.year, month.month),
                            ),
                          ),
                        )
                      : _CashFlowMonthRow(
                          point: month,
                          maxAbsNet: _maxAbsNet,
                          currencyCode: data.currencyCode,
                          onTap: () => open(
                            const ['income', 'expense'],
                            'Cash flow',
                            PeriodContext.calendarMonth(
                              DateTime(month.year, month.month),
                            ),
                          ),
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IncomeExpenseMonthRow extends StatelessWidget {
  const _IncomeExpenseMonthRow({
    required this.point,
    required this.maxValue,
    required this.currencyCode,
    required this.onIncomeTap,
    required this.onExpenseTap,
  });

  final MonthlyFlowPoint point;
  final double maxValue;
  final String currencyCode;
  final VoidCallback onIncomeTap;
  final VoidCallback onExpenseTap;

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
          onTap: onIncomeTap,
        ),
        const SizedBox(height: AppSpacing.space1),
        _FlowBar(
          value: point.expense,
          maxValue: maxValue,
          color: lootrColors.expense,
          label: MoneyFormat.display(point.expense, currencyCode),
          onTap: onExpenseTap,
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
    required this.onTap,
  });

  final MonthlyFlowPoint point;
  final double maxAbsNet;
  final String currencyCode;
  final VoidCallback onTap;

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
          onTap: onTap,
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
    this.onTap,
  });

  final double value;
  final double maxValue;
  final Color color;
  final String? label;
  final VoidCallback? onTap;

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

    final content = label == null
        ? bar
        : Row(
            children: [
              Expanded(child: bar),
              const SizedBox(width: AppSpacing.space2),
              SizedBox(
                width: 88,
                child: Text(
                  label!,
                  textAlign: TextAlign.right,
                  style: AppTypography.mono.copyWith(
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ),
            ],
          );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: label == null ? 'Open transactions' : '$label. Open transactions',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: content,
        ),
      ),
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
      data: (reports) {
        final visibleReports = reports.where((data) => !data.isEmpty).toList();
        if (visibleReports.isEmpty) {
          return EmptyState(
            headline: 'No accounts yet',
            subtext:
                'Add your accounts to start tracking your net worth over time.',
            ctaLabel: 'Add Account',
            onCtaPressed: () => context.push('/more/accounts'),
            illustration: const Icon(LucideIcons.trendingUp, size: 64),
          );
        }

        return ListView(
          padding: _reportPadding(context),
          children: [
            for (final data in visibleReports) ...[
              _NetWorthCurrencySection(data: data),
              const SizedBox(height: AppSpacing.space4),
            ],
          ],
        );
      },
    );
  }
}

class _NetWorthCurrencySection extends StatelessWidget {
  const _NetWorthCurrencySection({required this.data});

  final NetWorthReport data;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    final positiveChange = data.changePercent >= 0;
    final rangeLabel =
        '${DateFormat.MMMd().format(data.startDate)} – ${DateFormat.MMMd().format(data.endDate)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last 90 days · $rangeLabel · ${data.currencyCode}',
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
                color: Theme.of(context).colorScheme.primary,
                semanticLabel:
                    '${data.currencyCode} net worth over the last 90 days',
              ),
            ],
          ),
        ),
      ],
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
      data: (reports) {
        final visibleReports = reports.where((data) => !data.isEmpty).toList();
        if (visibleReports.isEmpty) {
          return EmptyState(
            headline: 'No budgets yet',
            subtext:
                'Create budgets to see how your spending tracks against them.',
            ctaLabel: 'Set Up Budgets',
            onCtaPressed: () => context.push('/budgets'),
            illustration: const Icon(LucideIcons.target, size: 64),
          );
        }

        return ListView(
          padding: _reportPadding(context),
          children: [
            for (final data in visibleReports) ...[
              _BudgetPerformanceCurrencySection(data: data),
              const SizedBox(height: AppSpacing.space4),
            ],
          ],
        );
      },
    );
  }
}

class _BudgetPerformanceCurrencySection extends StatelessWidget {
  const _BudgetPerformanceCurrencySection({required this.data});

  final BudgetPerformanceReport data;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${data.periodLabel} · ${data.currencyCode}',
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
                value: MoneyFormat.display(data.totalSpent, data.currencyCode),
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
                  padding: const EdgeInsets.only(bottom: AppSpacing.space3),
                  child: InkWell(
                    onTap: () => context.push(
                      row.isImported
                          ? '/budgets/imported/${row.budgetId}'
                                '?year=${row.periodStart.year}'
                                '&month=${row.periodStart.month}'
                          : '/budgets/${row.budgetId}',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.space1,
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      row.name,
                                      style: AppTypography.bodyMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (row.isImported)
                                      Text(
                                        row.isReadOnly
                                            ? 'Imported · Read-only'
                                            : 'Imported',
                                        style: AppTypography.caption.copyWith(
                                          color: lootrColors.textSecondary,
                                        ),
                                      ),
                                  ],
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
                            semanticLabel:
                                '${row.name} ${data.currencyCode} budget usage',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

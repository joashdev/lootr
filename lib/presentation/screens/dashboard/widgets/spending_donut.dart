import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../application/providers/dashboard_provider.dart';
import '../../../../core/format/money_format.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../shared/components/cards/standard_card.dart';
import 'dashboard_section_header.dart';

class SpendingDonut extends StatelessWidget {
  const SpendingDonut({super.key, required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return StandardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardSectionHeader(
            title: 'Spending by category',
            actionText: 'Report',
            actionLabel: 'View spending by category report',
            onPressed: () => context.push('/more/reports/spending-category'),
          ),
          const SizedBox(height: AppSpacing.space3),
          if (data.spendingByCategory.isEmpty)
            Text(
              'No expense activity this month yet.',
              style: AppTypography.body.copyWith(
                color: context.lootrColors.textSecondary,
              ),
            )
          else ...[
            _SpendingSnapshot(data: data),
            const SizedBox(height: AppSpacing.space4),
            for (final slice in data.spendingByCategory)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.space2),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: slice.color,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    Expanded(
                      child: Text(slice.name, style: AppTypography.bodyMedium),
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    Expanded(
                      child: Text(
                        MoneyFormat.display(slice.amount, data.currencyCode),
                        style: AppTypography.mono,
                        textAlign: TextAlign.end,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    Text(
                      '${(slice.percentage * 100).round()}%',
                      style: AppTypography.mono.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: context.lootrColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SpendingSnapshot extends StatelessWidget {
  const _SpendingSnapshot({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final colors = context.lootrColors;
    final amount = data.spendingByCategory.fold<double>(
      0,
      (sum, slice) => sum + slice.amount,
    );
    final share = data.spendingByCategory.fold<double>(
      0,
      (sum, slice) => sum + slice.percentage,
    );
    final percent = (share.clamp(0, 1) * 100).round();
    final figure = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top categories',
          style: AppTypography.captionMedium.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.space1),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            MoneyFormat.display(amount, data.currencyCode),
            style: AppTypography.h1Mono,
          ),
        ),
        const SizedBox(height: AppSpacing.space1),
        Text(
          '$percent% of categorized spending',
          style: AppTypography.caption.copyWith(color: colors.textSecondary),
        ),
      ],
    );
    final chart = ExcludeSemantics(
      child: SizedBox.square(
        dimension: 100,
        child: CustomPaint(
          painter: _DonutPainter(
            slices: data.spendingByCategory,
            trackColor: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 240 &&
            MediaQuery.textScalerOf(context).scale(14) <= 18) {
          return Row(
            children: [
              Expanded(child: figure),
              const SizedBox(width: AppSpacing.space4),
              chart,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            figure,
            const SizedBox(height: AppSpacing.space3),
            chart,
          ],
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.slices, required this.trackColor});

  final List<DashboardSpendingSlice> slices;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 14.0;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );
    canvas.drawCircle(
      center,
      radius - strokeWidth / 2,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    var startAngle = -math.pi / 2;

    for (final slice in slices) {
      final sweepAngle = 2 * math.pi * slice.percentage;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.slices != slices || oldDelegate.trackColor != trackColor;
  }
}

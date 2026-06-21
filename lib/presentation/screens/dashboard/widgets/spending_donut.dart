import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../application/providers/dashboard_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../shared/components/cards/standard_card.dart';

class SpendingDonut extends StatelessWidget {
  const SpendingDonut({super.key, required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return StandardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Spending by category', style: AppTypography.h2),
              ),
              TextButton(
                onPressed: () =>
                    context.push('/more/reports/spending-category'),
                child: const Text('View all'),
              ),
            ],
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
            Center(
              child: SizedBox(
                width: 180,
                height: 180,
                child: CustomPaint(
                  painter: _DonutPainter(slices: data.spendingByCategory),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Top 5', style: AppTypography.captionMedium),
                        const SizedBox(height: 2),
                        Text(
                          NumberFormat.currency(
                            locale: 'en_PH',
                            symbol: '₱',
                          ).format(
                            data.spendingByCategory.fold<double>(
                              0,
                              (sum, slice) => sum + slice.amount,
                            ),
                          ),
                          style: AppTypography.h2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
                    Text(
                      NumberFormat.currency(
                        locale: 'en_PH',
                        symbol: '₱',
                      ).format(slice.amount),
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    Text(
                      '${(slice.percentage * 100).round()}%',
                      style: AppTypography.caption.copyWith(
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

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.slices});

  final List<DashboardSpendingSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = 20.0;
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

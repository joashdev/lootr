import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../application/providers/dashboard_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/theme/typography.dart';
import '../../../shared/category_visuals.dart';
import '../../../shared/components/cards/cards.dart';

class BudgetProgressRings extends StatelessWidget {
  const BudgetProgressRings({
    super.key,
    required this.budgets,
    required this.currencyCode,
  });

  final List<DashboardBudgetSummary> budgets;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Budgets', style: AppTypography.h2),
        const SizedBox(height: AppSpacing.space3),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: budgets.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppSpacing.space3),
            itemBuilder: (context, index) {
              final budget = budgets[index];
              return SizedBox(
                width: 164,
                child: CompactRowCard(
                  onTap: () => context.push('/budgets/${budget.id}'),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _AnimatedProgressRing(
                        progress: budget.progress.clamp(0, 1),
                        color: _budgetColor(context, budget.progress),
                        iconName: budget.icon,
                      ),
                      Column(
                        children: [
                          Text(
                            budget.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.h3,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${NumberFormat.currency(locale: 'en_PH', symbol: '₱', name: currencyCode).format(budget.spent)} / ${NumberFormat.currency(locale: 'en_PH', symbol: '₱', name: currencyCode).format(budget.budgeted)}',
                            style: AppTypography.mono.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: context.lootrColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _budgetColor(BuildContext context, double progress) {
    if (progress >= 1) {
      return context.lootrColors.danger;
    }
    if (progress >= 0.85) {
      return context.lootrColors.warning;
    }
    return context.lootrColors.success;
  }
}

class _AnimatedProgressRing extends StatefulWidget {
  const _AnimatedProgressRing({
    required this.progress,
    required this.color,
    required this.iconName,
  });

  final double progress;
  final Color color;
  final String? iconName;

  @override
  State<_AnimatedProgressRing> createState() => _AnimatedProgressRingState();
}

class _AnimatedProgressRingState extends State<_AnimatedProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppTheme.progressDuration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _controller, curve: AppTheme.progressCurve),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(begin: _animation.value, end: widget.progress)
          .animate(
            CurvedAnimation(parent: _controller, curve: AppTheme.progressCurve),
          );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return CustomPaint(
          painter: _ProgressRingPainter(
            progress: _animation.value,
            color: widget.color,
            trackColor: Theme.of(context).colorScheme.surfaceContainerLow,
          ),
          child: SizedBox(
            width: 80,
            height: 80,
            child: Center(
              child: buildCategoryVisual(
                widget.iconName,
                color: widget.color,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 8.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - stroke) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0, 1),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

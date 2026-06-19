import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/theme.dart';

class BudgetProgressBar extends StatefulWidget {
  const BudgetProgressBar({
    super.key,
    required this.progress,
    this.color,
    this.height = 8,
    this.semanticLabel,
  });

  final double progress;
  final Color? color;
  final double height;
  final String? semanticLabel;

  @override
  State<BudgetProgressBar> createState() => _BudgetProgressBarState();
}

class _BudgetProgressBarState extends State<BudgetProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
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
  void didUpdateWidget(BudgetProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: AppTheme.progressCurve,
      ));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _fillColor(BuildContext context) {
    if (widget.color != null) return widget.color!;
    final lootrColors = context.lootrColors;
    if (widget.progress >= 1.0) return lootrColors.danger;
    if (widget.progress >= 0.85) return lootrColors.warning;
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: widget.semanticLabel,
      value: '${(widget.progress * 100).round()}%',
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: SizedBox(
              height: widget.height,
              child: Stack(
                children: [
                  Container(
                    color: colorScheme.surfaceContainerLow,
                  ),
                  FractionallySizedBox(
                    widthFactor: _animation.value.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _fillColor(context),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

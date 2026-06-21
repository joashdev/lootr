import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import 'date_group_header.dart';

class TransactionShimmer extends StatefulWidget {
  const TransactionShimmer({super.key, this.itemCount = 6});
  final int itemCount;

  @override
  State<TransactionShimmer> createState() => _TransactionShimmerState();
}

class _TransactionShimmerState extends State<TransactionShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? AppColors.darkSurfaceElevated
        : const Color(0xFFE5E7EB);
    final highlightColor = isDark
        ? AppColors.darkBorder
        : const Color(0xFFF3F4F6);

    final placeholders = <Widget>[
      const DateGroupHeader(title: 'Today'),
      ...List.generate(
        widget.itemCount ~/ 2,
        (_) =>
            _ShimmerRow(baseColor: baseColor, highlightColor: highlightColor),
      ),
      const DateGroupHeader(title: 'Yesterday'),
      ...List.generate(
        (widget.itemCount / 2).ceil(),
        (_) =>
            _ShimmerRow(baseColor: baseColor, highlightColor: highlightColor),
      ),
    ];

    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1).animate(_controller),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: placeholders,
      ),
    );
  }
}

class _ShimmerRow extends StatelessWidget {
  const _ShimmerRow({required this.baseColor, required this.highlightColor});

  final Color baseColor;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: highlightColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(
                    color: highlightColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 80,
                  height: 11,
                  decoration: BoxDecoration(
                    color: highlightColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 72,
                height: 14,
                decoration: BoxDecoration(
                  color: highlightColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 48,
                height: 11,
                decoration: BoxDecoration(
                  color: highlightColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';

class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerLow;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePaddingMobile,
        AppSpacing.space3,
        AppSpacing.pagePaddingMobile,
        120,
      ),
      children: [
        _ShimmerBlock(height: 60, color: baseColor),
        const SizedBox(height: AppSpacing.space4),
        _ShimmerBlock(height: 180, color: baseColor),
        const SizedBox(height: AppSpacing.space4),
        _ShimmerBlock(height: 140, color: baseColor),
        const SizedBox(height: AppSpacing.space5),
        _HorizontalSkeleton(height: 120, color: baseColor),
        const SizedBox(height: AppSpacing.space5),
        _ShimmerBlock(height: 100, color: baseColor),
        const SizedBox(height: AppSpacing.space5),
        _HorizontalSkeleton(height: 170, color: baseColor),
        const SizedBox(height: AppSpacing.space5),
        _ShimmerBlock(height: 280, color: baseColor),
        const SizedBox(height: AppSpacing.space5),
        _ShimmerBlock(height: 360, color: baseColor),
        const SizedBox(height: AppSpacing.space5),
        _ShimmerBlock(height: 220, color: baseColor),
      ],
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    );
  }
}

class _HorizontalSkeleton extends StatelessWidget {
  const _HorizontalSkeleton({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.space3),
        itemBuilder: (_, index) => SizedBox(
          width: 156,
          child: _ShimmerBlock(height: height, color: color),
        ),
      ),
    );
  }
}

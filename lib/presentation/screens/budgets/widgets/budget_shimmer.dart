import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/spacing.dart';

class BudgetShimmer extends StatelessWidget {
  const BudgetShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color(0xFF2E2E33)
        : const Color(0xFFE2E4E8);
    final highlightColor = isDark
        ? const Color(0xFF3E3E44)
        : const Color(0xFFF2F4F7);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        children: [
          _BudgetShimmerCard(),
          _BudgetShimmerCard(),
          _BudgetShimmerCard(),
          _BudgetShimmerCard(),
          _BudgetShimmerCard(),
        ],
      ),
    );
  }
}

class _BudgetShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingStandard),
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: colorScheme.outline)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              Container(
                width: 60,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

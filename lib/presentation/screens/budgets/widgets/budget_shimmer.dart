import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';

class BudgetShimmer extends StatelessWidget {
  const BudgetShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget block({
      double? width,
      required double height,
      required double radius,
    }) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.outlineVariant,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    final placeholder = Column(
      children: [
        block(width: double.infinity, height: 144, radius: AppRadius.xl),
        const SizedBox(height: AppSpacing.space3),
        for (var index = 0; index < 4; index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
            child: Row(
              children: [
                block(width: 36, height: 36, radius: AppRadius.md),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      block(width: 144, height: 16, radius: AppRadius.sm),
                      const SizedBox(height: AppSpacing.space2),
                      block(
                        width: double.infinity,
                        height: 4,
                        radius: AppRadius.full,
                      ),
                      const SizedBox(height: AppSpacing.space2),
                      block(width: 104, height: 12, radius: AppRadius.sm),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    return Semantics(
      label: 'Loading budgets',
      child: MediaQuery.disableAnimationsOf(context)
          ? placeholder
          : Shimmer.fromColors(
              baseColor: colors.outlineVariant,
              highlightColor: colors.surfaceContainerHighest,
              child: placeholder,
            ),
    );
  }
}

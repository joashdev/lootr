import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';

/// A row of dots indicating the current onboarding step.
///
/// The active dot is wider and uses the primary color; inactive dots are
/// smaller and use a subtle border color.
class StepIndicator extends StatelessWidget {
  const StepIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
  });

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          key: ValueKey('step-dot-$index'),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.space1),
          height: 8,
          width: isActive ? 24 : 8,
          decoration: BoxDecoration(
            color: isActive ? colorScheme.primary : colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

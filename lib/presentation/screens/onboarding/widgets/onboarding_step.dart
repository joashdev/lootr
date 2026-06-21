import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';

/// A single onboarding page: a hero illustration, a title, a description and
/// optional extra [child] content (e.g. the setup form on the last step).
class OnboardingStep extends StatelessWidget {
  const OnboardingStep({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space6,
        vertical: AppSpacing.space4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Icon(icon, size: 56, color: colorScheme.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.space8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.h1,
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: lootrColors.textSecondary),
          ),
          if (child != null) ...[
            const SizedBox(height: AppSpacing.space8),
            child!,
          ],
        ],
      ),
    );
  }
}

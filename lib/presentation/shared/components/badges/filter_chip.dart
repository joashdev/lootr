import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/typography.dart';

class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.full),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary50 : colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: isActive ? AppColors.primary200 : colorScheme.outline,
            ),
          ),
          child: Text(
            label,
            style: isActive
                ? AppTypography.captionMedium.copyWith(
                    color: colorScheme.primary,
                  )
                : AppTypography.caption.copyWith(
                    color: lootrColors.textSecondary,
                  ),
          ),
        ),
      ),
    );
  }
}

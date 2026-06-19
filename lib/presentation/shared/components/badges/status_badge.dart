import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/typography.dart';

enum StatusBadgeColor { success, warning, danger }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.color = StatusBadgeColor.success,
    this.customColor,
    this.customBackgroundColor,
  });

  final String label;
  final StatusBadgeColor color;
  final Color? customColor;
  final Color? customBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<LootrColorScheme>()!;

    Color bgColor;
    Color textColor;

    if (customBackgroundColor != null && customColor != null) {
      bgColor = customBackgroundColor!;
      textColor = customColor!;
    } else {
      switch (color) {
        case StatusBadgeColor.success:
          bgColor = colors.successBg;
          textColor = colors.success;
        case StatusBadgeColor.warning:
          bgColor = colors.warningBg;
          textColor = colors.warning;
        case StatusBadgeColor.danger:
          bgColor = colors.dangerBg;
          textColor = colors.danger;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.micro.copyWith(color: textColor),
      ),
    );
  }
}

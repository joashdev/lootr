import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/typography.dart';

class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isExpanded = true,
    this.icon,
    this.isDanger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isExpanded;
  final Widget? icon;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = isDanger
        ? context.lootrColors.danger
        : colorScheme.primary;

    final child = icon != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [icon!, const SizedBox(width: 8), Text(label)],
          )
        : Text(label);

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size(isExpanded ? double.infinity : 0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: AppTypography.bodyMedium,
        foregroundColor: foreground,
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        overlayColor: colorScheme.primary.withValues(alpha: 0.1),
      ),
      child: child,
    );
  }
}

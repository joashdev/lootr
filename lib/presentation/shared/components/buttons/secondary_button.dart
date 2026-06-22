import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/typography.dart';

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
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
    final lootrColors = context.lootrColors;
    final foreground = isDanger ? lootrColors.danger : colorScheme.onSurface;
    final border = isDanger
        ? lootrColors.danger.withValues(alpha: 0.5)
        : colorScheme.outline;

    final child = icon != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [icon!, const SizedBox(width: 8), Text(label)],
          )
        : Text(label) as Widget;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(isExpanded ? double.infinity : 0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        textStyle: AppTypography.bodyMedium,
        backgroundColor: colorScheme.surface,
        foregroundColor: foreground,
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      child: child,
    );
  }
}

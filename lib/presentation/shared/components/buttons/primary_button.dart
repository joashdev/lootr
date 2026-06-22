import 'package:flutter/material.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/typography.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isExpanded = true,
    this.icon,
    this.isTonal = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isExpanded;
  final Widget? icon;
  final bool isTonal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget child;
    if (isLoading) {
      child = const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [icon!, const SizedBox(width: 8), Text(label)],
      );
    } else {
      child = Text(label);
    }

    if (isTonal) {
      return FilledButton.tonal(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: Size(isExpanded ? double.infinity : 0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          textStyle: AppTypography.bodyMedium,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        child: child,
      );
    }

    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size(isExpanded ? double.infinity : 0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        textStyle: AppTypography.bodyMedium.copyWith(
          color: colorScheme.onPrimary,
        ),
        backgroundColor: colorScheme.primary,
        disabledBackgroundColor: colorScheme.primary.withValues(alpha: 0.12),
        disabledForegroundColor: colorScheme.primary.withValues(alpha: 0.38),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      child: child,
    );
  }
}

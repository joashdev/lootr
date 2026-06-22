import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/typography.dart';

enum AppSnackBarVariant { success, warning, error, neutral }

class AppSnackBar extends StatelessWidget {
  const AppSnackBar({
    super.key,
    required this.message,
    this.variant = AppSnackBarVariant.neutral,
    this.action,
    this.duration = const Duration(seconds: 4),
  });

  final String message;
  final AppSnackBarVariant variant;
  final SnackBarAction? action;
  final Duration duration;

  static void show(
    BuildContext context,
    String message, {
    AppSnackBarVariant variant = AppSnackBarVariant.neutral,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: _SnackBarContent(message: message, variant: variant),
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.horizontal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: duration,
        action: actionLabel != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction!)
            : null,
      ),
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message,
      variant: AppSnackBarVariant.error,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message,
      variant: AppSnackBarVariant.warning,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _SnackBarContent extends StatelessWidget {
  const _SnackBarContent({required this.message, required this.variant});

  final String message;
  final AppSnackBarVariant variant;

  IconData _icon() {
    switch (variant) {
      case AppSnackBarVariant.success:
        return LucideIcons.checkCircle2;
      case AppSnackBarVariant.warning:
        return LucideIcons.alertTriangle;
      case AppSnackBarVariant.error:
        return LucideIcons.xCircle;
      case AppSnackBarVariant.neutral:
        return LucideIcons.info;
    }
  }

  Color _color(BuildContext context) {
    final lootrColors = context.lootrColors;
    switch (variant) {
      case AppSnackBarVariant.success:
        return lootrColors.success;
      case AppSnackBarVariant.warning:
        return lootrColors.warning;
      case AppSnackBarVariant.error:
        return lootrColors.danger;
      case AppSnackBarVariant.neutral:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);

    return Row(
      children: [
        Icon(_icon(), color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: AppTypography.body.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

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

    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final targetContext = rootContext.mounted ? rootContext : context;
    final colorScheme = Theme.of(targetContext).colorScheme;

    final messenger = ScaffoldMessenger.of(targetContext);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: _SnackBarContent(
          message: message,
          variant: variant,
          surfaceColor: colorScheme.surface,
          onSurfaceColor: colorScheme.onSurface,
        ),
        backgroundColor: colorScheme.surface,
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.horizontal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: duration,
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: colorScheme.primary,
                onPressed: onAction!,
              )
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
  const _SnackBarContent({
    required this.message,
    required this.variant,
    required this.surfaceColor,
    required this.onSurfaceColor,
  });

  final String message;
  final AppSnackBarVariant variant;
  final Color surfaceColor;
  final Color onSurfaceColor;

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

  Color _color() {
    switch (variant) {
      case AppSnackBarVariant.success:
        return AppColors.success600;
      case AppSnackBarVariant.warning:
        return AppColors.warning600;
      case AppSnackBarVariant.error:
        return AppColors.danger600;
      case AppSnackBarVariant.neutral:
        return AppColors.primary600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();

    return Row(
      children: [
        Icon(_icon(), color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: AppTypography.body.copyWith(color: onSurfaceColor),
          ),
        ),
      ],
    );
  }
}

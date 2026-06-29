import 'package:flutter/material.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/shadows.dart';

class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.child, this.margin, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Container(
        padding: padding ?? const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withValues(
                alpha: isDark ? 0.18 : 0.55,
              ),
              colorScheme.surface,
              colorScheme.surface,
            ],
            stops: const [0, 0.26, 1],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: isDark ? AppShadows.none : AppShadows.sm,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: child,
      ),
    );
  }
}

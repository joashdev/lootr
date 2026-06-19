import 'package:flutter/material.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/shadows.dart';

class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.child,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: isDark ? AppShadows.none : AppShadows.md,
          border: isDark ? Border.all(color: colorScheme.outline) : null,
        ),
        child: child,
      ),
    );
  }
}

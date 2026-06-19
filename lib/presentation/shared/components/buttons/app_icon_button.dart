import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.full),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.full),
          customBorder: const CircleBorder(),
          child: Tooltip(
            message: tooltip ?? '',
            child: Semantics(
              label: semanticLabel ?? tooltip ?? '',
              button: true,
              child: Icon(
                icon,
                size: 24,
                color: lootrColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

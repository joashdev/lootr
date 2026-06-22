import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import 'buttons/primary_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.headline,
    required this.subtext,
    required this.ctaLabel,
    this.onCtaPressed,
    this.illustration,
  });

  final String headline;
  final String subtext;
  final String ctaLabel;
  final VoidCallback? onCtaPressed;
  final Widget? illustration;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: IconTheme.merge(
                data: IconThemeData(color: lootrColors.textTertiary),
                child:
                    illustration ??
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: lootrColors.textTertiary,
                    ),
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              headline,
              style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              subtext,
              style: AppTypography.body.copyWith(
                color: lootrColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.space4),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 220),
              child: PrimaryButton(
                label: ctaLabel,
                onPressed: onCtaPressed,
                isExpanded: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

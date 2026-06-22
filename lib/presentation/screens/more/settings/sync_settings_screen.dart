import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../shared/components/buttons/secondary_button.dart';

class SyncSettingsScreen extends ConsumerWidget {
  const SyncSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Cloud Sync')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.cloud,
                size: 64,
                color: lootrColors.textTertiary,
              ),
              const SizedBox(height: AppSpacing.space6),
              Text(
                'Cloud sync coming soon',
                style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(
                'Your data stays on your device. Cloud sync and backup will be available in a future update.',
                style: AppTypography.body.copyWith(
                  color: lootrColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.space4),
              SecondaryButton(
                label: 'Sync Now',
                onPressed: null,
                icon: const Icon(LucideIcons.refreshCw, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

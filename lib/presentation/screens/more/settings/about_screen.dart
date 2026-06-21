import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('About')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  LucideIcons.coins,
                  size: 40,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.space6),
              Text(
                'Lootr',
                style: AppTypography.h1.copyWith(color: colorScheme.onSurface),
              ),
              const SizedBox(height: AppSpacing.space1),
              Text(
                'Version 1.0.0 (Build 1)',
                style: AppTypography.body.copyWith(
                  color: lootrColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.space6),
              _DetailRow(label: 'Version', value: '1.0.0'),
              const SizedBox(height: AppSpacing.space2),
              _DetailRow(label: 'Build', value: '1'),
              const SizedBox(height: AppSpacing.space6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: 'Lootr',
                    applicationVersion: '1.0.0',
                  ),
                  icon: const Icon(LucideIcons.scrollText, size: 18),
                  label: const Text('Licenses'),
                ),
              ),
              const SizedBox(height: AppSpacing.space3),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Privacy Policy'),
                      content: const Text(
                        'Lootr keeps your data on-device in V1. Sync, backup, and data sharing stay opt-in as future features.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                  icon: const Icon(LucideIcons.shield, size: 18),
                  label: const Text('Privacy Policy'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.body.copyWith(color: lootrColors.textSecondary),
        ),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

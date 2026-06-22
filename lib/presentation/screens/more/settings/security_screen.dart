import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Security')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
        children: [
          _SettingsSection(
            header: 'App Lock',
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePaddingMobile,
                ),
                secondary: Icon(
                  LucideIcons.fingerprint,
                  size: 20,
                  color: colorScheme.primary,
                ),
                title: Text(
                  'Biometric Lock',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  'Require fingerprint or face to open the app',
                  style: AppTypography.caption.copyWith(
                    color: lootrColors.textSecondary,
                  ),
                ),
                value: false,
                onChanged: (_) {},
              ),
            ],
          ),
          _SettingsSection(
            header: 'PIN',
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePaddingMobile,
                ),
                leading: Icon(
                  LucideIcons.keyRound,
                  size: 20,
                  color: colorScheme.primary,
                ),
                title: Text(
                  'App PIN',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  'Set a PIN to protect your data',
                  style: AppTypography.caption.copyWith(
                    color: lootrColors.textSecondary,
                  ),
                ),
                trailing: Text(
                  'Coming soon',
                  style: AppTypography.caption.copyWith(
                    color: lootrColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.header, required this.children});

  final String header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePaddingMobile,
            AppSpacing.space3,
            AppSpacing.pagePaddingMobile,
            AppSpacing.space1,
          ),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Text(
            header,
            style: AppTypography.captionMedium.copyWith(
              color: lootrColors.textSecondary,
            ),
          ),
        ),
        ...children,
        const SizedBox(height: AppSpacing.space3),
      ],
    );
  }
}

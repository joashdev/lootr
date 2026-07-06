import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../application/providers/current_user_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Profile & Preferences'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
        children: [
          _SettingsSection(
            header: 'Profile',
            children: [
              _SettingsTile(
                leading: Icon(
                  LucideIcons.user,
                  size: 20,
                  color: colorScheme.primary,
                ),
                title: 'Display Name',
                subtitle: 'Your local profile name',
                trailing: Text(
                  user?.displayName ?? 'Local User',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              _SettingsTile(
                leading: Icon(
                  LucideIcons.mail,
                  size: 20,
                  color: colorScheme.primary,
                ),
                title: 'Email',
                subtitle: 'Read-only in V1',
                trailing: Text(
                  user?.email ?? '—',
                  style: AppTypography.bodyMedium.copyWith(
                    color: lootrColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          _SettingsSection(
            header: 'Preferences',
            children: [
              _SettingsTile(
                leading: Icon(
                  LucideIcons.coins,
                  size: 20,
                  color: colorScheme.primary,
                ),
                title: 'Currency',
                subtitle: user?.currencyCode ?? 'PHP',
                trailing: Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: lootrColors.textTertiary,
                ),
              ),
              _SettingsTile(
                leading: Icon(
                  LucideIcons.globe,
                  size: 20,
                  color: colorScheme.primary,
                ),
                title: 'Locale',
                subtitle: user?.locale ?? 'en-PH',
                trailing: Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: lootrColors.textTertiary,
                ),
              ),
              _SettingsTile(
                leading: Icon(
                  LucideIcons.clock,
                  size: 20,
                  color: colorScheme.primary,
                ),
                title: 'Timezone',
                subtitle: user?.timezone ?? 'Asia/Manila (GMT+8)',
                trailing: Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: lootrColors.textTertiary,
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

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingMobile,
      ),
      leading: leading,
      title: Text(
        title,
        style: AppTypography.bodyMedium.copyWith(color: colorScheme.onSurface),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.caption.copyWith(color: lootrColors.textSecondary),
      ),
      trailing: trailing,
    );
  }
}

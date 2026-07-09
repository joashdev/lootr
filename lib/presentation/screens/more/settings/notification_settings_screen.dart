import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../application/providers/notification_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(notificationSettingsProvider);

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
        children: [
          _SettingsSection(
            header: 'Reminders',
            children: [
              _SwitchTile(
                leading: Icon(
                  LucideIcons.repeat,
                  size: 20,
                  color: colorScheme.primary,
                ),
                title: 'Recurring Reminders',
                subtitle: 'Get notified before recurring transactions',
                value: settings.recurringReminder,
                onChanged: (value) =>
                    _updateSetting(ref, 'recurring_reminder', value),
              ),
              _SwitchTile(
                leading: Icon(
                  LucideIcons.creditCard,
                  size: 20,
                  color: colorScheme.primary,
                ),
                title: 'Bill Due',
                subtitle: 'Get notified before bills are due',
                value: settings.billDue,
                onChanged: (value) => _updateSetting(ref, 'bill_due', value),
              ),
              _SwitchTile(
                leading: Icon(
                  LucideIcons.calendar,
                  size: 20,
                  color: colorScheme.primary,
                ),
                title: 'Installment Due',
                subtitle: 'Get notified for upcoming installments',
                value: settings.installmentDue,
                onChanged: (value) =>
                    _updateSetting(ref, 'installment_due', value),
              ),
              _SwitchTile(
                leading: Icon(
                  LucideIcons.handCoins,
                  size: 20,
                  color: colorScheme.primary,
                ),
                title: 'Debt Reminders',
                subtitle: 'Get notified about debt deadlines',
                value: settings.debtReminder,
                onChanged: (value) =>
                    _updateSetting(ref, 'debt_reminder', value),
              ),
              _SwitchTile(
                leading: Icon(
                  LucideIcons.badgeDollarSign,
                  size: 20,
                  color: colorScheme.primary,
                ),
                title: 'Subscription Reminders',
                subtitle: 'Get notified about recurring subscriptions',
                value: settings.subscriptionReminder,
                onChanged: (value) =>
                    _updateSetting(ref, 'subscription_reminder', value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateSetting(
    WidgetRef ref,
    String notificationType,
    bool value,
  ) async {
    await ref
        .read(notificationSettingsProvider.notifier)
        .setEnabled(notificationType, value);
    await ref.read(notificationSchedulerProvider).rebuildSchedule();
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

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingMobile,
      ),
      secondary: leading,
      title: Text(
        title,
        style: AppTypography.bodyMedium.copyWith(color: colorScheme.onSurface),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.caption.copyWith(color: lootrColors.textSecondary),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

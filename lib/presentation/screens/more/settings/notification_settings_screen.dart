import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Notifications'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
        children: [
          _SettingsSection(header: 'Reminders', children: [
            _SwitchTile(
              leading: Icon(LucideIcons.repeat, size: 20, color: colorScheme.primary),
              title: 'Recurring Reminders',
              subtitle: 'Get notified before recurring transactions',
              value: true,
            ),
            _SwitchTile(
              leading: Icon(LucideIcons.creditCard, size: 20, color: colorScheme.primary),
              title: 'Bill Due',
              subtitle: 'Get notified before bills are due',
              value: true,
            ),
            _SwitchTile(
              leading: Icon(LucideIcons.calendar, size: 20, color: colorScheme.primary),
              title: 'Installment Due',
              subtitle: 'Get notified for upcoming installments',
              value: false,
            ),
            _SwitchTile(
              leading: Icon(LucideIcons.handCoins, size: 20, color: colorScheme.primary),
              title: 'Debt Reminders',
              subtitle: 'Get notified about debt deadlines',
              value: true,
            ),
          ]),
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

class _SwitchTile extends StatefulWidget {
  const _SwitchTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final bool value;

  @override
  State<_SwitchTile> createState() => _SwitchTileState();
}

class _SwitchTileState extends State<_SwitchTile> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingMobile,
      ),
      secondary: widget.leading,
      title: Text(
        widget.title,
        style: AppTypography.bodyMedium.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        widget.subtitle,
        style: AppTypography.caption.copyWith(
          color: lootrColors.textSecondary,
        ),
      ),
      value: _value,
      onChanged: (v) {
        setState(() => _value = v);
      },
    );
  }
}

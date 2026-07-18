import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/more_tab_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../shared/components/primary_screen_header.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  static const _iconMap = <String, IconData>{
    'wallet': LucideIcons.wallet,
    'hand-coins': LucideIcons.handCoins,
    'target': LucideIcons.target,
    'repeat': LucideIcons.repeat,
    'chart-bar': LucideIcons.chartBarBig,
    'sparkles': LucideIcons.sparkles,
    'tag': LucideIcons.tag,
    'address-book': LucideIcons.contact,
    'users': LucideIcons.users,
    'user-circle': LucideIcons.userCircle,
    'bell': LucideIcons.bell,
    'brain': LucideIcons.brain,
    'cloud': LucideIcons.cloud,
    'database': LucideIcons.database,
    'palette': LucideIcons.palette,
    'shield-check': LucideIcons.shieldCheck,
    'info': LucideIcons.info,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(moreTabProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;

    return Scaffold(
      appBar: const PrimaryScreenHeader(title: 'More'),
      body: ListView.separated(
        padding: const EdgeInsets.only(bottom: AppSpacing.space8),
        itemCount: sections.fold<int>(0, (sum, g) => sum + 1 + g.items.length),
        separatorBuilder: (_, _) => Divider(
          height: 1,
          indent: AppSpacing.pagePaddingMobile + 24 + AppSpacing.space3,
          color: lootrColors.borderSubtle,
        ),
        itemBuilder: (context, index) {
          var offset = 0;
          for (final group in sections) {
            if (index == offset) {
              return _SectionHeader(title: group.header);
            }
            offset++;
            final itemIndex = index - offset;
            if (itemIndex < group.items.length) {
              final item = group.items[itemIndex];
              final isLastInGroup = itemIndex == group.items.length - 1;
              return _MoreListTile(
                leading: Icon(
                  _iconMap[item.icon] ?? LucideIcons.dot,
                  size: 20,
                  color: item.enabled
                      ? colorScheme.primary
                      : lootrColors.textTertiary,
                ),
                title: item.label,
                trailing: Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: lootrColors.textTertiary,
                ),
                onTap: item.enabled ? () => context.push(item.route) : null,
                isLastInGroup: isLastInGroup,
                enabled: item.enabled,
              );
            }
            offset += group.items.length;
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePaddingMobile,
        AppSpacing.space5,
        AppSpacing.pagePaddingMobile,
        AppSpacing.space2,
      ),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Text(
        title,
        style: AppTypography.captionMedium.copyWith(
          color: lootrColors.textSecondary,
        ),
      ),
    );
  }
}

class _MoreListTile extends StatelessWidget {
  const _MoreListTile({
    required this.leading,
    required this.title,
    required this.trailing,
    required this.onTap,
    this.isLastInGroup = false,
    this.enabled = true,
  });

  final Widget leading;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool isLastInGroup;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePaddingMobile,
            vertical: AppSpacing.space3,
          ),
          child: Row(
            children: [
              SizedBox(width: 24, child: leading),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: enabled
                        ? Theme.of(context).colorScheme.onSurface
                        : context.lootrColors.textTertiary,
                  ),
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

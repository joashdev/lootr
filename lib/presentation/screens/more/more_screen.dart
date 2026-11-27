import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/more_tab_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../shared/components/primary_screen_header.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(moreTabProvider);

    return Scaffold(
      appBar: const PrimaryScreenHeader(title: 'More'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.pageMaxWidth),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pagePaddingMobile,
              AppSpacing.space4,
              AppSpacing.pagePaddingMobile,
              AppSpacing.bottomNavClearance +
                  MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: sections.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSpacing.space5),
            itemBuilder: (context, index) =>
                _MoreSection(group: sections[index], featured: index == 0),
          ),
        ),
      ),
    );
  }
}

class _MoreSection extends StatelessWidget {
  const _MoreSection({required this.group, required this.featured});

  final MoreSectionGroup group;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.space1,
              bottom: AppSpacing.space2,
            ),
            child: Text(group.header, style: AppTypography.h3),
          ),
        ),
        if (featured)
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = AppSpacing.space2;
              final tileWidth = (constraints.maxWidth - gap) / 2;
              final labelSize = MediaQuery.textScalerOf(context).scale(15);
              if (tileWidth < labelSize * 9) {
                return _MoreList(items: group.items);
              }
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final item in group.items)
                    SizedBox(
                      width: tileWidth,
                      child: _MoreListTile(item: item, featured: true),
                    ),
                ],
              );
            },
          )
        else
          _MoreList(items: group.items),
      ],
    );
  }
}

class _MoreList extends StatelessWidget {
  const _MoreList({required this.items});

  final List<MoreItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (index, item) in items.indexed) ...[
            if (index > 0)
              const Divider(indent: 48, endIndent: AppSpacing.space3),
            _MoreListTile(item: item),
          ],
        ],
      ),
    );
  }
}

class _MoreListTile extends StatelessWidget {
  const _MoreListTile({required this.item, this.featured = false});

  final MoreItem item;
  final bool featured;

  static const _iconMap = <String, IconData>{
    'wallet': LucideIcons.wallet,
    'hand-coins': LucideIcons.handCoins,
    'target': LucideIcons.target,
    'repeat': LucideIcons.repeat,
    'chart-bar': LucideIcons.chartBarBig,
    'sparkles': LucideIcons.sparkles,
    'tag': LucideIcons.tag,
    'list-filter': LucideIcons.listFilter,
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = context.lootrColors.textSecondary;
    final icon = _iconMap[item.icon] ?? LucideIcons.dot;
    final VoidCallback? open = item.enabled
        ? () => context.push(item.route)
        : null;

    if (featured) {
      return Material(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          enabled: item.enabled,
          minTileHeight: 84,
          minVerticalPadding: AppSpacing.space3,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space3,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 22, color: colors.onPrimaryContainer),
                  if (item.enabled)
                    Icon(
                      LucideIcons.chevronRight,
                      size: 16,
                      color: colors.onPrimaryContainer,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(
                item.label,
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
            ],
          ),
          onTap: open,
        ),
      );
    }

    return ListTile(
      enabled: item.enabled,
      minTileHeight: 48,
      minLeadingWidth: 24,
      horizontalTitleGap: AppSpacing.space3,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.space3),
      leading: Icon(
        icon,
        size: 20,
        color: item.enabled ? colors.primary : muted,
      ),
      title: Text(
        item.label,
        style: AppTypography.bodyMedium.copyWith(
          color: item.enabled ? colors.onSurface : muted,
        ),
      ),
      subtitle: item.enabled
          ? null
          : Text(
              'Enable in AI & Data',
              style: AppTypography.caption.copyWith(color: muted),
            ),
      trailing: item.enabled
          ? Icon(LucideIcons.chevronRight, size: 16, color: muted)
          : null,
      onTap: open,
    );
  }
}

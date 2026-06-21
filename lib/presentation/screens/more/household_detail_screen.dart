import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/households_provider.dart';
import '../../../application/providers/repo_providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/value_objects/field_types.dart';
import '../../shared/components/empty_state.dart';
import 'more_form_sheets.dart';

class HouseholdDetailScreen extends ConsumerWidget {
  const HouseholdDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(householdDetailProvider(id));

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Household'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.userPlus),
            onPressed: detailAsync.value == null
                ? null
                : () => showHouseholdMemberSheet(
                    context,
                    ref,
                    detailAsync.value!.household,
                  ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.pencil),
            onPressed: detailAsync.value == null
                ? null
                : () => showHouseholdSheet(
                    context,
                    ref,
                    initial: detailAsync.value!.household,
                  ),
          ),
        ],
      ),
      body: detailAsync.when(
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Household not found'));
          }

          final household = detail.household;
          final members = detail.members;
          final lootrColors = context.lootrColors;
          final colorScheme = Theme.of(context).colorScheme;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.pagePaddingMobile),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        household.name,
                        style: AppTypography.h1.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space2),
                      Text(
                        '${members.length} member${members.length == 1 ? '' : 's'} • Created ${_formatDate(household.createdAt)}',
                        style: AppTypography.caption.copyWith(
                          color: lootrColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space4),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () =>
                              showHouseholdMemberSheet(context, ref, household),
                          icon: const Icon(LucideIcons.userPlus, size: 18),
                          label: const Text('Invite Member'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  color: colorScheme.surfaceContainerLow,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePaddingMobile,
                    AppSpacing.space3,
                    AppSpacing.pagePaddingMobile,
                    AppSpacing.space1,
                  ),
                  child: Text(
                    'Members',
                    style: AppTypography.captionMedium.copyWith(
                      color: lootrColors.textSecondary,
                    ),
                  ),
                ),
              ),
              if (members.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    headline: 'No members yet',
                    subtext: 'Invite your first member to start collaborating.',
                    ctaLabel: 'Invite Member',
                    onCtaPressed: () =>
                        showHouseholdMemberSheet(context, ref, household),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final member = members[index];
                    return _MemberTile(
                      member: member,
                      canEditRole:
                          detail.currentUserId == household.createdByUserId &&
                          member.member.userId != household.createdByUserId,
                      onRoleChanged: (role) async {
                        await ref
                            .read(householdRepoProvider)
                            .updateMemberRole(member.member.id, role);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${member.displayName} is now ${roleLabel(role).toLowerCase()}.',
                            ),
                          ),
                        );
                      },
                    );
                  }, childCount: members.length),
                ),
            ],
          );
        },
        error: (err, _) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month]} ${dt.day}, ${dt.year}';
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.canEditRole,
    required this.onRoleChanged,
  });

  final HouseholdMemberView member;
  final bool canEditRole;
  final Future<void> Function(String role) onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;
    final initial = member.displayName.characters.first.toUpperCase();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingMobile,
      ),
      leading: CircleAvatar(
        backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
        child: Text(
          initial,
          style: AppTypography.captionMedium.copyWith(
            color: colorScheme.primary,
          ),
        ),
      ),
      title: Text(
        member.displayName,
        style: AppTypography.bodyMedium.copyWith(color: colorScheme.onSurface),
      ),
      subtitle: Text(
        '${member.roleLabel}${member.isCreator ? ' • Creator' : ''}',
        style: AppTypography.caption.copyWith(color: lootrColors.textSecondary),
      ),
      trailing: canEditRole
          ? PopupMenuButton<String>(
              onSelected: onRoleChanged,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: HouseholdRole.member,
                  child: Text('Make member'),
                ),
                PopupMenuItem(
                  value: HouseholdRole.viewer,
                  child: Text('Make viewer'),
                ),
              ],
            )
          : Text(
              member.roleLabel,
              style: AppTypography.caption.copyWith(
                color: lootrColors.textTertiary,
              ),
            ),
      onTap: member.isCurrentUser ? () => context.push('/more/settings') : null,
    );
  }
}

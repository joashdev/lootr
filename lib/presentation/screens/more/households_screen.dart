import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/households_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../shared/components/empty_state.dart';
import 'more_form_sheets.dart';

class HouseholdsScreen extends ConsumerWidget {
  const HouseholdsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdsAsync = ref.watch(householdsProvider);
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Households')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showHouseholdSheet(context, ref),
        child: const Icon(LucideIcons.plus),
      ),
      body: householdsAsync.when(
        data: (households) {
          if (households.isEmpty) {
            return EmptyState(
              headline: 'No households yet',
              subtext:
                  'Create a household to organize shared finances and members.',
              ctaLabel: 'Create Household',
              onCtaPressed: () => showHouseholdSheet(context, ref),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(
              top: AppSpacing.space2,
              bottom: AppSpacing.space8,
            ),
            itemCount: households.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              indent: AppSpacing.pagePaddingMobile,
              color: lootrColors.borderSubtle,
            ),
            itemBuilder: (context, index) {
              final summary = households[index];
              final roleText = summary.currentUserRole == null
                  ? null
                  : roleLabel(summary.currentUserRole!);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePaddingMobile,
                ),
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(
                    LucideIcons.users,
                    color: colorScheme.primary,
                    size: 18,
                  ),
                ),
                title: Text(
                  summary.household.name,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  '${summary.memberCount} member${summary.memberCount == 1 ? '' : 's'}'
                  '${roleText == null ? '' : ' • $roleText'}',
                  style: AppTypography.caption.copyWith(
                    color: lootrColors.textSecondary,
                  ),
                ),
                trailing: Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: lootrColors.textTertiary,
                ),
                onTap: () =>
                    context.push('/more/households/${summary.household.id}'),
              );
            },
          );
        },
        error: (err, _) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

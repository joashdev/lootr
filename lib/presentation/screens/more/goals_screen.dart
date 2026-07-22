import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/goals_provider.dart';
import '../../../application/providers/repo_providers.dart';
import '../../../core/format/money_format.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/entities/goal.dart';
import '../../shared/components/app_snackbar.dart';
import '../../shared/components/buttons/ghost_button.dart';
import '../../shared/components/empty_state.dart';
import '../../shared/components/progress/budget_progress_bar.dart';
import '../../shared/components/swipe_action_row.dart';
import 'more_form_sheets.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    final hasGoals = goalsAsync.asData?.value.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Goals'),
        actions: [
          if (hasGoals)
            IconButton(
              tooltip: 'Add goal',
              onPressed: () => showGoalSheet(context, ref),
              icon: const Icon(LucideIcons.plus),
            ),
        ],
      ),
      body: goalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) {
            return EmptyState(
              headline: 'No goals yet',
              subtext: 'Set savings goals to track your progress.',
              ctaLabel: 'Add Goal',
              onCtaPressed: () => showGoalSheet(context, ref),
            );
          }
          return _GoalList(goals: goals);
        },
        error: (err, _) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _GoalList extends ConsumerWidget {
  const _GoalList({required this.goals});

  final List<Goal> goals;

  /// No delete affordance exists on the goal detail screen, so this mirrors
  /// the recurring detail delete flow: confirm dialog, soft delete via the
  /// repo, then a success snackbar.
  Future<void> _deleteGoal(
    BuildContext context,
    WidgetRef ref,
    Goal goal,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: const Text(
          'This removes the goal. Contributions already made to your '
          'accounts are kept.',
        ),
        actions: [
          GhostButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(ctx, false),
            isExpanded: false,
          ),
          GhostButton(
            label: 'Delete',
            onPressed: () => Navigator.pop(ctx, true),
            isDanger: true,
            isExpanded: false,
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(goalRepoProvider)
        .update(
          GoalsCompanion(id: Value(goal.id), deletedAt: Value(DateTime.now())),
        );
    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      'Goal deleted.',
      variant: AppSnackBarVariant.success,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.pagePaddingMobile),
      itemCount: goals.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.space3),
      itemBuilder: (context, index) {
        final goal = goals[index];
        final progress = goal.progress / 100;
        final progressColor = progress >= 1.0
            ? lootrColors.success
            : progress >= 0.5
            ? Theme.of(context).colorScheme.primary
            : lootrColors.warning;

        return SwipeActionRow(
          rowKey: Key(goal.id),
          onEdit: () => showGoalSheet(context, ref, initial: goal),
          onDelete: () => _deleteGoal(context, ref, goal),
          child: Material(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/more/goals/${goal.id}'),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            goal.name,
                            style: AppTypography.h3.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          '${goal.progress.round()}%',
                          style: AppTypography.h3Mono.copyWith(
                            color: progressColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    BudgetProgressBar(
                      progress: progress.clamp(0.0, 1.0),
                      color: progressColor,
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: MoneyFormat.exactMoney(
                                  goal.exactCurrentAmount,
                                ),
                                style: AppTypography.mono.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: lootrColors.textSecondary,
                                ),
                              ),
                              TextSpan(
                                text: ' saved',
                                style: AppTypography.caption.copyWith(
                                  color: lootrColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'of ${MoneyFormat.exactMoney(goal.exactTargetAmount)}',
                          style: AppTypography.mono.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: lootrColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

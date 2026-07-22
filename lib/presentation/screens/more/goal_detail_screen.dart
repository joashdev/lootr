import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/accounts_provider.dart';
import '../../../application/providers/goal_contributions_provider.dart';
import '../../../application/providers/goal_detail_provider.dart';
import '../../../core/format/money_format.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/value_objects/exact_money.dart';
import '../../shared/components/empty_state.dart';
import '../../shared/components/buttons/primary_button.dart';
import 'more_form_sheets.dart';

class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalAsync = ref.watch(goalDetailProvider(id));
    final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
    final contributionsAsync = ref.watch(goalContributionsProvider(id));
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;
    final loadedGoal = goalAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Goal'),
        actions: [
          if (loadedGoal != null)
            IconButton(
              tooltip: 'Edit goal',
              icon: const Icon(LucideIcons.pencil, size: 20),
              onPressed: () => showGoalSheet(context, ref, initial: loadedGoal),
            ),
        ],
      ),
      body: goalAsync.when(
        data: (goal) {
          if (goal == null) {
            return const Center(child: Text('Goal not found'));
          }

          final progress = goal.progress / 100;
          final progressColor = progress >= 1.0
              ? lootrColors.success
              : progress >= 0.5
              ? colorScheme.primary
              : lootrColors.warning;
          final remaining = goal.exactTargetAmount - goal.exactCurrentAmount;
          final displayedRemaining = remaining.isNegative
              ? ExactMoney(
                  coefficient: BigInt.zero,
                  scale: remaining.scale,
                  currencyCode: remaining.currencyCode,
                )
              : remaining;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pagePaddingMobile,
              AppSpacing.pagePaddingMobile,
              AppSpacing.pagePaddingMobile,
              // Keep the trailing CTA clear of the floating bottom nav.
              AppSpacing.bottomNavClearance +
                  MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.space4),
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: CircularProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          strokeWidth: 12,
                          backgroundColor: colorScheme.surfaceContainerLow,
                          valueColor: AlwaysStoppedAnimation(progressColor),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${goal.progress.round()}%',
                            style: AppTypography.displayMono.copyWith(
                              color: progressColor,
                              fontSize: 28,
                            ),
                          ),
                          Text(
                            'complete',
                            style: AppTypography.caption.copyWith(
                              color: lootrColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.space6),
                Text(
                  goal.name,
                  style: AppTypography.h1.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.space6),
                _DetailCard(
                  label: 'Target',
                  value: MoneyFormat.exactMoney(goal.exactTargetAmount),
                  mono: true,
                ),
                const SizedBox(height: AppSpacing.space2),
                _DetailCard(
                  label: 'Saved',
                  value: MoneyFormat.exactMoney(goal.exactCurrentAmount),
                  mono: true,
                ),
                const SizedBox(height: AppSpacing.space2),
                _DetailCard(
                  label: 'Remaining',
                  value: MoneyFormat.exactMoney(displayedRemaining),
                  valueColor: !remaining.isZero && !remaining.isNegative
                      ? lootrColors.warning
                      : lootrColors.success,
                  mono: true,
                ),
                if (goal.targetDate != null) ...[
                  const SizedBox(height: AppSpacing.space2),
                  _DetailCard(
                    label: 'Target Date',
                    value: _formatDate(goal.targetDate!),
                  ),
                ],
                const SizedBox(height: AppSpacing.space6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Contribution History',
                    style: AppTypography.captionMedium.copyWith(
                      color: lootrColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
                contributionsAsync.when(
                  data: (contributions) {
                    if (contributions.isEmpty) {
                      return EmptyState(
                        headline: 'No contributions yet',
                        subtext:
                            'Add your first contribution to build momentum.',
                        ctaLabel: 'Add Contribution',
                        onCtaPressed: () => showGoalContributionSheet(
                          context,
                          ref,
                          goal,
                          accounts: accounts,
                        ),
                      );
                    }
                    return Column(
                      children: contributions
                          .map(
                            (contribution) =>
                                _ContributionRow(transaction: contribution),
                          )
                          .toList(),
                    );
                  },
                  error: (err, _) => Text(
                    'Unable to load contributions: $err',
                    style: AppTypography.body.copyWith(
                      color: lootrColors.textSecondary,
                    ),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.space2),
                    child: LinearProgressIndicator(),
                  ),
                ),
                const SizedBox(height: AppSpacing.space6),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: 'Add Contribution',
                    onPressed: () => showGoalContributionSheet(
                      context,
                      ref,
                      goal,
                      accounts: accounts,
                    ),
                    icon: const Icon(LucideIcons.plus, size: 20),
                  ),
                ),
              ],
            ),
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

class _ContributionRow extends StatelessWidget {
  const _ContributionRow({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(transaction.note ?? 'Contribution'),
      subtitle: Text(GoalDetailScreen._formatDate(transaction.occurredAt)),
      trailing: Text(
        MoneyFormat.exactMoney(transaction.exactAmount),
        style: AppTypography.mono.copyWith(color: lootrColors.expense),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.label,
    required this.value,
    this.valueColor,
    this.mono = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.body.copyWith(
              color: lootrColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: (mono ? AppTypography.mono : AppTypography.bodyMedium)
                .copyWith(color: valueColor ?? colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

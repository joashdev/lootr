import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/accounts_provider.dart';
import '../../../application/providers/payees_provider.dart';
import '../../../application/providers/recurring_provider.dart';
import '../../../application/providers/recurring_detail_provider.dart';
import '../../../core/format/money_format.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/entities/payee.dart';
import '../../../domain/entities/recurring_template.dart';
import '../../shared/components/app_snackbar.dart';
import '../../shared/components/buttons/ghost_button.dart';
import '../../shared/components/empty_state.dart';
import '../../shared/components/swipe_action_row.dart';
import 'more_form_sheets.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key, this.initialFilter});

  final String? initialFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringProvider);
    final occurrences =
        ref.watch(recurringOccurrencesProvider).asData?.value ??
        const <RecurringOccurrenceView>[];
    final subscriptionTemplateIdsAsync = ref.watch(
      subscriptionRecurringTemplateIdsProvider,
    );
    final hasRecurring = recurringAsync.asData?.value.isNotEmpty ?? false;
    final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
    final payees = ref.watch(payeesProvider).asData?.value ?? const <Payee>[];
    final payeeNames = {
      for (final payee in payees)
        payee.id: payee.displayName ?? payee.normalizedName,
    };

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Recurring'),
        actions: [
          if (hasRecurring)
            IconButton(
              tooltip: 'Add recurring item',
              onPressed: () =>
                  showRecurringSheet(context, ref, accounts: accounts),
              icon: const Icon(LucideIcons.plus),
            ),
        ],
      ),
      body: recurringAsync.when(
        data: (templates) {
          if (initialFilter == 'subscription') {
            return subscriptionTemplateIdsAsync.when(
              data: (subscriptionTemplateIds) => _buildTemplateState(
                context,
                ref,
                accounts: accounts,
                payeeNames: payeeNames,
                templates: templates
                    .where(
                      (template) =>
                          subscriptionTemplateIds.contains(template.id),
                    )
                    .toList(),
                occurrences: occurrences,
              ),
              error: (err, _) => Center(child: Text('Error: $err')),
              loading: () => const Center(child: CircularProgressIndicator()),
            );
          }

          return _buildTemplateState(
            context,
            ref,
            accounts: accounts,
            payeeNames: payeeNames,
            templates: templates,
            occurrences: occurrences,
          );
        },
        error: (err, _) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildTemplateState(
    BuildContext context,
    WidgetRef ref, {
    required List<Account> accounts,
    required Map<String, String> payeeNames,
    required List<RecurringTemplate> templates,
    required List<RecurringOccurrenceView> occurrences,
  }) {
    if (templates.isEmpty) {
      return EmptyState(
        headline: initialFilter == 'subscription'
            ? 'No subscriptions found'
            : 'No recurring items',
        subtext: initialFilter == 'subscription'
            ? 'Subscription reminders appear here when a recurring item is tagged like a subscription.'
            : 'Set up recurring transactions for bills and subscriptions.',
        ctaLabel: initialFilter == 'subscription'
            ? 'View All Recurring'
            : 'Add Recurring',
        onCtaPressed: () => initialFilter == 'subscription'
            ? context.go('/more/recurring')
            : showRecurringSheet(context, ref, accounts: accounts),
      );
    }

    return _RecurringList(
      templates: templates,
      occurrencesByTemplate: {
        for (final template in templates)
          template.id: occurrences
              .where(
                (occurrence) => occurrence.recurringTemplateId == template.id,
              )
              .toList(),
      },
      payeeNames: payeeNames,
      accounts: accounts,
    );
  }
}

class _RecurringList extends ConsumerWidget {
  const _RecurringList({
    required this.templates,
    required this.payeeNames,
    required this.accounts,
    required this.occurrencesByTemplate,
  });

  final List<RecurringTemplate> templates;
  final Map<String, String> payeeNames;
  final List<Account> accounts;
  final Map<String, List<RecurringOccurrenceView>> occurrencesByTemplate;

  /// Same confirm + soft delete flow as the recurring detail screen.
  Future<void> _deleteTemplate(
    BuildContext context,
    WidgetRef ref,
    RecurringTemplate template,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recurring?'),
        content: const Text(
          'This stops future auto-created transactions. Existing '
          'transactions are kept.',
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
        .read(recurringOccurrenceCommandsProvider)
        .deleteSeries(template.id);
    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      'Recurring item deleted.',
      variant: AppSnackBarVariant.success,
    );
  }

  String _frequencyLabel(String rule) {
    switch (rule) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'biweekly':
        return 'Biweekly';
      case 'monthly':
        return 'Monthly';
      case 'quarterly':
        return 'Quarterly';
      case 'yearly':
        return 'Yearly';
      default:
        return rule;
    }
  }

  String _nextDateLabel(DateTime? next) {
    if (next == null) return 'Paused';
    final now = DateTime.now();
    final diff = next.difference(now);
    if (diff.inDays < 0) return 'Overdue';
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Tomorrow';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return _formatDate(next);
  }

  String _occurrenceLabel(
    RecurringTemplate template,
    List<RecurringOccurrenceView> occurrences,
  ) {
    final actionable =
        occurrences
            .where(
              (occurrence) =>
                  occurrence.status == 'due' || occurrence.status == 'unpaid',
            )
            .toList()
          ..sort((left, right) => left.dueAt.compareTo(right.dueAt));
    if (actionable.isEmpty) return _nextDateLabel(template.nextOccurrenceAt);
    final occurrence = actionable.first;
    if (occurrence.status == 'unpaid' ||
        occurrence.dueAt.isBefore(DateTime.now())) {
      return 'Overdue · ${_formatDate(occurrence.dueAt)}';
    }
    final now = DateTime.now();
    final sameDay =
        occurrence.dueAt.year == now.year &&
        occurrence.dueAt.month == now.month &&
        occurrence.dueAt.day == now.day;
    return sameDay
        ? 'Due today'
        : 'Upcoming · ${_formatDate(occurrence.dueAt)}';
  }

  String _formatDate(DateTime dt) {
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
    return '${months[dt.month]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.separated(
      padding: const EdgeInsets.only(
        top: AppSpacing.space2,
        bottom: AppSpacing.space10,
      ),
      itemCount: templates.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: AppSpacing.pagePaddingMobile,
        color: lootrColors.borderSubtle,
      ),
      itemBuilder: (context, index) {
        final t = templates[index];
        return SwipeActionRow(
          rowKey: Key(t.id),
          onEdit: () => showRecurringSheet(
            context,
            ref,
            accounts: accounts,
            initial: t,
            initialPayeeName: t.payeeId == null ? null : payeeNames[t.payeeId!],
          ),
          onDelete: () => _deleteTemplate(context, ref, t),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePaddingMobile,
            ),
            leading: Icon(
              LucideIcons.repeat,
              color: t.autoCreateDisabled
                  ? lootrColors.textTertiary
                  : colorScheme.primary,
            ),
            title: Text(
              t.payeeId != null
                  ? (payeeNames[t.payeeId!] ?? 'Recurring')
                  : 'Recurring',
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              _frequencyLabel(t.recurrenceRule),
              style: AppTypography.caption.copyWith(
                color: lootrColors.textSecondary,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  MoneyFormat.exactMoney(t.exactAmount),
                  style: AppTypography.mono.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  _occurrenceLabel(
                    t,
                    occurrencesByTemplate[t.id] ??
                        const <RecurringOccurrenceView>[],
                  ),
                  style: AppTypography.caption.copyWith(
                    color: t.autoCreateDisabled
                        ? lootrColors.textTertiary
                        : lootrColors.textSecondary,
                  ),
                ),
              ],
            ),
            onTap: () => context.push('/more/recurring/${t.id}'),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/accounts_provider.dart';
import '../../../application/providers/payees_provider.dart';
import '../../../application/providers/recurring_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/entities/payee.dart';
import '../../../domain/entities/recurring_template.dart';
import '../../shared/components/empty_state.dart';
import 'more_form_sheets.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringProvider);
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
          if (templates.isEmpty) {
            return EmptyState(
              headline: 'No recurring items',
              subtext:
                  'Set up recurring transactions for bills and subscriptions.',
              ctaLabel: 'Add Recurring',
              onCtaPressed: () =>
                  showRecurringSheet(context, ref, accounts: accounts),
            );
          }
          return _RecurringList(templates: templates, payeeNames: payeeNames);
        },
        error: (err, _) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _RecurringList extends StatelessWidget {
  const _RecurringList({required this.templates, required this.payeeNames});

  final List<RecurringTemplate> templates;
  final Map<String, String> payeeNames;

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
  Widget build(BuildContext context) {
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
        final amount = t.amount;

        return ListTile(
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
                '₱${amount.toStringAsFixed(2)}',
                style: AppTypography.mono.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                _nextDateLabel(t.nextOccurrenceAt),
                style: AppTypography.caption.copyWith(
                  color: t.autoCreateDisabled
                      ? lootrColors.textTertiary
                      : lootrColors.textSecondary,
                ),
              ),
            ],
          ),
          onTap: () => context.push('/more/recurring/${t.id}'),
        );
      },
    );
  }
}

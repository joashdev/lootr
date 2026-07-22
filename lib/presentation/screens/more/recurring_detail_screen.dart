import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/accounts_provider.dart';
import '../../../application/providers/categories_provider.dart';
import '../../../application/providers/notification_provider.dart';
import '../../../application/providers/payees_provider.dart';
import '../../../application/providers/repo_providers.dart';
import '../../../application/providers/recurring_detail_provider.dart';
import '../../../core/format/money_format.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/entities/payee.dart';
import 'more_form_sheets.dart';
import '../../shared/components/app_snackbar.dart';
import '../../shared/components/buttons/ghost_button.dart';
import '../../shared/components/buttons/secondary_button.dart';

class RecurringDetailScreen extends ConsumerWidget {
  const RecurringDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(recurringDetailProvider(id));
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    final payees = ref.watch(payeesProvider).asData?.value ?? const <Payee>[];
    final categories =
        ref.watch(categoriesProvider).asData?.value ?? const <Category>[];
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;
    final payeeNames = {
      for (final payee in payees) payee.id: payee.resolvedName,
    };

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Recurring')),
      body: detailAsync.when(
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Recurring not found'));
          }

          final template = detail.template;
          final transactions = detail.transactions;
          final isDisabled = template.autoCreateDisabled;
          final accountNames = {
            for (final account in accounts) account.id: account.name,
          };
          final categoryNames = {
            for (final category in categories) category.id: category.name,
          };

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.pagePaddingMobile),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(
                        label: 'Payee',
                        value: template.payeeId != null
                            ? (payeeNames[template.payeeId!] ?? 'Not set')
                            : 'Not set',
                      ),
                      const SizedBox(height: AppSpacing.space2),
                      _DetailRow(
                        label: 'Amount',
                        value: MoneyFormat.exactMoney(template.exactAmount),
                        mono: true,
                      ),
                      const SizedBox(height: AppSpacing.space2),
                      _DetailRow(
                        label: 'Account',
                        value:
                            accountNames[template.accountId] ??
                            template.accountId,
                      ),
                      const SizedBox(height: AppSpacing.space2),
                      _DetailRow(
                        label: 'Category',
                        value: template.categoryId != null
                            ? (categoryNames[template.categoryId!] ??
                                  template.categoryId!)
                            : 'Not set',
                      ),
                      const SizedBox(height: AppSpacing.space2),
                      _DetailRow(
                        label: 'Frequency',
                        value: _frequencyLabel(template.recurrenceRule),
                      ),
                      const SizedBox(height: AppSpacing.space2),
                      _DetailRow(
                        label: 'Next Occurrence',
                        value: template.nextOccurrenceAt != null
                            ? DateFormat(
                                'MMM d, yyyy',
                              ).format(template.nextOccurrenceAt!)
                            : 'Paused',
                        valueColor:
                            template.nextOccurrenceAt != null &&
                                template.nextOccurrenceAt!.isBefore(
                                  DateTime.now(),
                                )
                            ? lootrColors.danger
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.space2),
                      _DetailRow(
                        label: 'Status',
                        value: isDisabled ? 'Disabled' : 'Active',
                        valueColor: isDisabled
                            ? lootrColors.textTertiary
                            : lootrColors.success,
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
                    'Transaction History',
                    style: AppTypography.captionMedium.copyWith(
                      color: lootrColors.textSecondary,
                    ),
                  ),
                ),
              ),
              if (transactions.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.space8),
                    child: Text(
                      'No transactions generated yet.',
                      style: AppTypography.body.copyWith(
                        color: lootrColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final tx = transactions[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.pagePaddingMobile,
                      ),
                      title: Text(
                        formatDate(tx.occurredAt),
                        style: AppTypography.bodyMedium.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      trailing: Text(
                        MoneyFormat.exactMoney(tx.exactAmount),
                        style: AppTypography.mono.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    );
                  }, childCount: transactions.length),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePaddingMobile,
                    AppSpacing.space6,
                    AppSpacing.pagePaddingMobile,
                    AppSpacing.space8,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              label: 'Edit',
                              icon: const Icon(LucideIcons.pencil, size: 18),
                              onPressed: () => showRecurringSheet(
                                context,
                                ref,
                                accounts: accounts,
                                initial: template,
                                initialPayeeName: template.payeeId == null
                                    ? null
                                    : payeeNames[template.payeeId!],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space3),
                          Expanded(
                            child: SecondaryButton(
                              label: 'Delete',
                              icon: const Icon(LucideIcons.trash2, size: 18),
                              isDanger: true,
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Recurring?'),
                                    content: const Text(
                                      'This stops future auto-created '
                                      'transactions. Existing transactions '
                                      'are kept.',
                                    ),
                                    actions: [
                                      GhostButton(
                                        label: 'Cancel',
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        isExpanded: false,
                                      ),
                                      GhostButton(
                                        label: 'Delete',
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        isDanger: true,
                                        isExpanded: false,
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;
                                await ref
                                    .read(recurringRepoProvider)
                                    .softDelete(template.id);
                                await ref
                                    .read(notificationSchedulerProvider)
                                    .rebuildSchedule();
                                if (!context.mounted) return;
                                AppSnackBar.show(
                                  context,
                                  'Recurring item deleted.',
                                  variant: AppSnackBarVariant.success,
                                );
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space3),
                      SecondaryButton(
                        label: isDisabled ? 'Enable' : 'Disable',
                        icon: Icon(
                          isDisabled ? LucideIcons.play : LucideIcons.pause,
                          size: 18,
                        ),
                        onPressed: () async {
                          await ref
                              .read(recurringRepoProvider)
                              .update(
                                RecurringTemplatesCompanion(
                                  id: Value(template.id),
                                  autoCreateDisabled: Value(
                                    !template.autoCreateDisabled,
                                  ),
                                ),
                              );
                          await ref
                              .read(notificationSchedulerProvider)
                              .rebuildSchedule();
                          if (!context.mounted) return;
                          AppSnackBar.show(
                            context,
                            template.autoCreateDisabled
                                ? 'Recurring item enabled.'
                                : 'Recurring item disabled.',
                            variant: AppSnackBarVariant.success,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        error: (err, _) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  static String _frequencyLabel(String rule) {
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

  static String formatDate(DateTime dt) {
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.body.copyWith(color: lootrColors.textSecondary),
        ),
        Text(
          value,
          style: (mono ? AppTypography.mono : AppTypography.bodyMedium)
              .copyWith(color: valueColor ?? colorScheme.onSurface),
        ),
      ],
    );
  }
}

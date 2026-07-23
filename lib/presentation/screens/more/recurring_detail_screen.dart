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
import '../../../domain/value_objects/exact_money.dart';
import 'more_form_sheets.dart';
import '../../shared/components/app_snackbar.dart';
import '../../shared/components/buttons/ghost_button.dart';
import '../../shared/components/buttons/secondary_button.dart';

class RecurringDetailScreen extends ConsumerWidget {
  const RecurringDetailScreen({
    super.key,
    required this.id,
    this.highlightedOccurrenceId,
  });

  final String id;
  final String? highlightedOccurrenceId;

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
          final occurrences = detail.occurrences;
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
                    'Occurrence History',
                    style: AppTypography.captionMedium.copyWith(
                      color: lootrColors.textSecondary,
                    ),
                  ),
                ),
              ),
              if (occurrences.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.space8),
                    child: Text(
                      'No occurrences recorded yet.',
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
                    final occurrence = occurrences[index];
                    return Container(
                      color: occurrence.id == highlightedOccurrenceId
                          ? colorScheme.primaryContainer.withValues(alpha: 0.35)
                          : null,
                      child: _OccurrenceTile(
                        occurrence: occurrence,
                        onPay: _isActionable(occurrence)
                            ? () => _payOccurrence(context, ref, occurrence)
                            : null,
                        onSkip: _isActionable(occurrence)
                            ? () => _skipOccurrence(context, ref, occurrence)
                            : null,
                        onEdit: _isActionable(occurrence)
                            ? () => _editOccurrence(context, ref, occurrence)
                            : null,
                      ),
                    );
                  }, childCount: occurrences.length),
                ),
              if (transactions.any(
                (transaction) => !occurrences.any(
                  (occurrence) => occurrence.transactionId == transaction.id,
                ),
              ))
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePaddingMobile,
                      AppSpacing.space3,
                      AppSpacing.pagePaddingMobile,
                      AppSpacing.space1,
                    ),
                    child: Text(
                      'Other Series Transactions',
                      style: AppTypography.captionMedium.copyWith(
                        color: lootrColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              SliverList(
                delegate: SliverChildListDelegate(
                  transactions
                      .where(
                        (transaction) => !occurrences.any(
                          (occurrence) =>
                              occurrence.transactionId == transaction.id,
                        ),
                      )
                      .map(
                        (transaction) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.pagePaddingMobile,
                          ),
                          title: Text(formatDate(transaction.occurredAt)),
                          subtitle: const Text('Finalized transaction'),
                          trailing: Text(
                            MoneyFormat.exactMoney(transaction.exactAmount),
                            style: AppTypography.mono,
                          ),
                        ),
                      )
                      .toList(),
                ),
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
                              label: 'Edit Series',
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

  static bool _isActionable(RecurringOccurrenceData occurrence) =>
      occurrence.status == 'due' || occurrence.status == 'unpaid';

  Future<void> _payOccurrence(
    BuildContext context,
    WidgetRef ref,
    RecurringOccurrenceData occurrence,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark occurrence paid?'),
        content: const Text(
          'This creates one finalized ledger transaction for this occurrence.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Pay'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(recurringOccurrenceServiceProvider).pay(occurrence.id);
      await ref.read(notificationSchedulerProvider).rebuildSchedule();
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        'Occurrence paid and transaction created.',
        variant: AppSnackBarVariant.success,
      );
    } catch (error) {
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        'Occurrence could not be paid. No changes were applied.',
        variant: AppSnackBarVariant.error,
      );
    }
  }

  Future<void> _skipOccurrence(
    BuildContext context,
    WidgetRef ref,
    RecurringOccurrenceData occurrence,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Skip this occurrence?'),
        content: const Text(
          'This occurrence will be kept in history. No transaction is created.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(recurringOccurrenceServiceProvider).skip(occurrence.id);
      await ref.read(notificationSchedulerProvider).rebuildSchedule();
      if (!context.mounted) return;
      AppSnackBar.show(context, 'Occurrence skipped.');
    } catch (_) {
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        'Occurrence could not be skipped. No changes were applied.',
        variant: AppSnackBarVariant.error,
      );
    }
  }

  Future<void> _editOccurrence(
    BuildContext context,
    WidgetRef ref,
    RecurringOccurrenceData occurrence,
  ) async {
    final amount = ExactMoney(
      coefficient: BigInt.parse(occurrence.amountAtoms),
      scale: occurrence.amountScale,
      currencyCode: occurrence.currencyCode,
    );
    final amountController = TextEditingController(
      text: amount.toDecimalString(),
    );
    var dueAt = occurrence.dueAt;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pagePaddingMobile,
            AppSpacing.space5,
            AppSpacing.pagePaddingMobile,
            MediaQuery.viewInsetsOf(context).bottom + AppSpacing.space5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Occurrence',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.space4),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount (${occurrence.currencyCode})',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.space3),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Due date'),
                subtitle: Text(DateFormat('MMM d, yyyy').format(dueAt)),
                trailing: const Icon(LucideIcons.calendar),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: dueAt,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (selected != null) {
                    setState(
                      () => dueAt = DateTime(
                        selected.year,
                        selected.month,
                        selected.day,
                        dueAt.hour,
                        dueAt.minute,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: AppSpacing.space4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    try {
                      final edited = ExactMoney.parse(
                        amountController.text,
                        occurrence.currencyCode,
                      ).rescale(occurrence.amountScale);
                      if (edited.isNegative || edited.isZero) {
                        throw const FormatException();
                      }
                      await ref
                          .read(recurringOccurrenceRepoProvider)
                          .updateOccurrence(
                            id: occurrence.id,
                            dueAt: dueAt,
                            amountAtoms: edited.coefficient.toString(),
                            amountScale: edited.scale,
                            currencyCode: edited.currencyCode,
                          );
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                    } catch (_) {
                      AppSnackBar.show(
                        sheetContext,
                        'Enter a valid amount at the existing precision.',
                        variant: AppSnackBarVariant.warning,
                      );
                    }
                  },
                  child: const Text('Save Occurrence'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    amountController.dispose();
  }
}

class _OccurrenceTile extends StatelessWidget {
  const _OccurrenceTile({
    required this.occurrence,
    required this.onPay,
    required this.onSkip,
    required this.onEdit,
  });

  final RecurringOccurrenceData occurrence;
  final VoidCallback? onPay;
  final VoidCallback? onSkip;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final money = ExactMoney(
      coefficient: BigInt.parse(occurrence.amountAtoms),
      scale: occurrence.amountScale,
      currencyCode: occurrence.currencyCode,
    );
    final status = _statusLabel(occurrence, DateTime.now());
    final changedDueDate = occurrence.originalDueAt != occurrence.dueAt;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingMobile,
        vertical: AppSpacing.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('MMM d, yyyy').format(occurrence.dueAt),
                  style: AppTypography.bodyMedium,
                ),
              ),
              Text(MoneyFormat.exactMoney(money), style: AppTypography.mono),
            ],
          ),
          const SizedBox(height: AppSpacing.space1),
          Text(
            changedDueDate
                ? '$status · originally due '
                      '${DateFormat('MMM d, yyyy').format(occurrence.originalDueAt)}'
                : status,
            style: AppTypography.caption.copyWith(
              color: context.lootrColors.textSecondary,
            ),
          ),
          if (onPay != null || onSkip != null || onEdit != null) ...[
            const SizedBox(height: AppSpacing.space2),
            Wrap(
              spacing: AppSpacing.space2,
              children: [
                if (onPay != null)
                  FilledButton.tonal(
                    onPressed: onPay,
                    child: const Text('Pay'),
                  ),
                if (onSkip != null)
                  OutlinedButton(onPressed: onSkip, child: const Text('Skip')),
                if (onEdit != null)
                  TextButton(
                    onPressed: onEdit,
                    child: const Text('Edit occurrence'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(RecurringOccurrenceData occurrence, DateTime now) {
    return switch (occurrence.status) {
      'paid' => 'Paid',
      'skipped' => 'Skipped',
      'dismissed' => 'Dismissed',
      'unpaid' => 'Overdue',
      'due' when occurrence.dueAt.isAfter(now) => 'Upcoming',
      'due' => 'Due',
      _ => occurrence.status,
    };
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

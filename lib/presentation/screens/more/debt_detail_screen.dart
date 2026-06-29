import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/accounts_provider.dart';
import '../../../application/providers/debt_payments_provider.dart';
import '../../../application/providers/debt_detail_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/value_objects/field_types.dart';
import '../../shared/components/progress/budget_progress_bar.dart';
import 'more_form_sheets.dart';

class DebtDetailScreen extends ConsumerWidget {
  const DebtDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtAsync = ref.watch(debtDetailProvider(id));
    final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
    final paymentsAsync = ref.watch(debtPaymentsProvider(id));
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Debt Detail')),
      body: debtAsync.when(
        data: (debt) {
          if (debt == null) {
            return const Center(child: Text('Debt not found'));
          }

          final isLent = debt.debtDirection == DebtDirection.lent;
          final progress = debt.amount > 0
              ? (1 - (debt.remainingBalance / debt.amount))
              : 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.pagePaddingMobile),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Icon(
                        isLent
                            ? LucideIcons.arrowUpRight
                            : LucideIcons.arrowDownLeft,
                        size: 48,
                        color: isLent
                            ? lootrColors.income
                            : lootrColors.expense,
                      ),
                      const SizedBox(height: AppSpacing.space3),
                      Text(
                        debt.counterpartyName,
                        style: AppTypography.h1.copyWith(
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.space1),
                      Text(
                        isLent ? 'You lent' : 'You borrowed',
                        style: AppTypography.captionMedium.copyWith(
                          color: lootrColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.space6),
                _DetailRow(
                  label: 'Total Amount',
                  value: '₱${debt.amount.toStringAsFixed(2)}',
                  mono: true,
                ),
                const SizedBox(height: AppSpacing.space2),
                _DetailRow(
                  label: 'Remaining',
                  value: '₱${debt.remainingBalance.toStringAsFixed(2)}',
                  valueColor: debt.remainingBalance > 0
                      ? lootrColors.warning
                      : lootrColors.success,
                  mono: true,
                ),
                if (debt.dueDate != null) ...[
                  const SizedBox(height: AppSpacing.space2),
                  _DetailRow(
                    label: 'Due Date',
                    value: _formatDate(debt.dueDate!),
                  ),
                ],
                const SizedBox(height: AppSpacing.space4),
                BudgetProgressBar(progress: progress.clamp(0.0, 1.0)),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.space1),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${(progress * 100).round()}%',
                          style: AppTypography.mono.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: lootrColors.textSecondary,
                          ),
                        ),
                        TextSpan(
                          text: ' paid',
                          style: AppTypography.caption.copyWith(
                            color: lootrColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (debt.note != null && debt.note!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    'Note',
                    style: AppTypography.captionMedium.copyWith(
                      color: lootrColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space1),
                  Text(
                    debt.note!,
                    style: AppTypography.body.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.space6),
                Text(
                  'Related Payments',
                  style: AppTypography.captionMedium.copyWith(
                    color: lootrColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
                paymentsAsync.when(
                  data: (payments) {
                    if (payments.isEmpty) {
                      return Text(
                        'No linked payments yet.',
                        style: AppTypography.body.copyWith(
                          color: lootrColors.textSecondary,
                        ),
                      );
                    }
                    return Column(
                      children: payments
                          .map((payment) => _PaymentRow(transaction: payment))
                          .toList(),
                    );
                  },
                  error: (err, _) => Text(
                    'Unable to load payments: $err',
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
                if (debt.status != DebtStatus.settled)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => showDebtPaymentSheet(
                            context,
                            ref,
                            debt,
                            accounts: accounts,
                            settle: true,
                          ),
                          child: const Text('Settle'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space3),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => showDebtPaymentSheet(
                            context,
                            ref,
                            debt,
                            accounts: accounts,
                            settle: false,
                          ),
                          child: const Text('Partial Pay'),
                        ),
                      ),
                    ],
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

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    final amountColor = transaction.direction == TransactionDirection.income
        ? lootrColors.income
        : lootrColors.expense;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(DebtDetailScreen._formatDate(transaction.occurredAt)),
      subtitle: Text(transaction.note ?? 'Debt payment'),
      trailing: Text(
        '₱${transaction.amount.toStringAsFixed(2)}',
        style: AppTypography.mono.copyWith(color: amountColor),
      ),
    );
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/shadows.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../domain/entities/transaction.dart';

class TransactionDetailCard extends StatelessWidget {
  const TransactionDetailCard({
    super.key,
    required this.transaction,
    required this.accountName,
    this.categoryName,
    this.payeeName,
    this.parentInfo,
    this.recurringInfo,
    this.transferInfo,
    this.metadata,
  });

  final Transaction transaction;
  final String accountName;
  final String? categoryName;
  final String? payeeName;
  final String? parentInfo;
  final String? recurringInfo;
  final String? transferInfo;
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy \u00b7 h:mm a');

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailSection(
            title: 'Details',
            children: [
              _DetailRow(label: 'Account', value: accountName),
              if (categoryName != null)
                _DetailRow(label: 'Category', value: categoryName!),
              if (payeeName != null)
                _DetailRow(label: 'Payee', value: payeeName!),
              _DetailRow(
                label: 'Date',
                value: dateFormat.format(transaction.occurredAt),
              ),
              if (transaction.note != null && transaction.note!.isNotEmpty)
                _DetailRow(label: 'Note', value: transaction.note!),
            ],
          ),
          if (parentInfo != null ||
              recurringInfo != null ||
              transferInfo != null ||
              (metadata?.isNotEmpty ?? false)) ...[
            const SizedBox(height: AppSpacing.space4),
            _DetailSection(
              title: 'Metadata',
              children: [
                if (parentInfo != null)
                  _DetailRow(label: 'Parent', value: parentInfo!),
                if (recurringInfo != null)
                  _DetailRow(label: 'Recurring', value: recurringInfo!),
                if (transferInfo != null)
                  _DetailRow(label: 'Transfer', value: transferInfo!),
                for (final entry
                    in metadata?.entries ?? const <MapEntry<String, dynamic>>[])
                  _DetailRow(label: entry.key, value: entry.value.toString()),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: isDark ? null : AppShadows.sm,
        border: isDark
            ? Border.all(color: colorScheme.outlineVariant, width: 0.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: AppTypography.captionMedium.copyWith(
                color: context.lootrColors.textSecondary,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                color: context.lootrColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.body.copyWith(color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/debts_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/entities/debt_record.dart';
import '../../../domain/value_objects/field_types.dart';
import '../../shared/components/badges/status_badge.dart';
import '../../shared/components/empty_state.dart';
import 'more_form_sheets.dart';

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsProvider);
    final hasDebts = debtsAsync.asData?.value.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Debts & Lending'),
        actions: [
          if (hasDebts)
            IconButton(
              tooltip: 'Add debt',
              onPressed: () => showDebtSheet(context, ref),
              icon: const Icon(LucideIcons.plus),
            ),
        ],
      ),
      body: debtsAsync.when(
        data: (debts) {
          if (debts.isEmpty) {
            return EmptyState(
              headline: 'No debts yet',
              subtext: 'Track money you lent or borrowed here.',
              ctaLabel: 'Add Debt',
              onCtaPressed: () => showDebtSheet(context, ref),
            );
          }
          return _DebtList(debts: debts);
        },
        error: (err, _) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _DebtList extends StatelessWidget {
  const _DebtList({required this.debts});

  final List<DebtRecord> debts;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<DebtRecord>>{
      'active': [],
      'partially_paid': [],
      'settled': [],
    };

    for (final d in debts) {
      if (d.deletedAt != null) continue;
      groups[d.status]?.add(d);
    }

    final orderedStatuses = ['active', 'partially_paid', 'settled'];
    final statusLabels = {
      'active': 'Active',
      'partially_paid': 'Partially Paid',
      'settled': 'Settled',
    };

    final sections = <Widget>[];
    for (final status in orderedStatuses) {
      final items = groups[status];
      if (items == null || items.isEmpty) continue;
      sections.add(
        _DebtSection(statusLabel: statusLabels[status]!, debts: items),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.space10),
      children: sections,
    );
  }
}

class _DebtSection extends StatelessWidget {
  const _DebtSection({required this.statusLabel, required this.debts});

  final String statusLabel;
  final List<DebtRecord> debts;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePaddingMobile,
            AppSpacing.space3,
            AppSpacing.pagePaddingMobile,
            AppSpacing.space1,
          ),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Text(
            statusLabel,
            style: AppTypography.captionMedium.copyWith(
              color: lootrColors.textSecondary,
            ),
          ),
        ),
        ...debts.map((d) => _DebtRow(debt: d)),
      ],
    );
  }
}

class _DebtRow extends StatelessWidget {
  const _DebtRow({required this.debt});

  final DebtRecord debt;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;
    final isLent = debt.debtDirection == DebtDirection.lent;
    final isSettled = debt.status == DebtStatus.settled;
    final statusColor = debt.status == DebtStatus.active
        ? StatusBadgeColor.warning
        : debt.status == DebtStatus.partiallyPaid
        ? StatusBadgeColor.warning
        : StatusBadgeColor.success;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingMobile,
      ),
      leading: Icon(
        isLent ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft,
        color: isLent ? lootrColors.income : lootrColors.expense,
      ),
      title: Text(
        debt.counterpartyName,
        style: AppTypography.bodyMedium.copyWith(color: colorScheme.onSurface),
      ),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isLent ? 'You lent' : 'You borrowed',
            style: AppTypography.caption.copyWith(
              color: lootrColors.textSecondary,
            ),
          ),
          if (!isSettled) ...[
            const SizedBox(width: AppSpacing.space1),
            StatusBadge(
              label: debt.status == DebtStatus.active ? 'Active' : 'Partial',
              color: statusColor,
            ),
          ],
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '₱${debt.remainingBalance.toStringAsFixed(2)}',
            style: AppTypography.mono.copyWith(
              color: isSettled
                  ? lootrColors.textTertiary
                  : colorScheme.onSurface,
            ),
          ),
          Text(
            'of ₱${debt.amount.toStringAsFixed(2)}',
            style: AppTypography.caption.copyWith(
              color: lootrColors.textTertiary,
            ),
          ),
        ],
      ),
      onTap: () => context.push('/more/debts/${debt.id}'),
    );
  }
}

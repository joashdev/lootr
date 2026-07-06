import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/payee_detail_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../shared/components/empty_state.dart';

class PayeesScreen extends ConsumerWidget {
  const PayeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payeesAsync = ref.watch(payeeSummariesProvider);

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Payees')),
      body: payeesAsync.when(
        data: (summaries) {
          if (summaries.isEmpty) {
            return EmptyState(
              headline: 'No payees yet',
              subtext:
                  'Payees are created automatically when you add transactions.',
              ctaLabel: 'Add Transaction',
              onCtaPressed: () => context.push('/transactions/new'),
            );
          }

          return _PayeeList(payees: summaries);
        },
        error: (err, _) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _PayeeList extends StatelessWidget {
  const _PayeeList({required this.payees});

  final List<PayeeSummary> payees;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.separated(
      padding: const EdgeInsets.only(
        top: AppSpacing.space2,
        bottom: AppSpacing.space8,
      ),
      itemCount: payees.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: AppSpacing.pagePaddingMobile,
        color: lootrColors.borderSubtle,
      ),
      itemBuilder: (context, index) {
        final payee = payees[index];
        final displayName = payee.payee.resolvedName;
        final initial = displayName[0].toUpperCase();

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePaddingMobile,
          ),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
            child: Text(
              initial,
              style: AppTypography.captionMedium.copyWith(
                color: colorScheme.primary,
              ),
            ),
          ),
          title: Text(
            displayName,
            style: AppTypography.bodyMedium.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            payee.lastUsedAt == null
                ? '${payee.transactionCount} transactions'
                : 'Last used ${_formatDate(payee.lastUsedAt!)}',
            style: AppTypography.caption.copyWith(
              color: lootrColors.textSecondary,
            ),
          ),
          trailing: Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: lootrColors.textTertiary,
          ),
          onTap: () => context.push('/more/payees/${payee.payee.id}'),
        );
      },
    );
  }

  String _formatDate(DateTime value) {
    return '${value.month}/${value.day}/${value.year}';
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../application/providers/accounts_provider.dart';
import '../../../../application/providers/categories_provider.dart';
import '../../../../application/providers/transaction_filters_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../domain/entities/account.dart';
import '../../../../domain/entities/category.dart';
import '../../../../domain/value_objects/transaction_filters.dart';

class FilterChipBar extends ConsumerWidget {
  const FilterChipBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(transactionFiltersProvider);
    final accounts = ref.watch(accountsProvider);
    final categories = ref.watch(categoriesProvider);
    final chips = _buildChips(filters, accounts, categories, ref);
    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePaddingMobile),
              itemCount: chips.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.space2),
              itemBuilder: (context, index) {
                if (index < chips.length) return chips[index];
                return _ClearAllChip(
                  onTap: () => ref.read(transactionFiltersProvider.notifier).reset(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChips(TransactionFilters filters, AsyncValue<List<Account>> accounts,
      AsyncValue<List<Category>> categories, WidgetRef ref) {
    final chips = <Widget>[];

    if (filters.direction != null) {
      chips.add(_FilterChip(
        label: 'Direction: ${_directionLabel(filters.direction!)}',
        onRemove: () => ref.read(transactionFiltersProvider.notifier).setDirection(null),
      ));
    }

    if (filters.mode != null) {
      chips.add(_FilterChip(
        label: 'Mode: ${_modeLabel(filters.mode!)}',
        onRemove: () => ref.read(transactionFiltersProvider.notifier).setMode(null),
      ));
    }

    if (filters.accountId != null && accounts is AsyncData) {
      final value = accounts.value;
      if (value != null) {
        final name = value.where((a) => a.id == filters.accountId).map((a) => a.name).firstOrNull;
        if (name != null) {
          chips.add(_FilterChip(
            label: 'Account: $name',
            onRemove: () => ref.read(transactionFiltersProvider.notifier).setAccountId(null),
          ));
        }
      }
    }

    if (filters.categoryId != null && categories is AsyncData) {
      final value = categories.value;
      if (value != null) {
        final name = value.where((c) => c.id == filters.categoryId).map((c) => c.name).firstOrNull;
        if (name != null) {
          chips.add(_FilterChip(
            label: 'Category: $name',
            onRemove: () => ref.read(transactionFiltersProvider.notifier).setCategoryId(null),
          ));
        }
      }
    }

    if (filters.minAmount != null || filters.maxAmount != null) {
      final min = filters.minAmount?.toStringAsFixed(0) ?? '';
      final max = filters.maxAmount?.toStringAsFixed(0) ?? '';
      chips.add(_FilterChip(
        label: 'Amount: \u20B1$min\u2014\u20B1$max',
        onRemove: () => ref.read(transactionFiltersProvider.notifier).setAmountRange(null, null),
      ));
    }

    if (filters.dateRange != null) {
      final start = _formatDate(filters.dateRange!.start);
      final end = _formatDate(filters.dateRange!.end);
      chips.add(_FilterChip(
        label: 'Date: $start \u2014 $end',
        onRemove: () => ref.read(transactionFiltersProvider.notifier).setDateRange(null),
      ));
    }

    return chips;
  }

  String _directionLabel(String d) {
    switch (d) {
      case 'expense': return 'Expense';
      case 'income': return 'Income';
      case 'transfer': return 'Transfer';
      default: return d;
    }
  }

  String _modeLabel(String m) {
    switch (m) {
      case 'one_time': return 'One-time';
      case 'recurring': return 'Recurring';
      case 'installment': return 'Installment';
      case 'debt': return 'Debt';
      default: return m;
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}';
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space3, vertical: AppSpacing.space1),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        border: Border.all(color: AppColors.primary200),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTypography.captionMedium.copyWith(color: AppColors.primary700)),
          const SizedBox(width: AppSpacing.space1),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: AppColors.primary700),
          ),
        ],
      ),
    );
  }
}

class _ClearAllChip extends StatelessWidget {
  const _ClearAllChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2, vertical: AppSpacing.space1),
        child: Text('Clear all',
            style: AppTypography.captionMedium.copyWith(
                color: Theme.of(context).colorScheme.primary)),
      ),
    );
  }
}

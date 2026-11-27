import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../application/providers/accounts_provider.dart';
import '../../../../application/providers/categories_provider.dart';
import '../../../../application/providers/transaction_filters_provider.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../domain/entities/account.dart';
import '../../../../domain/entities/category.dart';
import '../../../../domain/value_objects/exact_money.dart';
import '../../../../domain/value_objects/transaction_filters.dart';

class FilterChipBar extends ConsumerWidget {
  const FilterChipBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(transactionFiltersProvider);
    final accounts = ref.watch(accountsProvider);
    final categories = ref.watch(categoriesProvider);
    final chips = _buildChips(filters, accounts, categories, ref);
    if (filters.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingMobile,
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: chips.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.space2),
                  itemBuilder: (context, index) => Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth,
                      ),
                      child: chips[index],
                    ),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(transactionFiltersProvider.notifier).reset(),
              child: const Text('Clear all'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildChips(
    TransactionFilters filters,
    AsyncValue<List<Account>> accounts,
    AsyncValue<List<Category>> categories,
    WidgetRef ref,
  ) {
    final chips = <Widget>[];

    for (final direction in filters.directions) {
      chips.add(
        _FilterChip(
          label: _directionLabel(direction),
          onRemove: () => ref
              .read(transactionFiltersProvider.notifier)
              .toggleDirection(direction),
        ),
      );
    }

    for (final mode in filters.modes) {
      chips.add(
        _FilterChip(
          label: _modeLabel(mode),
          onRemove: () =>
              ref.read(transactionFiltersProvider.notifier).toggleMode(mode),
        ),
      );
    }

    if (filters.accountIds.isNotEmpty && accounts is AsyncData) {
      final value = accounts.value;
      if (value != null) {
        final selectedCurrencies =
            value
                .where((account) => filters.accountIds.contains(account.id))
                .map((account) => account.currencyCode)
                .toSet()
                .toList()
              ..sort();
        for (final accountId in filters.accountIds) {
          final name =
              value
                  .where((a) => a.id == accountId)
                  .map((a) => a.name)
                  .firstOrNull ??
              'Account';
          chips.add(
            _FilterChip(
              label: name,
              onRemove: () => ref
                  .read(transactionFiltersProvider.notifier)
                  .toggleAccountId(accountId),
            ),
          );
        }
        if (selectedCurrencies.isNotEmpty) {
          chips.add(
            _FilterChip(
              label: 'Currencies: ${selectedCurrencies.join(', ')}',
              onRemove: () => ref
                  .read(transactionFiltersProvider.notifier)
                  .setAccountId(null),
            ),
          );
        }
      }
    }

    if (filters.categoryIds.isNotEmpty && categories is AsyncData) {
      final value = categories.value;
      if (value != null) {
        for (final categoryId in filters.categoryIds) {
          final name =
              value
                  .where((c) => c.id == categoryId)
                  .map((c) => c.name)
                  .firstOrNull ??
              'Category';
          chips.add(
            _FilterChip(
              label: name,
              onRemove: () => ref
                  .read(transactionFiltersProvider.notifier)
                  .toggleCategoryId(categoryId),
            ),
          );
        }
      }
    }

    if (filters.currencyCode != null) {
      chips.add(
        _FilterChip(
          label: 'Currency: ${filters.currencyCode}',
          onRemove: () => ref
              .read(transactionFiltersProvider.notifier)
              .setExactAmountRange(currencyCode: null),
        ),
      );
    }

    if (filters.hasExactAmountRange) {
      final min = _exactBoundLabel(
        filters.minAmountCoefficient,
        filters.minAmountScale,
        filters.currencyCode!,
      );
      final max = _exactBoundLabel(
        filters.maxAmountCoefficient,
        filters.maxAmountScale,
        filters.currencyCode!,
      );
      chips.add(
        _FilterChip(
          label: 'Amount: $min—$max ${filters.currencyCode}',
          onRemove: () => ref
              .read(transactionFiltersProvider.notifier)
              .setExactAmountRange(currencyCode: filters.currencyCode),
        ),
      );
    } else if (filters.minAmount != null || filters.maxAmount != null) {
      final min = filters.minAmount?.toStringAsFixed(0) ?? '';
      final max = filters.maxAmount?.toStringAsFixed(0) ?? '';
      chips.add(
        _FilterChip(
          label: 'Amount: $min\u2014$max',
          onRemove: () => ref
              .read(transactionFiltersProvider.notifier)
              .setAmountRange(null, null),
        ),
      );
    }

    if (filters.dateRange != null) {
      final start = _formatDate(filters.dateRange!.start);
      final end = _formatDate(filters.dateRange!.end);
      chips.add(
        _FilterChip(
          label: 'Date: $start \u2014 $end',
          onRemove: () =>
              ref.read(transactionFiltersProvider.notifier).setDateRange(null),
        ),
      );
    }

    return chips;
  }

  String _directionLabel(String d) {
    switch (d) {
      case 'expense':
        return 'Expense';
      case 'income':
        return 'Income';
      case 'transfer':
        return 'Transfer';
      default:
        return d;
    }
  }

  String _modeLabel(String m) {
    switch (m) {
      case 'one_time':
        return 'One-time';
      case 'recurring':
        return 'Recurring';
      case 'installment':
        return 'Installment';
      case 'debt':
        return 'Debt';
      default:
        return m;
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}';

  String _exactBoundLabel(
    String? coefficient,
    int? scale,
    String currencyCode,
  ) {
    if (coefficient == null || scale == null) return '';
    return ExactMoney(
      coefficient: BigInt.parse(coefficient),
      scale: scale,
      currencyCode: currencyCode,
    ).toDecimalString();
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ActionChip(
      tooltip: 'Remove $label filter',
      onPressed: onRemove,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: colors.primaryContainer,
      labelStyle: AppTypography.captionMedium.copyWith(
        color: colors.onPrimaryContainer,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: AppSpacing.space1),
          Icon(Icons.close, size: 16, color: colors.onPrimaryContainer),
        ],
      ),
    );
  }
}

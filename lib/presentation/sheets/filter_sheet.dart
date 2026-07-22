import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/accounts_provider.dart';
import '../../application/providers/categories_provider.dart';
import '../../application/providers/transaction_filters_provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart';
import '../../domain/value_objects/date_range.dart';
import '../../domain/value_objects/exact_money.dart';
import '../../domain/value_objects/transaction_filters.dart';
import '../shared/components/sheet_handle.dart';

class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key});

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late final TextEditingController _minAmountController;
  late final TextEditingController _maxAmountController;
  String? _currencyCode;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _amountNeedsCurrency = false;
  bool _amountInvalid = false;

  @override
  void initState() {
    super.initState();
    final filters = ref.read(transactionFiltersProvider);
    _minAmountController = TextEditingController(
      text: _initialAmountText(
        coefficient: filters.minAmountCoefficient,
        scale: filters.minAmountScale,
        currencyCode: filters.currencyCode,
        legacyAmount: filters.minAmount,
      ),
    );
    _maxAmountController = TextEditingController(
      text: _initialAmountText(
        coefficient: filters.maxAmountCoefficient,
        scale: filters.maxAmountScale,
        currencyCode: filters.currencyCode,
        legacyAmount: filters.maxAmount,
      ),
    );
    _currencyCode = filters.currencyCode;
    _startDate = filters.dateRange?.start;
    _endDate = filters.dateRange?.end;
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  bool _applyAmountRange() {
    final notifier = ref.read(transactionFiltersProvider.notifier);
    final hasMinimum = _minAmountController.text.trim().isNotEmpty;
    final hasMaximum = _maxAmountController.text.trim().isNotEmpty;
    if (_currencyCode == null) {
      notifier.setExactAmountRange(currencyCode: null);
      final needsCurrency = hasMinimum || hasMaximum;
      if (mounted) {
        setState(() {
          _amountNeedsCurrency = needsCurrency;
          _amountInvalid = false;
        });
      }
      return !needsCurrency;
    }

    final minimum = _parseExactAmount(
      _minAmountController.text,
      _currencyCode!,
    );
    final maximum = _parseExactAmount(
      _maxAmountController.text,
      _currencyCode!,
    );
    final invalid =
        (hasMinimum && minimum == null) || (hasMaximum && maximum == null);
    if (mounted) {
      setState(() {
        _amountNeedsCurrency = false;
        _amountInvalid = invalid;
      });
    }
    if (invalid) return false;
    notifier.setExactAmountRange(
      currencyCode: _currencyCode,
      minCoefficient: minimum?.coefficient.toString(),
      minScale: minimum?.scale,
      maxCoefficient: maximum?.coefficient.toString(),
      maxScale: maximum?.scale,
    );
    return true;
  }

  void _applyDateRange() {
    if (_startDate == null || _endDate == null) {
      ref.read(transactionFiltersProvider.notifier).setDateRange(null);
      return;
    }

    final start = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
    );
    final end = DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      23,
      59,
      59,
      999,
    );

    if (start.isAfter(end)) {
      return;
    }

    ref
        .read(transactionFiltersProvider.notifier)
        .setDateRange(DateRange(start, end));
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _startDate = picked;
      if (_endDate != null && _endDate!.isBefore(picked)) {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _endDate = picked;
      if (_startDate != null && _startDate!.isAfter(picked)) {
        _startDate = picked;
      }
    });
  }

  void _clearAll() {
    _minAmountController.clear();
    _maxAmountController.clear();
    setState(() {
      _currencyCode = null;
      _startDate = null;
      _endDate = null;
      _amountNeedsCurrency = false;
      _amountInvalid = false;
    });
    ref.read(transactionFiltersProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(transactionFiltersProvider);
    final accounts = ref.watch(accountsProvider);
    final categories = ref.watch(categoriesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sheetPaddingHorizontal,
            0,
            AppSpacing.sheetPaddingHorizontal,
            AppSpacing.sheetPaddingVertical,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: AppSpacing.space2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style: AppTypography.h2.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: context.lootrColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space3),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionLabel(label: 'Direction'),
                      const SizedBox(height: AppSpacing.space2),
                      _DirectionControl(filters: filters),
                      const SizedBox(height: AppSpacing.space4),
                      const _SectionLabel(label: 'Mode'),
                      const SizedBox(height: AppSpacing.space2),
                      _ModeControl(filters: filters),
                      const SizedBox(height: AppSpacing.space4),
                      const _SectionLabel(label: 'Account'),
                      const SizedBox(height: AppSpacing.space2),
                      _AccountList(accounts: accounts, filters: filters),
                      const SizedBox(height: AppSpacing.space4),
                      const _SectionLabel(label: 'Category'),
                      const SizedBox(height: AppSpacing.space2),
                      _CategoryList(categories: categories, filters: filters),
                      const SizedBox(height: AppSpacing.space4),
                      const _SectionLabel(label: 'Currency'),
                      const SizedBox(height: AppSpacing.space2),
                      _CurrencyList(
                        accounts: accounts,
                        selectedCurrencyCode: _currencyCode,
                        onSelected: (currencyCode) {
                          if (currencyCode == null && _currencyCode != null) {
                            _minAmountController.clear();
                            _maxAmountController.clear();
                          }
                          setState(() => _currencyCode = currencyCode);
                          _applyAmountRange();
                        },
                      ),
                      const SizedBox(height: AppSpacing.space4),
                      const _SectionLabel(label: 'Amount Range'),
                      const SizedBox(height: AppSpacing.space2),
                      _AmountRangeSection(
                        minController: _minAmountController,
                        maxController: _maxAmountController,
                        onChanged: _applyAmountRange,
                      ),
                      if (_amountNeedsCurrency || _amountInvalid) ...[
                        const SizedBox(height: AppSpacing.space1),
                        Text(
                          _amountNeedsCurrency
                              ? 'Choose a currency before filtering by amount.'
                              : 'Enter a valid decimal amount.',
                          style: AppTypography.caption.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.space4),
                      const _SectionLabel(label: 'Date Range'),
                      const SizedBox(height: AppSpacing.space2),
                      _DateRangeSection(
                        startDate: _startDate,
                        endDate: _endDate,
                        onPickStartDate: _pickStartDate,
                        onPickEndDate: _pickEndDate,
                        onApply: _applyDateRange,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.space3),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.space3),
              LayoutBuilder(
                builder: (context, constraints) {
                  final clearButton = TextButton(
                    onPressed: _clearAll,
                    child: Text(
                      'Clear all filters',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  );
                  final activeCount = filters.activeCount;
                  final applyButton = FilledButton(
                    onPressed: () {
                      // Amounts are committed as they are typed, but re-apply
                      // here so nothing typed is lost on Apply.
                      if (!_applyAmountRange()) return;
                      Navigator.of(context).pop();
                    },
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                    child: Text(
                      activeCount == 0
                          ? 'Apply'
                          : 'Apply $activeCount filter${activeCount == 1 ? '' : 's'}',
                    ),
                  );

                  if (constraints.maxWidth < 360) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        applyButton,
                        const SizedBox(height: AppSpacing.space2),
                        Align(alignment: Alignment.center, child: clearButton),
                      ],
                    );
                  }

                  return Row(
                    children: [clearButton, const Spacer(), applyButton],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _initialAmountText({
  required String? coefficient,
  required int? scale,
  required String? currencyCode,
  required double? legacyAmount,
}) {
  if (coefficient != null && scale != null && currencyCode != null) {
    return ExactMoney(
      coefficient: BigInt.parse(coefficient),
      scale: scale,
      currencyCode: currencyCode,
    ).toDecimalString();
  }
  return legacyAmount?.toString() ?? '';
}

ExactMoney? _parseExactAmount(String raw, String currencyCode) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  try {
    return ExactMoney.parse(value, currencyCode);
  } on FormatException {
    return null;
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.captionMedium.copyWith(
        color: context.lootrColors.textSecondary,
      ),
    );
  }
}

class _DirectionControl extends ConsumerWidget {
  const _DirectionControl({required this.filters});

  final TransactionFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PillScroller(
      children: [
        _PillChip(
          label: 'All',
          isSelected: filters.directions.isEmpty,
          onTap: () =>
              ref.read(transactionFiltersProvider.notifier).setDirection(null),
        ),
        for (final value in const ['expense', 'income', 'transfer'])
          _PillChip(
            label: _titleCase(value),
            isSelected: filters.directions.contains(value),
            onTap: () => ref
                .read(transactionFiltersProvider.notifier)
                .toggleDirection(value),
          ),
      ],
    );
  }
}

class _ModeControl extends ConsumerWidget {
  const _ModeControl({required this.filters});

  final TransactionFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PillScroller(
      children: [
        _PillChip(
          label: 'All',
          isSelected: filters.modes.isEmpty,
          onTap: () =>
              ref.read(transactionFiltersProvider.notifier).setMode(null),
        ),
        for (final entry in const {
          'one_time': 'One-time',
          'recurring': 'Recurring',
          'installment': 'Installment',
          'debt': 'Debt',
        }.entries)
          _PillChip(
            label: entry.value,
            isSelected: filters.modes.contains(entry.key),
            onTap: () => ref
                .read(transactionFiltersProvider.notifier)
                .toggleMode(entry.key),
          ),
      ],
    );
  }
}

class _AccountList extends ConsumerWidget {
  const _AccountList({required this.accounts, required this.filters});

  final AsyncValue<List<Account>> accounts;
  final TransactionFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return accounts.when(
      data: (items) {
        return _PillScroller(
          children: [
            _PillChip(
              label: 'All',
              isSelected: filters.accountIds.isEmpty,
              onTap: () => ref
                  .read(transactionFiltersProvider.notifier)
                  .setAccountId(null),
            ),
            for (final account in items)
              _PillChip(
                label: account.name,
                isSelected: filters.accountIds.contains(account.id),
                onTap: () => ref
                    .read(transactionFiltersProvider.notifier)
                    .toggleAccountId(account.id),
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.space4),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const Text('Unable to load accounts'),
    );
  }
}

class _CurrencyList extends StatelessWidget {
  const _CurrencyList({
    required this.accounts,
    required this.selectedCurrencyCode,
    required this.onSelected,
  });

  final AsyncValue<List<Account>> accounts;
  final String? selectedCurrencyCode;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return accounts.when(
      data: (items) {
        final currencyCodes =
            items.map((account) => account.currencyCode).toSet().toList()
              ..sort();
        return _PillScroller(
          children: [
            _PillChip(
              label: 'All',
              isSelected: selectedCurrencyCode == null,
              onTap: () => onSelected(null),
            ),
            for (final currencyCode in currencyCodes)
              _PillChip(
                label: currencyCode,
                isSelected: selectedCurrencyCode == currencyCode,
                onTap: () => onSelected(currencyCode),
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.space4),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const Text('Unable to load currencies'),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.categories, required this.filters});

  final AsyncValue<List<Category>> categories;
  final TransactionFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return categories.when(
      data: (items) {
        return _PillScroller(
          children: [
            _PillChip(
              label: 'All',
              isSelected: filters.categoryIds.isEmpty,
              onTap: () => ref
                  .read(transactionFiltersProvider.notifier)
                  .setCategoryId(null),
            ),
            for (final category in items)
              _PillChip(
                label: category.name,
                isSelected: filters.categoryIds.contains(category.id),
                accent: _groupColor(context, category.categoryGroup),
                onTap: () => ref
                    .read(transactionFiltersProvider.notifier)
                    .toggleCategoryId(category.id),
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.space4),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const Text('Unable to load categories'),
    );
  }

  Color _groupColor(BuildContext context, String group) {
    switch (group) {
      case 'expense':
        return context.lootrColors.expense;
      case 'income':
        return context.lootrColors.income;
      case 'transfer':
        return context.lootrColors.transfer;
      default:
        return context.lootrColors.textSecondary;
    }
  }
}

class _AmountRangeSection extends StatelessWidget {
  const _AmountRangeSection({
    required this.minController,
    required this.maxController,
    required this.onChanged,
  });

  final TextEditingController minController;
  final TextEditingController maxController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: minController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTypography.body.copyWith(color: colorScheme.onSurface),
            decoration: _rangeInputDecoration(
              context: context,
              hintText: 'Min',
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(width: AppSpacing.space3),
        Text(
          '—',
          style: AppTypography.body.copyWith(
            color: context.lootrColors.textTertiary,
          ),
        ),
        const SizedBox(width: AppSpacing.space3),
        Expanded(
          child: TextField(
            controller: maxController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTypography.body.copyWith(color: colorScheme.onSurface),
            decoration: _rangeInputDecoration(
              context: context,
              hintText: 'Max',
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
      ],
    );
  }
}

class _DateRangeSection extends StatelessWidget {
  const _DateRangeSection({
    required this.startDate,
    required this.endDate,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onApply,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final Future<void> Function() onPickStartDate;
  final Future<void> Function() onPickEndDate;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _DateField(
                label: _formatDate(startDate),
                hasValue: startDate != null,
                onTap: onPickStartDate,
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
            Text(
              '—',
              style: AppTypography.body.copyWith(
                color: context.lootrColors.textTertiary,
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: _DateField(
                label: _formatDate(endDate),
                hasValue: endDate != null,
                onTap: onPickEndDate,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space2),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: onApply, child: const Text('Apply')),
        ),
      ],
    );
  }

  static String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Select date';
    }

    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.hasValue,
    required this.onTap,
  });

  final String label;
  final bool hasValue;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space3,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colorScheme.outline),
        ),
        child: Text(
          label,
          style: AppTypography.body.copyWith(
            color: hasValue
                ? colorScheme.onSurface
                : context.lootrColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

InputDecoration _rangeInputDecoration({
  required BuildContext context,
  required String hintText,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  return InputDecoration(
    hintText: hintText,
    hintStyle: AppTypography.body.copyWith(
      color: context.lootrColors.textTertiary,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: colorScheme.outline),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.space3,
      vertical: AppSpacing.space3,
    ),
    isDense: true,
  );
}

String _titleCase(String value) {
  if (value.isEmpty) {
    return value;
  }

  return value[0].toUpperCase() + value.substring(1);
}

class _PillScroller extends StatelessWidget {
  const _PillScroller({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.space2),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.accent,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final primary = accent ?? Theme.of(context).colorScheme.primary;

    return FilterChip(
      label: Text(label, softWrap: false),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: primary.withValues(alpha: 0.14),
      side: BorderSide(
        color: isSelected
            ? primary
            : Theme.of(context).colorScheme.outlineVariant,
      ),
      labelStyle: AppTypography.captionMedium.copyWith(
        color: isSelected ? primary : Theme.of(context).colorScheme.onSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
    );
  }
}

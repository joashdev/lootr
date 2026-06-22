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
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final filters = ref.read(transactionFiltersProvider);
    _minAmountController = TextEditingController(
      text: filters.minAmount?.toStringAsFixed(0) ?? '',
    );
    _maxAmountController = TextEditingController(
      text: filters.maxAmount?.toStringAsFixed(0) ?? '',
    );
    _startDate = filters.dateRange?.start;
    _endDate = filters.dateRange?.end;
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  void _applyAmountRange() {
    final min = double.tryParse(_minAmountController.text.trim());
    final max = double.tryParse(_maxAmountController.text.trim());
    ref.read(transactionFiltersProvider.notifier).setAmountRange(min, max);
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
      _startDate = null;
      _endDate = null;
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
                      const _SectionLabel(label: 'Amount Range'),
                      const SizedBox(height: AppSpacing.space2),
                      _AmountRangeSection(
                        minController: _minAmountController,
                        maxController: _maxAmountController,
                        onApply: _applyAmountRange,
                      ),
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
                  final applyButton = FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                    child: Text(
                      'Apply ${filters.activeCount} filter${filters.activeCount == 1 ? '' : 's'}',
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 520,
        child: SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: '', label: Text('All', softWrap: false)),
            ButtonSegment(
              value: 'expense',
              label: Text('Expense', softWrap: false),
            ),
            ButtonSegment(
              value: 'income',
              label: Text('Income', softWrap: false),
            ),
            ButtonSegment(
              value: 'transfer',
              label: Text('Transfer', softWrap: false),
            ),
          ],
          selected: {filters.direction ?? ''},
          onSelectionChanged: (selected) {
            final value = selected.first;
            ref
                .read(transactionFiltersProvider.notifier)
                .setDirection(value.isEmpty ? null : value);
          },
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
      ),
    );
  }
}

class _ModeControl extends ConsumerWidget {
  const _ModeControl({required this.filters});

  final TransactionFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 640,
        child: SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: '', label: Text('All', softWrap: false)),
            ButtonSegment(
              value: 'one_time',
              label: Text('One-time', softWrap: false),
            ),
            ButtonSegment(
              value: 'recurring',
              label: Text('Recurring', softWrap: false),
            ),
            ButtonSegment(
              value: 'installment',
              label: Text('Installment', softWrap: false),
            ),
            ButtonSegment(value: 'debt', label: Text('Debt', softWrap: false)),
          ],
          selected: {filters.mode ?? ''},
          onSelectionChanged: (selected) {
            final value = selected.first;
            ref
                .read(transactionFiltersProvider.notifier)
                .setMode(value.isEmpty ? null : value);
          },
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
      ),
    );
  }
}

class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off_outlined,
              size: 20,
              color: isSelected
                  ? colorScheme.primary
                  : context.lootrColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Text(
                title,
                style: AppTypography.body.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
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
        return SizedBox(
          height: _heightForRows(items.length + 1, maxHeight: 264),
          child: ListView(
            children: [
              _SelectableTile(
                title: 'All',
                isSelected: filters.accountId == null,
                onTap: () => ref
                    .read(transactionFiltersProvider.notifier)
                    .setAccountId(null),
              ),
              for (final account in items)
                _SelectableTile(
                  title: account.name,
                  isSelected: filters.accountId == account.id,
                  onTap: () => ref
                      .read(transactionFiltersProvider.notifier)
                      .setAccountId(
                        filters.accountId == account.id ? null : account.id,
                      ),
                ),
            ],
          ),
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

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.categories, required this.filters});

  final AsyncValue<List<Category>> categories;
  final TransactionFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return categories.when(
      data: (items) {
        final grouped = <String, List<Category>>{
          'expense': items
              .where((item) => item.categoryGroup == 'expense')
              .toList(),
          'income': items
              .where((item) => item.categoryGroup == 'income')
              .toList(),
          'transfer': items
              .where((item) => item.categoryGroup == 'transfer')
              .toList(),
        };

        final tiles = <Widget>[
          _SelectableTile(
            title: 'All',
            isSelected: filters.categoryId == null,
            onTap: () => ref
                .read(transactionFiltersProvider.notifier)
                .setCategoryId(null),
          ),
        ];

        for (final entry in grouped.entries) {
          if (entry.value.isEmpty) {
            continue;
          }

          tiles.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space4,
                AppSpacing.space2,
                0,
                AppSpacing.space1,
              ),
              child: Text(
                _titleCase(entry.key),
                style: AppTypography.micro.copyWith(
                  color: _groupColor(context, entry.key),
                ),
              ),
            ),
          );

          for (final category in entry.value) {
            tiles.add(
              _SelectableTile(
                title: category.name,
                isSelected: filters.categoryId == category.id,
                onTap: () => ref
                    .read(transactionFiltersProvider.notifier)
                    .setCategoryId(
                      filters.categoryId == category.id ? null : category.id,
                    ),
              ),
            );
          }
        }

        return SizedBox(
          height: _heightForRows(tiles.length, maxHeight: 360),
          child: ListView(children: tiles),
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
    required this.onApply,
  });

  final TextEditingController minController;
  final TextEditingController maxController;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: minController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: AppTypography.body.copyWith(
                  color: colorScheme.onSurface,
                ),
                decoration: _rangeInputDecoration(
                  context: context,
                  hintText: 'Min',
                ),
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: AppTypography.body.copyWith(
                  color: colorScheme.onSurface,
                ),
                decoration: _rangeInputDecoration(
                  context: context,
                  hintText: 'Max',
                ),
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

double _heightForRows(int count, {required double maxHeight}) {
  return (count * 44.0).clamp(0, maxHeight);
}

String _titleCase(String value) {
  if (value.isEmpty) {
    return value;
  }

  return value[0].toUpperCase() + value.substring(1);
}

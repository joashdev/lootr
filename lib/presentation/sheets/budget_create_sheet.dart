import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/extensions/async_value_x.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/mappers.dart';
import '../../application/providers/budgets_tab_provider.dart';
import '../../application/providers/categories_provider.dart';
import '../../application/providers/repo_providers.dart';
import '../shared/category_visuals.dart';
import '../shared/components/sheet_handle.dart';
import '../shared/components/app_snackbar.dart';

String _generateId() {
  final r = Random();
  return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
}

class BudgetCreateSheet extends ConsumerStatefulWidget {
  const BudgetCreateSheet({super.key, this.budget});

  final Budget? budget;

  @override
  ConsumerState<BudgetCreateSheet> createState() => _BudgetCreateSheetState();
}

class _BudgetCreateSheetState extends ConsumerState<BudgetCreateSheet> {
  late TextEditingController _amountController;
  late TextEditingController _categoryController;
  late FocusNode _categoryFocusNode;
  String? _selectedCategoryId;

  /// Visual overrides. Null means the budget inherits its category's
  /// icon/color.
  String? _iconOverride;
  String? _colorOverride;

  bool get isEditing => widget.budget != null;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.budget?.amount.toStringAsFixed(0) ?? '',
    );
    _categoryController = TextEditingController();
    _categoryFocusNode = FocusNode();
    _selectedCategoryId = widget.budget?.categoryId;
    _iconOverride = widget.budget?.icon;
    _colorOverride = widget.budget?.color;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _categoryFocusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty || _selectedCategoryId == null) return;

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      AppSnackBar.show(
        context,
        'Please enter a valid amount',
        variant: AppSnackBarVariant.warning,
      );
      return;
    }

    final int month = widget.budget == null
        ? ref.read(budgetMonthProvider)
        : widget.budget!.month;
    final int year = widget.budget == null
        ? ref.read(budgetYearProvider)
        : widget.budget!.year;
    if (isPastBudgetPeriod(month, year)) {
      _showError('Past months are read-only');
      return;
    }

    final repo = ref.read(budgetRepoProvider);
    final ownerUserId =
        widget.budget?.ownerUserId ??
        (await ref.read(userRepoProvider).getCurrentUser())?.id;
    if (ownerUserId == null) {
      _showError('Create a user profile before adding budgets');
      return;
    }

    final existing = await repo.watchAll(month: month, year: year).first;
    final duplicate = existing.any(
      (b) =>
          b.id != widget.budget?.id &&
          b.ownerUserId == ownerUserId &&
          b.householdId == widget.budget?.householdId &&
          b.categoryId == _selectedCategoryId,
    );
    if (duplicate) {
      _showError('A budget already exists for this category and month');
      return;
    }

    final now = DateTime.now();

    try {
      if (isEditing) {
        final b = widget.budget!.copyWith(
          amount: amount,
          categoryId: _selectedCategoryId,
          icon: () => _iconOverride,
          color: () => _colorOverride,
          updatedAt: now,
        );
        await repo.update(b.toCompanion());
      } else {
        final b = Budget(
          id: _generateId(),
          ownerUserId: ownerUserId,
          categoryId: _selectedCategoryId!,
          amount: amount,
          month: month,
          year: year,
          icon: _iconOverride,
          color: _colorOverride,
          createdAt: now,
          updatedAt: now,
        );
        await repo.create(b.toCompanion());
      }
    } catch (_) {
      _showError(
        'Could not save budget. Check for an existing category budget.',
      );
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  void _showError(String message) {
    AppSnackBar.show(context, message, variant: AppSnackBarVariant.error);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;
    final categoriesAsync = ref.watch(categoriesProvider);
    final budgetsAsync = ref.watch(budgetsTabProvider);
    final month = ref.watch(budgetMonthProvider);
    final year = ref.watch(budgetYearProvider);
    final int sheetMonth = widget.budget == null ? month : widget.budget!.month;
    final int sheetYear = widget.budget == null ? year : widget.budget!.year;
    final isReadOnly = isPastBudgetPeriod(sheetMonth, sheetYear);

    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final usedCategoryIds =
        budgetsAsync.valueOrNull
            ?.where((b) => b.id != widget.budget?.id)
            .map((b) => b.categoryId)
            .toSet() ??
        <String>{};
    final expenseCategories =
        categoriesAsync.valueOrNull
            ?.where(
              (c) =>
                  c.categoryGroup == 'expense' &&
                  (!usedCategoryIds.contains(c.id) ||
                      c.id == _selectedCategoryId),
            )
            .toList() ??
        [];
    final selectedCategory = expenseCategories
        .where((c) => c.id == _selectedCategoryId)
        .firstOrNull;
    if (selectedCategory != null &&
        !_categoryFocusNode.hasFocus &&
        _categoryController.text != selectedCategory.name) {
      _categoryController.value = TextEditingValue(
        text: selectedCategory.name,
        selection: TextSelection.collapsed(
          offset: selectedCategory.name.length,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sheetPaddingHorizontal,
              0,
              8,
              AppSpacing.sheetPaddingHorizontal,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEditing ? 'Edit Budget' : 'New Budget',
                        style: AppTypography.h2.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space5),
                Text(
                  'Category',
                  style: AppTypography.captionMedium.copyWith(
                    color: lootrColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
                categoriesAsync.when(
                  data: (_) => _CategoryDropdown(
                    categories: expenseCategories,
                    controller: _categoryController,
                    focusNode: _categoryFocusNode,
                    selectedCategoryId: _selectedCategoryId,
                    enabled: !isReadOnly,
                    onTextChanged: (value) {
                      final normalized = value.trim().toLowerCase();
                      final exactMatch = expenseCategories
                          .where(
                            (category) =>
                                category.name.toLowerCase() == normalized,
                          )
                          .firstOrNull;

                      setState(() {
                        _selectedCategoryId = exactMatch?.id;
                      });
                    },
                    onChanged: (cat) {
                      setState(() {
                        _selectedCategoryId = cat.id;
                      });
                    },
                  ),
                  loading: () => const SizedBox(
                    height: 48,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (_, _) => const Text('Failed to load categories'),
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  'Amount',
                  style: AppTypography.captionMedium.copyWith(
                    color: lootrColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: colorScheme.outline),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space4,
                    vertical: AppSpacing.space3,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '₱',
                        style: AppTypography.mono.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: lootrColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space2),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          enabled: !isReadOnly,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppTypography.mono.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            hintStyle: AppTypography.mono.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: lootrColors.textTertiary,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  '${monthNames[sheetMonth - 1]} $sheetYear',
                  style: AppTypography.caption.copyWith(
                    color: lootrColors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
                _AppearancePicker(
                  category: selectedCategory,
                  iconOverride: _iconOverride,
                  colorOverride: _colorOverride,
                  enabled: !isReadOnly,
                  onIconChanged: (value) =>
                      setState(() => _iconOverride = value),
                  onColorChanged: (value) =>
                      setState(() => _colorOverride = value),
                  onReset: () => setState(() {
                    _iconOverride = null;
                    _colorOverride = null;
                  }),
                ),
                const SizedBox(height: AppSpacing.space5),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isReadOnly ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                    child: Text(
                      isEditing ? 'Save Changes' : 'Save Budget',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (isEditing && !isReadOnly)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.space3),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _confirmDelete(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: lootrColors.danger,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.trash2, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'Delete Budget',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.space4),
              ],
            ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    if (widget.budget == null ||
        isPastBudgetPeriod(widget.budget!.month, widget.budget!.year)) {
      _showError('Past months are read-only');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Budget?'),
        content: const Text(
          'This budget will be permanently removed. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.lootrColors.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(budgetRepoProvider);
      await repo.softDelete(widget.budget!.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

/// Icon + color pickers for a budget, mirroring the category sheet pickers.
/// A null override means the budget inherits its category's visuals.
class _AppearancePicker extends StatelessWidget {
  const _AppearancePicker({
    required this.category,
    required this.iconOverride,
    required this.colorOverride,
    required this.enabled,
    required this.onIconChanged,
    required this.onColorChanged,
    required this.onReset,
  });

  final Category? category;
  final String? iconOverride;
  final String? colorOverride;
  final bool enabled;
  final ValueChanged<String> onIconChanged;
  final ValueChanged<String> onColorChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;
    final hasOverride = iconOverride != null || colorOverride != null;

    final displayIconValue =
        canonicalCategoryIconValue(iconOverride) ??
        resolveCategoryIconValue(
          icon: category?.icon,
          name: category?.name,
          categoryGroup: category?.categoryGroup,
        );
    final displayColorHex = colorOverride ?? category?.color;
    final displayColor = parseCategoryColor(displayColorHex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Color',
                style: AppTypography.captionMedium.copyWith(
                  color: lootrColors.textSecondary,
                ),
              ),
            ),
            if (hasOverride)
              TextButton(
                onPressed: enabled ? onReset : null,
                child: const Text('Use category default'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.space2),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categoryColorOptions.map((option) {
              final isSelected = displayColorHex == option.hex;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.space2),
                child: InkWell(
                  onTap: enabled ? () => onColorChanged(option.hex) : null,
                  borderRadius: BorderRadius.circular(9999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: option.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.surface.withValues(alpha: 0.6)
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.space3),
        Text(
          'Icon',
          style: AppTypography.captionMedium.copyWith(
            color: lootrColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.space2),
        GridView.count(
          crossAxisCount: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.space2,
          crossAxisSpacing: AppSpacing.space2,
          children: categoryIconOptions.map((option) {
            final isSelected = displayIconValue == option.value;
            return InkWell(
              onTap: enabled ? () => onIconChanged(option.value) : null,
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  color: displayColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected
                      ? Border.all(color: displayColor, width: 2)
                      : null,
                ),
                child: Center(
                  child: buildCategoryVisual(
                    option.value,
                    color: displayColor,
                    size: 22,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.categories,
    required this.controller,
    required this.focusNode,
    required this.selectedCategoryId,
    required this.enabled,
    required this.onTextChanged,
    required this.onChanged,
  });

  final List<Category> categories;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? selectedCategoryId;
  final bool enabled;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<Category> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RawAutocomplete<Category>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: (category) => category.name,
      optionsBuilder: (textEditingValue) {
        if (!enabled) return const Iterable<Category>.empty();

        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return categories;

        return categories.where(
          (category) => category.name.toLowerCase().contains(query),
        );
      },
      onSelected: onChanged,
      fieldViewBuilder: (context, fieldController, fieldFocusNode, _) {
        return TextField(
          key: const Key('budget-category-input'),
          controller: fieldController,
          focusNode: fieldFocusNode,
          enabled: enabled,
          onChanged: onTextChanged,
          decoration: InputDecoration(
            hintText: 'Select category',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: AppSpacing.space3,
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final optionList = options.toList();

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 240),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: optionList.length,
                itemBuilder: (context, index) {
                  final category = optionList[index];
                  return ListTile(
                    title: Text(category.name),
                    onTap: () => onSelected(category),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

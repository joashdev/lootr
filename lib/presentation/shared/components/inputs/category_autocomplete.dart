import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/typography.dart';
import '../../../../domain/entities/category.dart';
import '../../../shared/category_visuals.dart';

/// Autocomplete selector for categories, filtered by [groupFilter]
/// (e.g. expense vs income).
class CategoryAutocomplete extends StatelessWidget {
  const CategoryAutocomplete({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.groupFilter,
    required this.onChanged,
    this.initialText,
    this.onTextChanged,
  });

  final List<Category> categories;
  final String? selectedCategoryId;
  final String groupFilter;
  final ValueChanged<String?> onChanged;
  final String? initialText;

  /// Reports raw text typed into the field (without a selection), so callers
  /// can resolve free-text drafts (e.g. from NL quick-add) at save time.
  final ValueChanged<String>? onTextChanged;

  @override
  Widget build(BuildContext context) {
    final filteredCategories =
        categories
            .where(
              (category) =>
                  category.deletedAt == null &&
                  category.categoryGroup == groupFilter,
            )
            .toList()
          ..sort((left, right) => left.name.compareTo(right.name));

    // Resolve the selected category from the FULL list (not the group-filtered
    // one) so an existing selection still displays its name/icon even when the
    // category was soft-deleted or belongs to another group.
    final selectedCategory = categories.cast<Category?>().firstWhere(
      (category) => category!.id == selectedCategoryId,
      orElse: () => null,
    );
    final displayText = (initialText != null && initialText!.trim().isNotEmpty)
        ? initialText!
        : (selectedCategory?.name ?? '');

    return Autocomplete<Category>(
      key: ValueKey(
        '${selectedCategoryId ?? 'none'}:$displayText:$groupFilter',
      ),
      initialValue: TextEditingValue(text: displayText),
      displayStringForOption: (category) => category.name,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) {
          return filteredCategories;
        }
        return filteredCategories.where(
          (category) => category.name.toLowerCase().contains(query),
        );
      },
      onSelected: (category) => onChanged(category.id),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        final colorScheme = Theme.of(context).colorScheme;
        final lootrColors = context.lootrColors;

        final selectedIconColor = selectedCategory == null
            ? null
            : parseCategoryColor(selectedCategory.color);

        return TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (value) {
            onTextChanged?.call(value);
            if (value.trim().isEmpty) {
              onChanged(null);
            }
          },
          style: AppTypography.body.copyWith(color: colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Search category',
            hintStyle: AppTypography.body.copyWith(
              color: lootrColors.textTertiary,
            ),
            prefixIcon: selectedCategory != null && selectedIconColor != null
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: buildCategoryVisualFor(
                      selectedCategory,
                      color: selectedIconColor,
                      size: 18,
                    ),
                  )
                : const Icon(Icons.search, size: 18),
            filled: true,
            fillColor: colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: colorScheme.primary),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final colorScheme = Theme.of(context).colorScheme;
        final lootrColors = context.lootrColors;

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, minWidth: 240),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final category = options.elementAt(index);
                  final isSelected = category.id == selectedCategoryId;
                  final iconColor = parseCategoryColor(category.color);
                  return InkWell(
                    onTap: () => onSelected(category),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: buildCategoryVisualFor(
                              category,
                              color: iconColor,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              category.name,
                              style: AppTypography.body.copyWith(
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check,
                              size: 16,
                              color: lootrColors.success,
                            ),
                        ],
                      ),
                    ),
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

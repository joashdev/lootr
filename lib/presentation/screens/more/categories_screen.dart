import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/categories_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/value_objects/field_types.dart';
import '../../shared/components/empty_state.dart';
import 'more_form_sheets.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  static const _groupLabels = <String, String>{
    CategoryGroup.expense: 'Expenses',
    CategoryGroup.income: 'Income',
    CategoryGroup.transfer: 'Transfers',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Categories')),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return EmptyState(
              headline: 'No categories',
              subtext: 'Categories help you organize your transactions.',
              ctaLabel: 'Add Category',
              onCtaPressed: () => showCategorySheet(context, ref),
            );
          }
          return _CategoryList(categories: categories);
        },
        error: (err, _) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.categories});

  final List<Category> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = <String, List<Category>>{};
    for (final cat in categories) {
      if (cat.deletedAt != null) continue;
      grouped.putIfAbsent(cat.categoryGroup, () => []).add(cat);
    }

    final order = [
      CategoryGroup.expense,
      CategoryGroup.income,
      CategoryGroup.transfer,
    ];
    final sections = <Widget>[];

    for (final group in order) {
      final items = grouped[group];
      if (items == null || items.isEmpty) continue;
      final parentCats = items
          .where((c) => c.parentCategoryId == null)
          .toList();
      sections.add(
        _CategorySection(
          groupLabel: CategoriesScreen._groupLabels[group] ?? group,
          categories: parentCats,
          allCategories: items,
          ref: ref,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.space8),
      children: sections,
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.groupLabel,
    required this.categories,
    required this.allCategories,
    required this.ref,
  });

  final String groupLabel;
  final List<Category> categories;
  final List<Category> allCategories;
  final WidgetRef ref;

  static IconData? _iconForName(String? iconName) {
    if (iconName == null) return LucideIcons.tag;
    final map = <String, IconData>{
      'food': LucideIcons.utensils,
      'transport': LucideIcons.car,
      'shopping': LucideIcons.shoppingBag,
      'utilities': LucideIcons.zap,
      'health': LucideIcons.heart,
      'entertainment': LucideIcons.gamepad2,
      'salary': LucideIcons.banknote,
      'freelance': LucideIcons.laptop,
      'transfer': LucideIcons.arrowLeftRight,
    };
    return map[iconName] ?? LucideIcons.tag;
  }

  static Color _colorForHex(BuildContext context, String? hex) {
    if (hex == null) return Theme.of(context).colorScheme.primary;
    final stripped = hex.replaceFirst('#', '');
    final parsed = int.tryParse('FF$stripped', radix: 16);
    if (parsed == null) return Theme.of(context).colorScheme.primary;
    return Color(parsed);
  }

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
            groupLabel,
            style: AppTypography.captionMedium.copyWith(
              color: lootrColors.textSecondary,
            ),
          ),
        ),
        ...categories.expand((category) {
          final children = allCategories
              .where((item) => item.parentCategoryId == category.id)
              .toList();
          return [
            _CategoryTile(
              category: category,
              lootrColors: lootrColors,
              iconForName: _iconForName,
              colorForHex: _colorForHex,
              onEdit: () => showCategorySheet(context, ref, initial: category),
            ),
            ...children.map(
              (child) => _CategoryTile(
                category: child,
                lootrColors: lootrColors,
                iconForName: _iconForName,
                colorForHex: _colorForHex,
                onEdit: () => showCategorySheet(context, ref, initial: child),
                isChild: true,
              ),
            ),
          ];
        }),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.lootrColors,
    required this.iconForName,
    required this.colorForHex,
    required this.onEdit,
    this.isChild = false,
  });

  final Category category;
  final LootrColorScheme lootrColors;
  final IconData? Function(String?) iconForName;
  final Color Function(BuildContext, String?) colorForHex;
  final VoidCallback onEdit;
  final bool isChild;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.only(
        left: AppSpacing.pagePaddingMobile + (isChild ? AppSpacing.space5 : 0),
        right: AppSpacing.pagePaddingMobile,
      ),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isChild) ...[
            Icon(
              LucideIcons.cornerDownRight,
              size: 14,
              color: lootrColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.space2),
          ],
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorForHex(context, category.color).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              iconForName(category.icon),
              size: 18,
              color: colorForHex(context, category.color),
            ),
          ),
        ],
      ),
      title: Text(
        category.name,
        style: AppTypography.bodyMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: isChild
          ? Text(
              'Subcategory',
              style: AppTypography.caption.copyWith(
                color: lootrColors.textSecondary,
              ),
            )
          : null,
      trailing: IconButton(
        icon: Icon(
          LucideIcons.pencil,
          size: 18,
          color: lootrColors.textTertiary,
        ),
        onPressed: onEdit,
      ),
    );
  }
}

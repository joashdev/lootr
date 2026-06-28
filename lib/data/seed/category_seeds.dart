import 'package:drift/drift.dart' hide isNull;

import '../database/app_database.dart';

class CategorySeed {
  final String id;
  final String name;
  final String categoryGroup;
  final String icon;
  final String color;

  const CategorySeed({
    required this.id,
    required this.name,
    required this.categoryGroup,
    required this.icon,
    required this.color,
  });
}

class CategorySeeds {
  CategorySeeds._();

  static const defaults = <CategorySeed>[
    // Expense (10)
    CategorySeed(
      id: 'default-cat-food-dining',
      name: 'Food & Dining',
      categoryGroup: 'expense',
      icon: 'fork-knife',
      color: '#EF4444',
    ),
    CategorySeed(
      id: 'default-cat-transportation',
      name: 'Transportation',
      categoryGroup: 'expense',
      icon: 'car',
      color: '#F59E0B',
    ),
    CategorySeed(
      id: 'default-cat-shopping',
      name: 'Shopping',
      categoryGroup: 'expense',
      icon: 'shopping-bag-open',
      color: '#8B5CF6',
    ),
    CategorySeed(
      id: 'default-cat-bills-utilities',
      name: 'Bills & Utilities',
      categoryGroup: 'expense',
      icon: 'lightbulb',
      color: '#06B6D4',
    ),
    CategorySeed(
      id: 'default-cat-housing',
      name: 'Housing',
      categoryGroup: 'expense',
      icon: 'house',
      color: '#EC4899',
    ),
    CategorySeed(
      id: 'default-cat-entertainment',
      name: 'Entertainment',
      categoryGroup: 'expense',
      icon: 'game-controller',
      color: '#F97316',
    ),
    CategorySeed(
      id: 'default-cat-health-fitness',
      name: 'Health & Fitness',
      categoryGroup: 'expense',
      icon: 'heartbeat',
      color: '#10B981',
    ),
    CategorySeed(
      id: 'default-cat-education',
      name: 'Education',
      categoryGroup: 'expense',
      icon: 'graduation-cap',
      color: '#6366F1',
    ),
    CategorySeed(
      id: 'default-cat-personal-care',
      name: 'Personal Care',
      categoryGroup: 'expense',
      icon: 'scissors',
      color: '#D946EF',
    ),
    CategorySeed(
      id: 'default-cat-gifts-donations',
      name: 'Gifts & Donations',
      categoryGroup: 'expense',
      icon: 'gift',
      color: '#E11D48',
    ),
    // Income (6)
    CategorySeed(
      id: 'default-cat-salary',
      name: 'Salary',
      categoryGroup: 'income',
      icon: 'money',
      color: '#22C55E',
    ),
    CategorySeed(
      id: 'default-cat-freelance',
      name: 'Freelance',
      categoryGroup: 'income',
      icon: 'laptop',
      color: '#3B82F6',
    ),
    CategorySeed(
      id: 'default-cat-business-income',
      name: 'Business Income',
      categoryGroup: 'income',
      icon: 'storefront',
      color: '#14B8A6',
    ),
    CategorySeed(
      id: 'default-cat-investment-income',
      name: 'Investment Income',
      categoryGroup: 'income',
      icon: 'chart-line-up',
      color: '#A855F7',
    ),
    CategorySeed(
      id: 'default-cat-gifts-received',
      name: 'Gifts Received',
      categoryGroup: 'income',
      icon: 'hand-heart',
      color: '#84CC16',
    ),
    CategorySeed(
      id: 'default-cat-refunds',
      name: 'Refunds',
      categoryGroup: 'income',
      icon: 'arrow-bend-up-left',
      color: '#78716C',
    ),
    // Transfer (1)
    CategorySeed(
      id: 'default-cat-account-transfer',
      name: 'Account Transfer',
      categoryGroup: 'transfer',
      icon: 'arrows-left-right',
      color: '#64748B',
    ),
  ];

  static List<CategoriesCompanion> toCompanions() {
    return defaults
        .map(
          (c) => CategoriesCompanion.insert(
            id: c.id,
            name: c.name,
            categoryGroup: c.categoryGroup,
            icon: Value(c.icon),
            color: Value(c.color),
          ),
        )
        .toList();
  }
}

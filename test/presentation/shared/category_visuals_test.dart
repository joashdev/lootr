import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/domain/entities/budget.dart';
import 'package:lootr/domain/entities/category.dart';
import 'package:lootr/presentation/shared/category_visuals.dart';

Category _category({
  String? icon,
  String? color,
  String name = 'Test',
  String group = 'expense',
}) {
  final now = DateTime(2026, 1, 1);
  return Category(
    id: 'cat-1',
    name: name,
    icon: icon,
    color: color,
    categoryGroup: group,
    createdAt: now,
    updatedAt: now,
  );
}

Budget _budget({String? icon, String? color}) {
  final now = DateTime(2026, 1, 1);
  return Budget(
    id: 'bud-1',
    ownerUserId: 'user-1',
    categoryId: 'cat-1',
    amount: 1000,
    month: 1,
    year: 2026,
    icon: icon,
    color: color,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('canonicalCategoryIconValue', () {
    test('returns canonical values unchanged', () {
      expect(canonicalCategoryIconValue('dining'), 'dining');
      expect(canonicalCategoryIconValue('banknote'), 'banknote');
    });

    test('passes emoji values through', () {
      expect(canonicalCategoryIconValue('emoji:🍔'), 'emoji:🍔');
    });

    test('maps legacy seed keys to canonical values', () {
      expect(canonicalCategoryIconValue('fork-knife'), 'dining');
      expect(canonicalCategoryIconValue('shopping-bag-open'), 'shopping-bag');
      expect(canonicalCategoryIconValue('lightbulb'), 'electricity');
      expect(canonicalCategoryIconValue('game-controller'), 'gaming');
      expect(canonicalCategoryIconValue('heartbeat'), 'health');
      expect(canonicalCategoryIconValue('graduation-cap'), 'education');
      expect(canonicalCategoryIconValue('money'), 'banknote');
      expect(canonicalCategoryIconValue('chart-line-up'), 'investment');
      expect(canonicalCategoryIconValue('hand-heart'), 'charity');
      expect(canonicalCategoryIconValue('arrow-bend-up-left'), 'refund');
      expect(canonicalCategoryIconValue('arrows-left-right'), 'transfer');
    });

    test('returns null for unknown or empty values', () {
      expect(canonicalCategoryIconValue(null), isNull);
      expect(canonicalCategoryIconValue(''), isNull);
      expect(canonicalCategoryIconValue('definitely-not-an-icon'), isNull);
    });
  });

  group('defaultCategoryIconValue', () {
    test('derives icon from the category name', () {
      expect(defaultCategoryIconValue(name: 'Food & Dining'), 'dining');
      expect(defaultCategoryIconValue(name: 'Bills & Utilities'), 'electricity');
      expect(defaultCategoryIconValue(name: 'Transportation'), 'car');
      expect(defaultCategoryIconValue(name: 'Entertainment'), 'entertainment');
      expect(defaultCategoryIconValue(name: 'Health & Fitness'), 'health');
      expect(defaultCategoryIconValue(name: 'Education'), 'education');
      expect(defaultCategoryIconValue(name: 'Shopping'), 'shopping-bag');
      expect(defaultCategoryIconValue(name: 'Salary'), 'banknote');
      expect(defaultCategoryIconValue(name: 'Groceries'), 'grocery');
    });

    test('falls back to the category group', () {
      expect(
        defaultCategoryIconValue(name: 'Xyzzy', categoryGroup: 'income'),
        'banknote',
      );
      expect(
        defaultCategoryIconValue(name: 'Xyzzy', categoryGroup: 'transfer'),
        'transfer',
      );
      expect(
        defaultCategoryIconValue(name: 'Xyzzy', categoryGroup: 'expense'),
        'tag',
      );
      expect(defaultCategoryIconValue(), 'tag');
    });
  });

  group('resolveCategoryIconValue', () {
    test('user-chosen icon wins over name-based default', () {
      expect(
        resolveCategoryIconValue(icon: 'pet', name: 'Food & Dining'),
        'pet',
      );
    });

    test('legacy stored icon wins over name-based default', () {
      expect(
        resolveCategoryIconValue(icon: 'money', name: 'Food & Dining'),
        'banknote',
      );
    });

    test('unknown stored icon falls back to name-based default', () {
      expect(
        resolveCategoryIconValue(icon: 'bogus', name: 'Food & Dining'),
        'dining',
      );
    });
  });

  group('categoryIconOptionFor', () {
    test('resolves aliases to real options', () {
      final option = categoryIconOptionFor('fork-knife');
      expect(option.value, 'dining');
      expect(option.icon, isNotNull);
    });

    test('unknown values resolve to the generic tag option', () {
      expect(categoryIconOptionFor('nope').value, 'tag');
      expect(categoryIconOptionFor(null).value, 'tag');
    });

    test('emoji values keep their emoji', () {
      expect(categoryIconOptionFor('emoji:🍔').emoji, '🍔');
    });
  });

  group('budget visuals', () {
    test('budget override wins over category icon and color', () {
      final budget = _budget(icon: 'travel', color: '#E11D48');
      final category = _category(icon: 'dining', color: '#059669');
      expect(resolveBudgetIconValue(budget, category), 'travel');
      expect(resolveBudgetColor(budget, category), const Color(0xFFE11D48));
    });

    test('budget without override inherits category visuals', () {
      final budget = _budget();
      final category = _category(icon: 'fork-knife', color: '#059669');
      expect(resolveBudgetIconValue(budget, category), 'dining');
      expect(resolveBudgetColor(budget, category), const Color(0xFF059669));
    });

    test('budget with missing category falls back to defaults', () {
      final budget = _budget();
      expect(resolveBudgetIconValue(budget, null), 'tag');
      expect(resolveBudgetColor(budget, null), isA<Color>());
    });

    test('category name drives default when no icon is stored', () {
      final budget = _budget();
      final category = _category(name: 'Food & Dining');
      expect(resolveBudgetIconValue(budget, category), 'dining');
    });
  });

  group('seed icons', () {
    test('every seed icon key resolves to a concrete option', () {
      const seedIcons = [
        'fork-knife',
        'car',
        'shopping-bag-open',
        'lightbulb',
        'house',
        'game-controller',
        'heartbeat',
        'graduation-cap',
        'scissors',
        'gift',
        'money',
        'laptop',
        'storefront',
        'chart-line-up',
        'hand-heart',
        'arrow-bend-up-left',
        'arrows-left-right',
      ];
      for (final icon in seedIcons) {
        final canonical = canonicalCategoryIconValue(icon);
        expect(canonical, isNotNull, reason: 'seed icon $icon is unmapped');
        final option = categoryIconOptionFor(canonical);
        expect(
          option.icon ?? option.emoji,
          isNotNull,
          reason: 'seed icon $icon has no glyph',
        );
        // Only the Shopping seed itself may resolve to the shopping bag;
        // everything else must keep its own glyph.
        if (icon != 'shopping-bag-open') {
          expect(
            option.value,
            isNot('shopping-bag'),
            reason: 'seed icon $icon fell back to the generic glyph',
          );
        }
      }
    });
  });

  group('buildCategoryVisual', () {
    testWidgets('renders icon for canonical value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: buildCategoryVisual('dining', color: Colors.red),
        ),
      );
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('renders emoji as text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: buildCategoryVisual('emoji:🍔', color: Colors.red),
        ),
      );
      expect(find.text('🍔'), findsOneWidget);
    });

    testWidgets('uses name-based default for null icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: buildCategoryVisual(
            null,
            color: Colors.red,
            categoryName: 'Groceries',
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, categoryIconOptionFor('grocery').icon);
    });
  });
}

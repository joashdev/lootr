import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/data/seed/category_seeds.dart';

void main() {
  group('CategorySeeds', () {
    test('has exactly 17 default categories', () {
      expect(CategorySeeds.defaults.length, 17);
    });

    test('has 10 expense categories', () {
      final expenses =
          CategorySeeds.defaults.where((c) => c.categoryGroup == 'expense');
      expect(expenses.length, 10);
    });

    test('has 6 income categories', () {
      final income =
          CategorySeeds.defaults.where((c) => c.categoryGroup == 'income');
      expect(income.length, 6);
    });

    test('has 1 transfer category', () {
      final transfers =
          CategorySeeds.defaults.where((c) => c.categoryGroup == 'transfer');
      expect(transfers.length, 1);
    });

    test('all categories have non-null name, icon, color', () {
      for (final cat in CategorySeeds.defaults) {
        expect(cat.name, isNotEmpty);
        expect(cat.icon, isNotEmpty);
        expect(cat.color, isNotEmpty);
        expect(cat.color, startsWith('#'));
      }
    });

    test('all category IDs are unique', () {
      final ids = CategorySeeds.defaults.map((c) => c.id).toSet();
      expect(ids.length, 17);
    });

    test('all category IDs start with default-cat-', () {
      for (final cat in CategorySeeds.defaults) {
        expect(cat.id, startsWith('default-cat-'));
      }
    });

    test('toCompanions produces 17 companions with correct fields', () {
      final companions = CategorySeeds.toCompanions();
      expect(companions.length, 17);

      for (var i = 0; i < companions.length; i++) {
        final c = companions[i];
        final seed = CategorySeeds.defaults[i];
        expect(c.id.value, seed.id);
        expect(c.name.value, seed.name);
        expect(c.categoryGroup.value, seed.categoryGroup);
        expect(c.icon.value, seed.icon);
        expect(c.color.value, seed.color);
      }
    });
  });
}

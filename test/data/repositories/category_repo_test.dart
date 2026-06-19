import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/category_repo.dart';

void main() {
  late AppDatabase db;
  late CategoryRepo repo;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = CategoryRepo(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('CategoryRepo', () {
    test('create inserts and returns id', () async {
      final id = await repo.create(CategoriesCompanion.insert(
        id: 'cat-1',
        name: 'Food',
        categoryGroup: 'expense',
      ));
      expect(id, 'cat-1');
    });

    test('watchAll returns all non-deleted categories', () async {
      await repo.create(CategoriesCompanion.insert(
        id: 'cat-1',
        name: 'Food',
        categoryGroup: 'expense',
      ));
      await repo.create(CategoriesCompanion.insert(
        id: 'cat-2',
        name: 'Salary',
        categoryGroup: 'income',
      ));

      final cats = await repo.watchAll().first;
      expect(cats.length, 2);
    });

    test('watchByGroup filters by category group', () async {
      await repo.create(CategoriesCompanion.insert(
        id: 'cat-exp',
        name: 'Food',
        categoryGroup: 'expense',
      ));
      await repo.create(CategoriesCompanion.insert(
        id: 'cat-inc',
        name: 'Salary',
        categoryGroup: 'income',
      ));
      await repo.create(CategoriesCompanion.insert(
        id: 'cat-xfer',
        name: 'Transfer',
        categoryGroup: 'transfer',
      ));

      final expenses = await repo.watchByGroup('expense').first;
      expect(expenses.length, 1);
      expect(expenses.first.name, 'Food');

      final income = await repo.watchByGroup('income').first;
      expect(income.length, 1);
      expect(income.first.name, 'Salary');

      final transfers = await repo.watchByGroup('transfer').first;
      expect(transfers.length, 1);
      expect(transfers.first.name, 'Transfer');
    });

    test('update modifies category fields', () async {
      await repo.create(CategoriesCompanion.insert(
        id: 'cat-1',
        name: 'Food',
        categoryGroup: 'expense',
      ));

      await repo.update(CategoriesCompanion(
        id: const Value('cat-1'),
        name: const Value('Groceries'),
        icon: const Value('cart'),
      ));

      final cat = await (db.select(db.categories)..limit(1)).getSingle();
      expect(cat.name, 'Groceries');
      expect(cat.icon, 'cart');
    });
  });
}

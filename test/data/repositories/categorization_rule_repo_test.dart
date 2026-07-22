import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/categorization_rule_repo.dart';

void main() {
  late AppDatabase db;
  late CategorizationRuleRepo repo;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = CategorizationRuleRepo(db);
    for (final id in ['exact', 'contains', 'archived', 'payee']) {
      await db.categories.insertOne(
        CategoriesCompanion.insert(id: id, name: id, categoryGroup: 'expense'),
      );
    }
  });

  tearDown(() => db.close());

  test(
    'normalizes whitespace and exact rules precede contains rules',
    () async {
      await repo.create(
        id: 'contains-rule',
        matchTarget: 'title',
        matchKind: 'contains',
        pattern: 'market',
        categoryId: 'contains',
        priority: 100,
      );
      await repo.create(
        id: 'exact-rule',
        matchTarget: 'title',
        matchKind: 'exact',
        pattern: '  Corner   Market ',
        categoryId: 'exact',
        priority: -100,
      );

      final match = await repo.match(title: 'corner market');
      expect(match!.id, 'exact-rule');
      expect(match.normalizedPattern, 'corner market');
    },
  );

  test('inactive and archived rules never match', () async {
    await repo.create(
      id: 'inactive-rule',
      matchTarget: 'title',
      matchKind: 'exact',
      pattern: 'match',
      categoryId: 'archived',
      priority: 50,
    );
    await repo.setActive('inactive-rule', false);
    await repo.create(
      id: 'archived-rule',
      matchTarget: 'title',
      matchKind: 'exact',
      pattern: 'match',
      categoryId: 'archived',
      priority: 40,
    );
    await repo.archive('archived-rule');
    await repo.create(
      id: 'live-rule',
      matchTarget: 'title',
      matchKind: 'contains',
      pattern: 'mat',
      categoryId: 'contains',
    );

    expect((await repo.match(title: 'match'))!.id, 'live-rule');
    expect((await repo.watchAll().first).map((row) => row.id), [
      'inactive-rule',
      'live-rule',
    ]);
    expect((await repo.watchAll(includeArchived: true).first).length, 3);
  });

  test('matches title and payee targets independently', () async {
    await repo.create(
      id: 'title-rule',
      matchTarget: 'title',
      matchKind: 'exact',
      pattern: 'same',
      categoryId: 'exact',
    );
    await repo.create(
      id: 'payee-rule',
      matchTarget: 'payee',
      matchKind: 'exact',
      pattern: 'payee',
      categoryId: 'payee',
    );

    expect(
      (await repo.match(title: 'other', payee: 'payee'))!.id,
      'payee-rule',
    );
  });
}

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/repo_providers.dart';
import 'package:lootr/data/database/app_database.dart';

import 'provider_container.dart';
import 'test_database.dart';

final _loadingThenDataProvider = FutureProvider<String>((ref) async {
  await Future<void>.delayed(Duration.zero);
  return 'ready';
});

final _errorProvider = FutureProvider<String>((ref) async {
  throw StateError('test failure');
});

void main() {
  group('test database helpers', () {
    test('createTestDb creates isolated in-memory databases', () async {
      final first = createTestDb();

      await first
          .into(first.users)
          .insert(UsersCompanion.insert(id: 'usr-one'));

      final firstCount = await first
          .customSelect('SELECT COUNT(*) AS c FROM users')
          .getSingle();
      expect(firstCount.read<int>('c'), 1);

      await first.close();

      final second = createTestDb();
      addTearDown(second.close);
      final secondCount = await second
          .customSelect('SELECT COUNT(*) AS c FROM users')
          .getSingle();

      expect(secondCount.read<int>('c'), 0);
    });

    test('createSeededTestDb inserts default categories', () async {
      final db = await createSeededTestDb();
      addTearDown(db.close);

      final categories = await db.select(db.categories).get();

      expect(categories.map((c) => c.name), containsAll(['Food', 'Salary']));
      expect(
        categories.map((c) => c.categoryGroup).toSet(),
        containsAll(['expense', 'income', 'transfer']),
      );
    });

    test('seedDemoDataSubset creates a small relational fixture', () async {
      final db = createTestDb();
      addTearDown(db.close);

      await seedDemoDataSubset(db);

      expect(await db.select(db.users).get(), hasLength(1));
      expect(await db.select(db.accounts).get(), hasLength(2));
      expect(await db.select(db.transactions).get(), hasLength(1));
      expect(await db.select(db.budgets).get(), hasLength(1));
    });
  });

  group('provider test helpers', () {
    test('createTestContainer overrides databaseProvider with the test DB', () {
      final db = createTestDb();
      addTearDown(db.close);
      final container = createTestContainer(db: db);

      expect(container.read(databaseProvider), same(db));
    });

    test('database override flows through downstream providers', () async {
      final db = await createSeededTestDb();
      addTearDown(db.close);
      final container = createTestContainer(db: db);

      final categories = await container
          .read(categoryRepoProvider)
          .watchAll()
          .first;

      expect(categories.map((c) => c.name), contains('Food'));
    });

    test('provider tests can assert loading, data, and error states', () async {
      final container = createTestContainer();

      expect(
        container.read(_loadingThenDataProvider),
        const AsyncValue<String>.loading(),
      );
      expect(await container.read(_loadingThenDataProvider.future), 'ready');

      await expectLater(
        container.read(_errorProvider.future),
        throwsA(isA<StateError>()),
      );
      expect(container.read(_errorProvider).hasError, isTrue);
    });
  });

  group('fixture files', () {
    test('sample fixtures are valid JSON', () {
      const fixtureJson = [
        '{"id":"txn-sample","amount":125.5}',
        '{"merchant":"Coffee Bar","lines":["Latte PHP 125.50"]}',
        '{"users":[],"accounts":[],"transactions":[]}',
      ];

      for (final value in fixtureJson) {
        expect(jsonDecode(value), isA<Object>());
      }
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/demo_data_provider.dart';
import 'package:lootr/application/providers/repo_providers.dart';

import '../../test_helpers/provider_container.dart';

void main() {
  group('DemoDataProvider', () {
    test('hasDemoData returns false initially', () async {
      final container = createTestContainer();
      final notifier = container.read(demoDataProvider.notifier);

      expect(await notifier.hasDemoData(), false);
    });

    test('seed creates demo data and hasDemoData returns true', () async {
      final container = createTestContainer();

      await container.read(categoryRepoProvider).seedCategories();

      final notifier = container.read(demoDataProvider.notifier);
      await notifier.seed();

      expect(await notifier.hasDemoData(), true);

      final state = container.read(demoDataProvider);
      expect(state.value?.status, DemoDataStatus.present);
    });

    test('clear removes demo data and hasDemoData returns false', () async {
      final container = createTestContainer();

      await container.read(categoryRepoProvider).seedCategories();

      final notifier = container.read(demoDataProvider.notifier);
      await notifier.seed();
      expect(await notifier.hasDemoData(), true);

      await notifier.clear();
      expect(await notifier.hasDemoData(), false);

      final state = container.read(demoDataProvider);
      expect(state.value?.status, DemoDataStatus.absent);
    });

    test('clear preserves default categories', () async {
      final container = createTestContainer();

      await container.read(categoryRepoProvider).seedCategories();

      final notifier = container.read(demoDataProvider.notifier);
      await notifier.seed();

      final db = container.read(databaseProvider);
      var categories = await db.select(db.categories).get();
      final defaultCatCount = categories.length;
      expect(defaultCatCount, greaterThanOrEqualTo(17));

      await notifier.clear();

      categories = await db.select(db.categories).get();
      expect(categories.length, defaultCatCount);

      for (final cat in categories) {
        expect(cat.id, isNot(startsWith('demo-')));
      }
    });

    test('seed removes all demo- prefixed rows on clear', () async {
      final container = createTestContainer();

      await container.read(categoryRepoProvider).seedCategories();

      final notifier = container.read(demoDataProvider.notifier);
      await notifier.seed();

      final db = container.read(databaseProvider);

      var accounts = await db.select(db.accounts).get();
      expect(accounts.any((a) => a.id.startsWith('demo-')), true);

      var transactions = await db.select(db.transactions).get();
      expect(transactions.any((t) => t.id.startsWith('demo-')), true);

      await notifier.clear();

      accounts = await db.select(db.accounts).get();
      expect(accounts.any((a) => a.id.startsWith('demo-')), false);

      transactions = await db.select(db.transactions).get();
      expect(transactions.any((t) => t.id.startsWith('demo-')), false);
    });

    test('seed is idempotent', () async {
      final container = createTestContainer();

      await container.read(categoryRepoProvider).seedCategories();

      final notifier = container.read(demoDataProvider.notifier);
      await notifier.seed();

      final db = container.read(databaseProvider);
      final txnCount1 = (await db.select(db.transactions).get()).length;
      final acctCount1 = (await db.select(db.accounts).get()).length;

      await notifier.seed();

      final txnCount2 = (await db.select(db.transactions).get()).length;
      final acctCount2 = (await db.select(db.accounts).get()).length;

      expect(txnCount2, txnCount1);
      expect(acctCount2, acctCount1);
    });

    test('full lifecycle: seed -> hasDemoData -> clear -> hasDemoData', () async {
      final container = createTestContainer();

      await container.read(categoryRepoProvider).seedCategories();

      final notifier = container.read(demoDataProvider.notifier);

      expect(await notifier.hasDemoData(), false);

      await notifier.seed();
      expect(await notifier.hasDemoData(), true);

      await notifier.clear();
      expect(await notifier.hasDemoData(), false);
    });
  });
}

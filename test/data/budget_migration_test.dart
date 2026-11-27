import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/data/database/app_database.dart';

void main() {
  group('schema v1 -> current migration (budgets icon/color)', () {
    test('adds nullable icon/color columns and keeps existing rows', () async {
      // Build a raw v1 database: minimal tables the budgets FKs point at,
      // the v1 budgets table (no icon/color), one existing row, and
      // user_version = 1 so drift runs onUpgrade instead of onCreate.
      final executor = NativeDatabase.memory(
        setup: (raw) {
          raw
            ..execute('CREATE TABLE users (id TEXT NOT NULL PRIMARY KEY)')
            ..execute('CREATE TABLE households (id TEXT NOT NULL PRIMARY KEY)')
            ..execute('CREATE TABLE categories (id TEXT NOT NULL PRIMARY KEY)')
            ..execute('CREATE TABLE accounts (id TEXT NOT NULL PRIMARY KEY)')
            ..execute(
              'CREATE TABLE account_balance_snapshots '
              '(id TEXT NOT NULL PRIMARY KEY)',
            )
            ..execute(
              'CREATE TABLE transactions (id TEXT NOT NULL PRIMARY KEY)',
            )
            ..execute('CREATE TABLE transfers (id TEXT NOT NULL PRIMARY KEY)')
            ..execute(
              'CREATE TABLE recurring_templates '
              '(id TEXT NOT NULL PRIMARY KEY)',
            )
            ..execute('CREATE TABLE goals (id TEXT NOT NULL PRIMARY KEY)')
            ..execute(
              'CREATE TABLE debt_records (id TEXT NOT NULL PRIMARY KEY)',
            )
            ..execute('''
              CREATE TABLE budgets (
                id TEXT NOT NULL PRIMARY KEY,
                household_id TEXT NULL REFERENCES households (id),
                owner_user_id TEXT NOT NULL REFERENCES users (id),
                category_id TEXT NOT NULL REFERENCES categories (id),
                amount REAL NOT NULL,
                month INTEGER NOT NULL,
                year INTEGER NOT NULL,
                created_at TEXT NOT NULL
                  DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
                updated_at TEXT NOT NULL
                  DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
                deleted_at TEXT NULL,
                sync_status TEXT NOT NULL DEFAULT 'local_only',
                last_synced_at TEXT NULL
              )
            ''')
            ..execute("INSERT INTO users (id) VALUES ('usr-1')")
            ..execute("INSERT INTO categories (id) VALUES ('cat-1')")
            ..execute(
              "INSERT INTO budgets (id, owner_user_id, category_id, amount, month, year, created_at, updated_at) "
              "VALUES ('bud-1', 'usr-1', 'cat-1', 500.0, 1, 2026, "
              "'2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z')",
            )
            ..execute('PRAGMA user_version = 1');
        },
      );

      final db = AppDatabase(executor);
      addTearDown(db.close);

      // Existing row survives with null overrides.
      final migrated = await db.budgets.select().getSingle();
      expect(migrated.id, 'bud-1');
      expect(migrated.icon, isNull);
      expect(migrated.color, isNull);

      // New rows can persist overrides.
      await db.budgets.insertOne(
        BudgetsCompanion.insert(
          id: 'bud-2',
          ownerUserId: 'usr-1',
          categoryId: 'cat-1',
          amount: 900,
          month: 2,
          year: 2026,
          icon: const Value('travel'),
          color: const Value('#E11D48'),
        ),
      );
      final inserted =
          await (db.budgets.select()..where((t) => t.id.equals('bud-2')))
              .getSingle();
      expect(inserted.icon, 'travel');
      expect(inserted.color, '#E11D48');

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 4);
    });

    test('fresh database creates budgets with icon/color columns', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);

      await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
      await db.categories.insertOne(
        CategoriesCompanion.insert(
          id: 'cat-1',
          name: 'Food',
          categoryGroup: 'expense',
        ),
      );
      await db.budgets.insertOne(
        BudgetsCompanion.insert(
          id: 'bud-1',
          ownerUserId: 'usr-1',
          categoryId: 'cat-1',
          amount: 100,
          month: 1,
          year: 2026,
          icon: const Value('dining'),
          color: const Value('#059669'),
        ),
      );

      final row = await db.budgets.select().getSingle();
      expect(row.icon, 'dining');
      expect(row.color, '#059669');
    });
  });
}

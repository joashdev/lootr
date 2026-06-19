import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/budget_repo.dart';

void main() {
  late AppDatabase db;
  late BudgetRepo repo;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = BudgetRepo(db);

    await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
    await db.categories.insertOne(
      CategoriesCompanion.insert(
        id: 'cat-food',
        name: 'Food',
        categoryGroup: 'expense',
      ),
    );
    await db.accounts.insertOne(
      AccountsCompanion.insert(
        id: 'acc-1',
        ownerUserId: 'usr-1',
        name: 'Cash',
        accountType: 'cash',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('BudgetRepo', () {
    test('create inserts and returns id', () async {
      final id = await repo.create(BudgetsCompanion.insert(
        id: 'bud-1',
        ownerUserId: 'usr-1',
        categoryId: 'cat-food',
        amount: 500.0,
        month: 6,
        year: 2026,
      ));
      expect(id, 'bud-1');
    });

    test('watchAll filters by month and year', () async {
      await repo.create(BudgetsCompanion.insert(
        id: 'bud-jun',
        ownerUserId: 'usr-1',
        categoryId: 'cat-food',
        amount: 500.0,
        month: 6,
        year: 2026,
      ));
      await repo.create(BudgetsCompanion.insert(
        id: 'bud-jul',
        ownerUserId: 'usr-1',
        categoryId: 'cat-food',
        amount: 600.0,
        month: 7,
        year: 2026,
      ));

      final june = await repo.watchAll(month: 6, year: 2026).first;
      expect(june.length, 1);
      expect(june.first.id, 'bud-jun');

      final all = await repo.watchAll().first;
      expect(all.length, 2);
    });

    test('watchSpentForBudget returns SUM of expense transactions for period',
        () async {
      await repo.create(BudgetsCompanion.insert(
        id: 'bud-1',
        ownerUserId: 'usr-1',
        categoryId: 'cat-food',
        amount: 500.0,
        month: 6,
        year: 2026,
      ));

      await db.transactions.insertOne(
        TransactionsCompanion.insert(
          id: 'txn-1',
          accountId: 'acc-1',
          amount: 100.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 15),
          categoryId: const Value('cat-food'),
        ),
      );
      await db.transactions.insertOne(
        TransactionsCompanion.insert(
          id: 'txn-2',
          accountId: 'acc-1',
          amount: 50.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 20),
          categoryId: const Value('cat-food'),
        ),
      );
      await db.transactions.insertOne(
        TransactionsCompanion.insert(
          id: 'txn-3',
          accountId: 'acc-1',
          amount: 200.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 7, 1),
          categoryId: const Value('cat-food'),
        ),
      );

      final spent = await repo.watchSpentForBudget('bud-1').first;
      expect(spent, 150.0);
    });

    test('watchSpentForBudget excludes non-expense transactions', () async {
      await repo.create(BudgetsCompanion.insert(
        id: 'bud-1',
        ownerUserId: 'usr-1',
        categoryId: 'cat-food',
        amount: 500.0,
        month: 6,
        year: 2026,
      ));

      await db.transactions.insertOne(
        TransactionsCompanion.insert(
          id: 'txn-inc',
          accountId: 'acc-1',
          amount: 100.0,
          transactionDirection: 'income',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 15),
          categoryId: const Value('cat-food'),
        ),
      );

      final spent = await repo.watchSpentForBudget('bud-1').first;
      expect(spent, 0.0);
    });

    test('watchSpentForBudget excludes deleted transactions', () async {
      await repo.create(BudgetsCompanion.insert(
        id: 'bud-1',
        ownerUserId: 'usr-1',
        categoryId: 'cat-food',
        amount: 500.0,
        month: 6,
        year: 2026,
      ));

      await db.transactions.insertOne(
        TransactionsCompanion.insert(
          id: 'txn-del',
          accountId: 'acc-1',
          amount: 100.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 15),
          categoryId: const Value('cat-food'),
        ),
      );

      await (db.update(db.transactions)
            ..where((t) => t.id.equals('txn-del')))
          .write(TransactionsCompanion(
        deletedAt: Value(DateTime.now()),
      ));

      final spent = await repo.watchSpentForBudget('bud-1').first;
      expect(spent, 0.0);
    });

    test('softDelete sets deleted_at', () async {
      await repo.create(BudgetsCompanion.insert(
        id: 'bud-1',
        ownerUserId: 'usr-1',
        categoryId: 'cat-food',
        amount: 500.0,
        month: 6,
        year: 2026,
      ));

      await repo.softDelete('bud-1');

      final budgets = await (db.select(db.budgets)..limit(1)).getSingle();
      expect(budgets.deletedAt, isNotNull);
    });
  });
}

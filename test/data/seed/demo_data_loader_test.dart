import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/seed/category_seeds.dart';
import 'package:lootr/data/seed/demo_data_loader.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.inMemory();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedCategories() async {
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.categories, CategorySeeds.toCompanions());
    });
  }

  group('DemoDataLoader', () {
    test('creates 4 accounts', () async {
      await seedCategories();
      const userId = 'demo-user-1';
      await db.into(db.users).insertOnConflictUpdate(
            UsersCompanion.insert(id: userId, email: const Value('test@test.com')),
          );

      final loader = DemoDataLoader();
      final result = await loader.load(db, userId: userId);

      expect(result.accountIds.length, 4);
      final accounts = await db.select(db.accounts).get();
      expect(accounts.length, 4);
    });

    test('creates 15 payees', () async {
      await seedCategories();
      const userId = 'demo-user-1';
      await db.into(db.users).insertOnConflictUpdate(
            UsersCompanion.insert(id: userId, email: const Value('test@test.com')),
          );

      final loader = DemoDataLoader();
      final result = await loader.load(db, userId: userId);

      expect(result.payeeIds.length, 15);
    });

    test('creates 40+ transactions', () async {
      await seedCategories();
      const userId = 'demo-user-1';
      await db.into(db.users).insertOnConflictUpdate(
            UsersCompanion.insert(id: userId, email: const Value('test@test.com')),
          );

      final loader = DemoDataLoader();
      final result = await loader.load(db, userId: userId);

      expect(result.transactionIds.length, greaterThanOrEqualTo(40));
    });

    test('creates 4 budgets', () async {
      await seedCategories();
      const userId = 'demo-user-1';
      await db.into(db.users).insertOnConflictUpdate(
            UsersCompanion.insert(id: userId, email: const Value('test@test.com')),
          );

      final loader = DemoDataLoader();
      final result = await loader.load(db, userId: userId);

      expect(result.budgetIds.length, 4);
    });

    test('creates 2 goals', () async {
      await seedCategories();
      const userId = 'demo-user-1';
      await db.into(db.users).insertOnConflictUpdate(
            UsersCompanion.insert(id: userId, email: const Value('test@test.com')),
          );

      final loader = DemoDataLoader();
      final result = await loader.load(db, userId: userId);

      expect(result.goalIds.length, 2);
    });

    test('accounts have correct names and balances', () async {
      await seedCategories();
      const userId = 'demo-user-1';
      await db.into(db.users).insertOnConflictUpdate(
            UsersCompanion.insert(id: userId, email: const Value('test@test.com')),
          );

      final loader = DemoDataLoader();
      await loader.load(db, userId: userId);

      final accounts = await db.select(db.accounts).get();
      final names = accounts.map((a) => a.name).toSet();
      expect(names, containsAll(['BDO Savings', 'GCash', 'BPI Checking', 'Cash']));

      final bdo = accounts.firstWhere((a) => a.name == 'BDO Savings');
      expect(bdo.balance, 45000.0);
      expect(bdo.accountType, 'bank');

      final gcash = accounts.firstWhere((a) => a.name == 'GCash');
      expect(gcash.balance, 3200.0);
      expect(gcash.accountType, 'ewallet');

      final bpi = accounts.firstWhere((a) => a.name == 'BPI Checking');
      expect(bpi.balance, 120000.0);

      final cash = accounts.firstWhere((a) => a.name == 'Cash');
      expect(cash.balance, 1500.0);
      expect(cash.accountType, 'cash');
    });

    test('payees have Philippine names', () async {
      await seedCategories();
      const userId = 'demo-user-1';
      await db.into(db.users).insertOnConflictUpdate(
            UsersCompanion.insert(id: userId, email: const Value('test@test.com')),
          );

      final loader = DemoDataLoader();
      await loader.load(db, userId: userId);

      final payees = await db.select(db.payees).get();
      final names = payees.map((p) => p.normalizedName).toSet();
      expect(names, contains('jollibee'));
      expect(names, contains('meralco'));
      expect(names, contains('grab'));
      expect(names, contains('angkas'));
    });

    test('transaction amounts are realistic PHP values', () async {
      await seedCategories();
      const userId = 'demo-user-1';
      await db.into(db.users).insertOnConflictUpdate(
            UsersCompanion.insert(id: userId, email: const Value('test@test.com')),
          );

      final loader = DemoDataLoader();
      await loader.load(db, userId: userId);

      final transactions = await db.select(db.transactions).get();
      for (final txn in transactions) {
        expect(txn.amount, greaterThan(0));
      }

      final maxAmount = transactions
          .map((t) => t.amount)
          .reduce((a, b) => a > b ? a : b);
      expect(maxAmount, 35000.0);
    });

    test('transactions include income and expense', () async {
      await seedCategories();
      const userId = 'demo-user-1';
      await db.into(db.users).insertOnConflictUpdate(
            UsersCompanion.insert(id: userId, email: const Value('test@test.com')),
          );

      final loader = DemoDataLoader();
      await loader.load(db, userId: userId);

      final income =
          await (db.select(db.transactions)
            ..where((t) => t.transactionDirection.equals('income')))
              .get();
      expect(income.length, greaterThan(0));

      final expense =
          await (db.select(db.transactions)
            ..where((t) => t.transactionDirection.equals('expense')))
              .get();
      expect(expense.length, greaterThan(income.length));
    });

    test('transactions span 2 months', () async {
      await seedCategories();
      const userId = 'demo-user-1';
      await db.into(db.users).insertOnConflictUpdate(
            UsersCompanion.insert(id: userId, email: const Value('test@test.com')),
          );

      final loader = DemoDataLoader();
      await loader.load(db, userId: userId);

      final transactions = await db.select(db.transactions).get();
      final months =
          transactions.map((t) => t.occurredAt.month).toSet();
      expect(months.length, greaterThanOrEqualTo(2));
    });

    test('salary transactions have salary subtype', () async {
      await seedCategories();
      const userId = 'demo-user-1';
      await db.into(db.users).insertOnConflictUpdate(
            UsersCompanion.insert(id: userId, email: const Value('test@test.com')),
          );

      final loader = DemoDataLoader();
      await loader.load(db, userId: userId);

      final salaryTxns = await (db.select(db.transactions)
            ..where((t) => t.transactionSubtype.equals('salary')))
          .get();
      expect(salaryTxns.length, 3);
      for (final txn in salaryTxns) {
        expect(txn.transactionDirection, 'income');
        expect(txn.amount, 35000.0);
      }
    });

    test('subscription transactions have subscription subtype', () async {
      await seedCategories();
      const userId = 'demo-user-1';
      await db.into(db.users).insertOnConflictUpdate(
            UsersCompanion.insert(id: userId, email: const Value('test@test.com')),
          );

      final loader = DemoDataLoader();
      await loader.load(db, userId: userId);

      final subTxns = await (db.select(db.transactions)
            ..where((t) => t.transactionSubtype.equals('subscription')))
          .get();
      expect(subTxns.length, 6);
    });

    test('goals have correct targets and current amounts', () async {
      await seedCategories();
      const userId = 'demo-user-1';
      await db.into(db.users).insertOnConflictUpdate(
            UsersCompanion.insert(id: userId, email: const Value('test@test.com')),
          );

      final loader = DemoDataLoader();
      await loader.load(db, userId: userId);

      final goals = await db.select(db.goals).get();
      expect(goals.length, 2);

      final emergency = goals.firstWhere((g) => g.name == 'Emergency Fund');
      expect(emergency.targetAmount, 100000.0);
      expect(emergency.currentAmount, 45000.0);
      expect(emergency.goalType, 'emergency_fund');

      final japan = goals.firstWhere((g) => g.name == 'Vacation to Japan');
      expect(japan.targetAmount, 80000.0);
      expect(japan.currentAmount, 20000.0);
      expect(japan.goalType, 'travel');
    });

    test('budgets have correct amounts', () async {
      await seedCategories();
      const userId = 'demo-user-1';
      await db.into(db.users).insertOnConflictUpdate(
            UsersCompanion.insert(id: userId, email: const Value('test@test.com')),
          );

      final loader = DemoDataLoader();
      await loader.load(db, userId: userId);

      final budgets = await db.select(db.budgets).get();
      expect(budgets.length, 4);

      final amounts = budgets.map((b) => b.amount).toSet();
      expect(amounts, containsAll([15000.0, 5000.0, 8000.0, 3000.0]));
    });

    test('seeding is idempotent', () async {
      await seedCategories();
      const userId = 'demo-user-1';
      await db.into(db.users).insertOnConflictUpdate(
            UsersCompanion.insert(id: userId, email: const Value('test@test.com')),
          );

      final loader = DemoDataLoader();
      await loader.load(db, userId: userId);

      final accountCount1 = (await db.select(db.accounts).get()).length;
      final txnCount1 = (await db.select(db.transactions).get()).length;

      await loader.load(db, userId: userId);

      final accountCount2 = (await db.select(db.accounts).get()).length;
      final txnCount2 = (await db.select(db.transactions).get()).length;

      expect(accountCount2, accountCount1);
      expect(txnCount2, txnCount1);
    });

    test('all IDs are prefixed demo-', () async {
      await seedCategories();
      const userId = 'demo-user-1';
      await db.into(db.users).insertOnConflictUpdate(
            UsersCompanion.insert(id: userId, email: const Value('test@test.com')),
          );

      final loader = DemoDataLoader();
      final result = await loader.load(db, userId: userId);

      for (final id in result.accountIds) {
        expect(id, startsWith('demo-'));
      }
      for (final id in result.payeeIds) {
        expect(id, startsWith('demo-'));
      }
      for (final id in result.transactionIds) {
        expect(id, startsWith('demo-'));
      }
      for (final id in result.budgetIds) {
        expect(id, startsWith('demo-'));
      }
      for (final id in result.goalIds) {
        expect(id, startsWith('demo-'));
      }
    });
  });
}

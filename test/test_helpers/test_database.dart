import 'package:drift/drift.dart';
import 'package:lootr/data/database/app_database.dart';

AppDatabase createTestDb() => AppDatabase.inMemory();

Future<AppDatabase> createSeededTestDb() async {
  final db = createTestDb();
  await seedDefaultCategories(db);
  return db;
}

Future<void> seedDefaultCategories(AppDatabase db) async {
  await db.batch((batch) {
    batch.insertAllOnConflictUpdate(db.categories, [
      CategoriesCompanion.insert(
        id: 'cat-test-food',
        name: 'Food',
        categoryGroup: 'expense',
        icon: const Value('utensils'),
        color: const Value('#ef4444'),
        syncStatus: const Value('synced'),
      ),
      CategoriesCompanion.insert(
        id: 'cat-test-transport',
        name: 'Transport',
        categoryGroup: 'expense',
        icon: const Value('car'),
        color: const Value('#3b82f6'),
        syncStatus: const Value('synced'),
      ),
      CategoriesCompanion.insert(
        id: 'cat-test-salary',
        name: 'Salary',
        categoryGroup: 'income',
        icon: const Value('briefcase'),
        color: const Value('#22c55e'),
        syncStatus: const Value('synced'),
      ),
      CategoriesCompanion.insert(
        id: 'cat-test-transfer',
        name: 'Transfer',
        categoryGroup: 'transfer',
        icon: const Value('repeat'),
        color: const Value('#64748b'),
        syncStatus: const Value('synced'),
      ),
    ]);
  });
}

Future<void> seedDemoDataSubset(AppDatabase db) async {
  await seedDefaultCategories(db);
  final now = DateTime(2026, 6, 21, 9);

  await db
      .into(db.users)
      .insertOnConflictUpdate(
        UsersCompanion.insert(
          id: 'usr-test-demo',
          displayName: const Value('Demo User'),
          currencyCode: const Value('PHP'),
        ),
      );
  await db
      .into(db.accounts)
      .insertOnConflictUpdate(
        AccountsCompanion.insert(
          id: 'acc-test-wallet',
          ownerUserId: 'usr-test-demo',
          name: 'Wallet',
          accountType: 'cash',
          balance: const Value(1500),
        ),
      );
  await db
      .into(db.accounts)
      .insertOnConflictUpdate(
        AccountsCompanion.insert(
          id: 'acc-test-bank',
          ownerUserId: 'usr-test-demo',
          name: 'Bank',
          accountType: 'bank',
          balance: const Value(10000),
        ),
      );
  await db
      .into(db.payees)
      .insertOnConflictUpdate(
        PayeesCompanion.insert(
          id: 'pay-test-grocery',
          normalizedName: 'green grocer',
          displayName: const Value('Green Grocer'),
        ),
      );
  await db
      .into(db.transactions)
      .insertOnConflictUpdate(
        TransactionsCompanion.insert(
          id: 'txn-test-grocery',
          accountId: 'acc-test-wallet',
          categoryId: const Value('cat-test-food'),
          payeeId: const Value('pay-test-grocery'),
          amount: 250,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: now,
          note: const Value('Demo grocery run'),
        ),
      );
  await db
      .into(db.budgets)
      .insertOnConflictUpdate(
        BudgetsCompanion.insert(
          id: 'bud-test-food',
          ownerUserId: 'usr-test-demo',
          categoryId: 'cat-test-food',
          amount: 5000,
          month: now.month,
          year: now.year,
        ),
      );
}

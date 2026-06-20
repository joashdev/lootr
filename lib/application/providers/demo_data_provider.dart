import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull;
import '../../data/database/app_database.dart';
import 'database_provider.dart';
import 'repo_providers.dart';

enum DemoDataStatus { absent, loading, present }

class DemoDataState {
  final DemoDataStatus status;

  const DemoDataState({this.status = DemoDataStatus.absent});
}

class DemoDataNotifier extends AsyncNotifier<DemoDataState> {
  @override
  Future<DemoDataState> build() async {
    return const DemoDataState();
  }

  Future<void> seed() async {
    state = const AsyncData(DemoDataState(status: DemoDataStatus.loading));
    final db = ref.read(databaseProvider);

    final now = DateTime.now();

    const userId = 'demo-user-1';
    await db.into(db.users).insert(
          UsersCompanion.insert(
              id: userId, email: const Value('demo@lootr.app')),
        );

    const cashId = 'demo-acc-cash';
    const bankId = 'demo-acc-bank';
    const ewalletId = 'demo-acc-ewallet';
    const creditId = 'demo-acc-credit';

    for (final acc in [
      AccountsCompanion.insert(
          id: cashId,
          ownerUserId: userId,
          name: 'Cash',
          accountType: 'cash',
          balance: const Value(2500.0)),
      AccountsCompanion.insert(
          id: bankId,
          ownerUserId: userId,
          name: 'Bank',
          accountType: 'bank',
          balance: const Value(15000.0)),
      AccountsCompanion.insert(
          id: ewalletId,
          ownerUserId: userId,
          name: 'E-Wallet',
          accountType: 'ewallet',
          balance: const Value(800.0)),
      AccountsCompanion.insert(
          id: creditId,
          ownerUserId: userId,
          name: 'Credit Card',
          accountType: 'credit_card',
          balance: const Value(-3500.0)),
    ]) {
      await db.into(db.accounts).insert(acc);
    }

    const catFood = 'demo-cat-food';
    const catTransport = 'demo-cat-transport';
    const catSalary = 'demo-cat-salary';
    const catEntertainment = 'demo-cat-entertainment';
    const catUtilities = 'demo-cat-utilities';
    const catShopping = 'demo-cat-shopping';

    for (final cat in [
      CategoriesCompanion.insert(
          id: catFood, name: 'Food & Dining', categoryGroup: 'expense'),
      CategoriesCompanion.insert(
          id: catTransport, name: 'Transport', categoryGroup: 'expense'),
      CategoriesCompanion.insert(
          id: catSalary, name: 'Salary', categoryGroup: 'income'),
      CategoriesCompanion.insert(
          id: catEntertainment,
          name: 'Entertainment',
          categoryGroup: 'expense'),
      CategoriesCompanion.insert(
          id: catUtilities, name: 'Utilities', categoryGroup: 'expense'),
      CategoriesCompanion.insert(
          id: catShopping, name: 'Shopping', categoryGroup: 'expense'),
    ]) {
      await db.into(db.categories).insert(cat);
    }

    const payeeGrocery = 'demo-pay-grocery';
    const payeeEmployer = 'demo-pay-employer';
    const payeeNetflix = 'demo-pay-netflix';
    const payeeElectric = 'demo-pay-electric';

    for (final pay in [
      PayeesCompanion.insert(
          id: payeeGrocery, normalizedName: 'grocery-store'),
      PayeesCompanion.insert(id: payeeEmployer, normalizedName: 'acme-corp'),
      PayeesCompanion.insert(id: payeeNetflix, normalizedName: 'netflix'),
      PayeesCompanion.insert(
          id: payeeElectric, normalizedName: 'electric-company'),
    ]) {
      await db.into(db.payees).insert(pay);
    }

    final transactions = <TransactionsCompanion>[];
    for (var i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: 29 - i));
      transactions.addAll([
        if (i % 7 == 0)
          TransactionsCompanion.insert(
            id: 'demo-txn-s$i',
            accountId: bankId,
            amount: 500.0,
            transactionDirection: 'expense',
            transactionMode: 'one_time',
            categoryId: const Value(catFood),
            payeeId: const Value(payeeGrocery),
            note: const Value('Weekly groceries'),
            occurredAt: date,
            syncStatus: const Value('local_only'),
          ),
        TransactionsCompanion.insert(
          id: 'demo-txn-t$i',
          accountId: cashId,
          amount: 120.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          categoryId: const Value(catTransport),
          note: const Value('Commute'),
          occurredAt: date,
          syncStatus: const Value('local_only'),
        ),
        if (i % 15 == 0)
          TransactionsCompanion.insert(
            id: 'demo-txn-sal$i',
            accountId: bankId,
            amount: 8000.0,
            transactionDirection: 'income',
            transactionMode: 'one_time',
            categoryId: const Value(catSalary),
            payeeId: const Value(payeeEmployer),
            note: const Value('Bi-monthly salary'),
            occurredAt: date,
            syncStatus: const Value('local_only'),
          ),
      ]);
    }

    for (final txn in transactions) {
      await db.into(db.transactions).insert(txn);
    }

    final currentMonth = now.month;
    final currentYear = now.year;

    for (final budget in [
      BudgetsCompanion.insert(
        id: 'demo-budget-food',
        ownerUserId: userId,
        categoryId: catFood,
        amount: 4000.0,
        month: currentMonth,
        year: currentYear,
      ),
      BudgetsCompanion.insert(
        id: 'demo-budget-transport',
        ownerUserId: userId,
        categoryId: catTransport,
        amount: 2000.0,
        month: currentMonth,
        year: currentYear,
      ),
      BudgetsCompanion.insert(
        id: 'demo-budget-entertainment',
        ownerUserId: userId,
        categoryId: catEntertainment,
        amount: 1500.0,
        month: currentMonth,
        year: currentYear,
      ),
      BudgetsCompanion.insert(
        id: 'demo-budget-shopping',
        ownerUserId: userId,
        categoryId: catShopping,
        amount: 3000.0,
        month: currentMonth,
        year: currentYear,
      ),
    ]) {
      await db.into(db.budgets).insert(budget);
    }

    await db.into(db.goals).insert(GoalsCompanion.insert(
          id: 'demo-goal-emergency',
          ownerUserId: userId,
          name: 'Emergency Fund',
          goalType: 'emergency_fund',
          targetAmount: 50000.0,
          currentAmount: const Value(12000.0),
        ));
    await db.into(db.goals).insert(GoalsCompanion.insert(
          id: 'demo-goal-travel',
          ownerUserId: userId,
          name: 'Vacation Fund',
          goalType: 'travel',
          targetAmount: 30000.0,
          currentAmount: const Value(5000.0),
        ));

    await db.into(db.recurringTemplates).insert(
          RecurringTemplatesCompanion.insert(
            id: 'demo-rec-netflix',
            accountId: creditId,
            categoryId: const Value(catEntertainment),
            payeeId: const Value(payeeNetflix),
            amount: 549.0,
            recurrenceRule: 'monthly',
            nextOccurrenceAt: Value(now.add(const Duration(days: 3))),
          ),
        );
    await db.into(db.recurringTemplates).insert(
          RecurringTemplatesCompanion.insert(
            id: 'demo-rec-electric',
            accountId: bankId,
            categoryId: const Value(catUtilities),
            payeeId: const Value(payeeElectric),
            amount: 2500.0,
            recurrenceRule: 'monthly',
            nextOccurrenceAt: Value(now.add(const Duration(days: 10))),
          ),
        );

    await db.into(db.debtRecords).insert(DebtRecordsCompanion.insert(
          id: 'demo-debt-friend',
          ownerUserId: userId,
          counterpartyName: 'Friend',
          debtDirection: 'borrowed',
          amount: 5000.0,
          remainingBalance: 3000.0,
          status: 'active',
        ));

    final syncRepo = ref.read(syncMetadataRepoProvider);
    await syncRepo.set('demo_data_seeded', 'true');

    state = const AsyncData(DemoDataState(status: DemoDataStatus.present));
  }

  Future<void> clear() async {
    final db = ref.read(databaseProvider);

    await (db.delete(db.transactions)..where((t) => t.id.like('demo-%'))).go();
    await (db.delete(db.accounts)..where((t) => t.id.like('demo-%'))).go();
    await (db.delete(db.categories)..where((t) => t.id.like('demo-%'))).go();
    await (db.delete(db.payees)..where((t) => t.id.like('demo-%'))).go();
    await (db.delete(db.budgets)..where((t) => t.id.like('demo-%'))).go();
    await (db.delete(db.goals)..where((t) => t.id.like('demo-%'))).go();
    await (db.delete(db.recurringTemplates)..where((t) => t.id.like('demo-%'))).go();
    await (db.delete(db.debtRecords)..where((t) => t.id.like('demo-%'))).go();
    await (db.delete(db.users)..where((t) => t.id.like('demo-%'))).go();

    final syncRepo = ref.read(syncMetadataRepoProvider);
    await syncRepo.set('demo_data_seeded', 'false');

    state = const AsyncData(DemoDataState(status: DemoDataStatus.absent));
  }

  Future<bool> hasDemoData() async {
    final syncRepo = ref.read(syncMetadataRepoProvider);
    final value = await syncRepo.get('demo_data_seeded');
    return value == 'true';
  }
}

final demoDataProvider =
    AsyncNotifierProvider<DemoDataNotifier, DemoDataState>(
  DemoDataNotifier.new,
);

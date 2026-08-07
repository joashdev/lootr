import 'package:drift/drift.dart' hide isNull;

import '../database/app_database.dart';
import 'demo_data_manifest.dart';

class DemoDataResult {
  final List<String> accountIds;
  final List<String> payeeIds;
  final List<String> transactionIds;
  final List<String> budgetIds;
  final List<String> goalIds;
  final List<String> debtIds;
  final List<String> recurringIds;

  const DemoDataResult({
    required this.accountIds,
    required this.payeeIds,
    required this.transactionIds,
    required this.budgetIds,
    required this.goalIds,
    required this.debtIds,
    required this.recurringIds,
  });
}

class DemoDataLoader {
  Future<DemoDataResult> load(AppDatabase db, {required String userId}) async {
    final now = DateTime.now();
    final curYear = now.year;
    final curMonth = now.month;
    final prevMonth = curMonth == 1 ? 12 : curMonth - 1;
    final prevYear = curMonth == 1 ? curYear - 1 : curYear;

    final accountIds = DemoDataManifest.accountIds;
    final bdo = accountIds[0];
    final gcash = accountIds[1];
    final bpi = accountIds[2];
    final cash = accountIds[3];

    final payeeIds = DemoDataManifest.payeeIds;

    final jollibee = payeeIds[0];
    final mcdonalds = payeeIds[1];
    final mercuryDrug = payeeIds[2];
    final smSupermarket = payeeIds[3];
    final grab = payeeIds[4];
    final angkas = payeeIds[5];
    final meralco = payeeIds[6];
    final pldt = payeeIds[7];
    final converge = payeeIds[8];
    final landers = payeeIds[9];
    final shopee = payeeIds[10];
    final lazada = payeeIds[11];
    final sevenEleven = payeeIds[12];
    final starbucks = payeeIds[13];
    final puregold = payeeIds[14];
    final netflix = payeeIds[15];

    const categoryFood = 'default-cat-food-dining';
    const categoryTransport = 'default-cat-transportation';
    const categoryShopping = 'default-cat-shopping';
    const categoryBills = 'default-cat-bills-utilities';
    const categoryHealth = 'default-cat-health-fitness';
    const categoryEntertainment = 'default-cat-entertainment';
    const categorySalary = 'default-cat-salary';
    const categoryHousing = 'default-cat-housing';

    final transactionIds = <String>[];
    final transactions = <TransactionsCompanion>[];

    void addTxn({
      required String id,
      required String accountId,
      required double amount,
      required String direction,
      required String categoryId,
      String? payeeId,
      DateTime? occurredAt,
      String? note,
      String? subtype,
    }) {
      final expectedId = DemoDataManifest.transactionIds[transactionIds.length];
      if (id != expectedId) {
        throw StateError('Sample transaction manifest is out of sync.');
      }
      transactionIds.add(id);
      transactions.add(
        TransactionsCompanion.insert(
          id: id,
          accountId: accountId,
          amount: amount,
          transactionDirection: direction,
          transactionMode: 'one_time',
          categoryId: Value(categoryId),
          payeeId: payeeId != null ? Value(payeeId) : const Value.absent(),
          note: note != null ? Value(note) : const Value.absent(),
          transactionSubtype: subtype != null
              ? Value(subtype)
              : const Value.absent(),
          occurredAt: occurredAt ?? DateTime.now(),
          syncStatus: const Value('local_only'),
        ),
      );
    }

    // === MAY 2026 ===
    // Bills first of month
    addTxn(
      id: 'demo-txn-m001',
      accountId: bpi,
      amount: 3500,
      direction: 'expense',
      categoryId: categoryBills,
      payeeId: meralco,
      occurredAt: DateTime(prevYear, prevMonth, 1),
      note: 'Meralco bill — May',
      subtype: 'subscription',
    );
    addTxn(
      id: 'demo-txn-m002',
      accountId: bpi,
      amount: 1899,
      direction: 'expense',
      categoryId: categoryBills,
      payeeId: pldt,
      occurredAt: DateTime(prevYear, prevMonth, 1),
      note: 'PLDT bill — May',
      subtype: 'subscription',
    );
    addTxn(
      id: 'demo-txn-m003',
      accountId: bpi,
      amount: 1500,
      direction: 'expense',
      categoryId: categoryBills,
      payeeId: converge,
      occurredAt: DateTime(prevYear, prevMonth, 2),
      note: 'Converge internet — May',
      subtype: 'subscription',
    );
    // Weekly groceries (Sundays)
    addTxn(
      id: 'demo-txn-m004',
      accountId: bdo,
      amount: 2200,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: smSupermarket,
      occurredAt: DateTime(prevYear, prevMonth, 3),
      note: 'Weekly groceries',
    );
    // Daily expenses
    addTxn(
      id: 'demo-txn-m005',
      accountId: gcash,
      amount: 185,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: jollibee,
      occurredAt: DateTime(prevYear, prevMonth, 4),
      note: 'Jollibee lunch',
    );
    addTxn(
      id: 'demo-txn-m006',
      accountId: gcash,
      amount: 125,
      direction: 'expense',
      categoryId: categoryTransport,
      payeeId: angkas,
      occurredAt: DateTime(prevYear, prevMonth, 5),
      note: 'Angkas ride to work',
    );
    addTxn(
      id: 'demo-txn-m007',
      accountId: gcash,
      amount: 350,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: grab,
      occurredAt: DateTime(prevYear, prevMonth, 6),
      note: 'GrabFood dinner',
    );
    addTxn(
      id: 'demo-txn-m008',
      accountId: bdo,
      amount: 620,
      direction: 'expense',
      categoryId: categoryHealth,
      payeeId: mercuryDrug,
      occurredAt: DateTime(prevYear, prevMonth, 7),
      note: 'Vitamins & medicine',
    );
    addTxn(
      id: 'demo-txn-m009',
      accountId: gcash,
      amount: 195,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: starbucks,
      occurredAt: DateTime(prevYear, prevMonth, 8),
      note: 'Morning coffee',
    );
    addTxn(
      id: 'demo-txn-m010',
      accountId: bdo,
      amount: 1850,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: puregold,
      occurredAt: DateTime(prevYear, prevMonth, 10),
      note: 'Weekly groceries',
    );
    addTxn(
      id: 'demo-txn-m011',
      accountId: gcash,
      amount: 450,
      direction: 'expense',
      categoryId: categoryShopping,
      payeeId: shopee,
      occurredAt: DateTime(prevYear, prevMonth, 12),
      note: 'Phone case',
    );
    addTxn(
      id: 'demo-txn-m012',
      accountId: bdo,
      amount: 700,
      direction: 'expense',
      categoryId: categoryShopping,
      payeeId: landers,
      occurredAt: DateTime(prevYear, prevMonth, 13),
      note: 'Landers membership renewal',
    );
    // Bi-weekly salary
    addTxn(
      id: 'demo-txn-m013',
      accountId: bpi,
      amount: 35000,
      direction: 'income',
      categoryId: categorySalary,
      occurredAt: DateTime(prevYear, prevMonth, 15),
      note: 'Bi-monthly salary',
      subtype: 'salary',
    );
    addTxn(
      id: 'demo-txn-m014',
      accountId: cash,
      amount: 85,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: sevenEleven,
      occurredAt: DateTime(prevYear, prevMonth, 15),
      note: 'Slurpee & siopao',
    );
    addTxn(
      id: 'demo-txn-m015',
      accountId: bdo,
      amount: 2400,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: smSupermarket,
      occurredAt: DateTime(prevYear, prevMonth, 17),
      note: 'Weekly groceries',
    );
    addTxn(
      id: 'demo-txn-m016',
      accountId: gcash,
      amount: 250,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: mcdonalds,
      occurredAt: DateTime(prevYear, prevMonth, 18),
      note: "McDonald's dinner",
    );
    addTxn(
      id: 'demo-txn-m017',
      accountId: gcash,
      amount: 1250,
      direction: 'expense',
      categoryId: categoryShopping,
      payeeId: lazada,
      occurredAt: DateTime(prevYear, prevMonth, 19),
      note: 'Kitchen appliance',
    );
    addTxn(
      id: 'demo-txn-m018',
      accountId: gcash,
      amount: 110,
      direction: 'expense',
      categoryId: categoryTransport,
      payeeId: angkas,
      occurredAt: DateTime(prevYear, prevMonth, 20),
      note: 'Angkas ride home',
    );
    addTxn(
      id: 'demo-txn-m019',
      accountId: cash,
      amount: 175,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: starbucks,
      occurredAt: DateTime(prevYear, prevMonth, 22),
      note: 'Afternoon coffee',
    );
    addTxn(
      id: 'demo-txn-m020',
      accountId: bdo,
      amount: 1600,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: puregold,
      occurredAt: DateTime(prevYear, prevMonth, 24),
      note: 'Weekly groceries',
    );
    addTxn(
      id: 'demo-txn-m021',
      accountId: gcash,
      amount: 280,
      direction: 'expense',
      categoryId: categoryTransport,
      payeeId: grab,
      occurredAt: DateTime(prevYear, prevMonth, 25),
      note: 'GrabCar to meeting',
    );
    addTxn(
      id: 'demo-txn-m022',
      accountId: cash,
      amount: 210,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: jollibee,
      occurredAt: DateTime(prevYear, prevMonth, 27),
      note: 'Chickenjoy meal',
    );
    addTxn(
      id: 'demo-txn-m023',
      accountId: gcash,
      amount: 195,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: starbucks,
      occurredAt: DateTime(prevYear, prevMonth, 28),
      note: 'Morning coffee',
    );
    addTxn(
      id: 'demo-txn-m024',
      accountId: bpi,
      amount: 35000,
      direction: 'income',
      categoryId: categorySalary,
      occurredAt: DateTime(prevYear, prevMonth, 30),
      note: 'Bi-monthly salary',
      subtype: 'salary',
    );
    addTxn(
      id: 'demo-txn-m025',
      accountId: bdo,
      amount: 2100,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: smSupermarket,
      occurredAt: DateTime(prevYear, prevMonth, 31),
      note: 'Weekly groceries',
    );

    // === JUNE 2026 ===
    addTxn(
      id: 'demo-txn-m026',
      accountId: bpi,
      amount: 3600,
      direction: 'expense',
      categoryId: categoryBills,
      payeeId: meralco,
      occurredAt: DateTime(curYear, curMonth, 1),
      note: 'Meralco bill — June',
      subtype: 'subscription',
    );
    addTxn(
      id: 'demo-txn-m027',
      accountId: bpi,
      amount: 1899,
      direction: 'expense',
      categoryId: categoryBills,
      payeeId: pldt,
      occurredAt: DateTime(curYear, curMonth, 1),
      note: 'PLDT bill — June',
      subtype: 'subscription',
    );
    addTxn(
      id: 'demo-txn-m028',
      accountId: bpi,
      amount: 1500,
      direction: 'expense',
      categoryId: categoryBills,
      payeeId: converge,
      occurredAt: DateTime(curYear, curMonth, 2),
      note: 'Converge internet — June',
      subtype: 'subscription',
    );
    addTxn(
      id: 'demo-txn-m029',
      accountId: bdo,
      amount: 2300,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: smSupermarket,
      occurredAt: DateTime(curYear, curMonth, 4),
      note: 'Weekly groceries',
    );
    addTxn(
      id: 'demo-txn-m030',
      accountId: gcash,
      amount: 135,
      direction: 'expense',
      categoryId: categoryTransport,
      payeeId: angkas,
      occurredAt: DateTime(curYear, curMonth, 5),
      note: 'Angkas ride to work',
    );
    addTxn(
      id: 'demo-txn-m031',
      accountId: gcash,
      amount: 420,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: grab,
      occurredAt: DateTime(curYear, curMonth, 7),
      note: 'GrabFood lunch',
    );
    addTxn(
      id: 'demo-txn-m032',
      accountId: bdo,
      amount: 480,
      direction: 'expense',
      categoryId: categoryHealth,
      payeeId: mercuryDrug,
      occurredAt: DateTime(curYear, curMonth, 8),
      note: 'Prescription refill',
    );
    addTxn(
      id: 'demo-txn-m033',
      accountId: cash,
      amount: 195,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: starbucks,
      occurredAt: DateTime(curYear, curMonth, 10),
      note: 'Morning coffee',
    );
    addTxn(
      id: 'demo-txn-m034',
      accountId: gcash,
      amount: 899,
      direction: 'expense',
      categoryId: categoryShopping,
      payeeId: shopee,
      occurredAt: DateTime(curYear, curMonth, 12),
      note: 'Wireless earbuds',
    );
    addTxn(
      id: 'demo-txn-m035',
      accountId: bdo,
      amount: 1750,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: puregold,
      occurredAt: DateTime(curYear, curMonth, 14),
      note: 'Weekly groceries',
    );
    addTxn(
      id: 'demo-txn-m036',
      accountId: bpi,
      amount: 35000,
      direction: 'income',
      categoryId: categorySalary,
      occurredAt: DateTime(curYear, curMonth, 15),
      note: 'Bi-monthly salary',
      subtype: 'salary',
    );
    addTxn(
      id: 'demo-txn-m037',
      accountId: gcash,
      amount: 165,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: jollibee,
      occurredAt: DateTime(curYear, curMonth, 16),
      note: 'Jollibee breakfast',
    );
    addTxn(
      id: 'demo-txn-m038',
      accountId: bdo,
      amount: 650,
      direction: 'expense',
      categoryId: categoryEntertainment,
      payeeId: smSupermarket,
      occurredAt: DateTime(curYear, curMonth, 18),
      note: 'Movie tickets — SM Cinema',
    );
    addTxn(
      id: 'demo-txn-m039',
      accountId: gcash,
      amount: 780,
      direction: 'expense',
      categoryId: categoryShopping,
      payeeId: lazada,
      occurredAt: DateTime(curYear, curMonth, 20),
      note: 'New sandals',
    );
    addTxn(
      id: 'demo-txn-m040',
      accountId: gcash,
      amount: 95,
      direction: 'expense',
      categoryId: categoryTransport,
      payeeId: angkas,
      occurredAt: DateTime(curYear, curMonth, 22),
      note: 'Angkas ride home',
    );
    addTxn(
      id: 'demo-txn-m041',
      accountId: bdo,
      amount: 2400,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: smSupermarket,
      occurredAt: DateTime(curYear, curMonth, 24),
      note: 'Weekly groceries',
    );
    addTxn(
      id: 'demo-txn-m042',
      accountId: cash,
      amount: 225,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: mcdonalds,
      occurredAt: DateTime(curYear, curMonth, 26),
      note: "McDonald's lunch",
    );
    addTxn(
      id: 'demo-txn-m043',
      accountId: cash,
      amount: 120,
      direction: 'expense',
      categoryId: categoryFood,
      payeeId: sevenEleven,
      occurredAt: DateTime(curYear, curMonth, 28),
      note: 'Quick snack',
    );

    final budgetIds = DemoDataManifest.budgetIds;
    final goalIds = DemoDataManifest.goalIds;
    final debtIds = DemoDataManifest.debtIds;
    final recurringIds = DemoDataManifest.recurringIds;

    final today = DateTime(now.year, now.month, now.day);
    final firstOfNextMonth = DateTime(
      curMonth == 12 ? curYear + 1 : curYear,
      curMonth == 12 ? 1 : curMonth + 1,
      1,
    );

    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.accounts, [
        AccountsCompanion.insert(
          id: bdo,
          ownerUserId: userId,
          name: 'BDO Savings',
          accountType: 'bank',
          balance: const Value(45000.0),
          currencyCode: const Value('PHP'),
        ),
        AccountsCompanion.insert(
          id: gcash,
          ownerUserId: userId,
          name: 'GCash',
          accountType: 'ewallet',
          balance: const Value(3200.0),
          currencyCode: const Value('PHP'),
        ),
        AccountsCompanion.insert(
          id: bpi,
          ownerUserId: userId,
          name: 'BPI Checking',
          accountType: 'bank',
          balance: const Value(120000.0),
          currencyCode: const Value('PHP'),
        ),
        AccountsCompanion.insert(
          id: cash,
          ownerUserId: userId,
          name: 'Cash',
          accountType: 'cash',
          balance: const Value(1500.0),
          currencyCode: const Value('PHP'),
        ),
      ]);

      batch.insertAllOnConflictUpdate(db.payees, [
        PayeesCompanion.insert(
          id: jollibee,
          normalizedName: 'jollibee',
          displayName: const Value('Jollibee'),
        ),
        PayeesCompanion.insert(
          id: mcdonalds,
          normalizedName: 'mcdonalds',
          displayName: const Value("McDonald's"),
        ),
        PayeesCompanion.insert(
          id: mercuryDrug,
          normalizedName: 'mercury drug',
          displayName: const Value('Mercury Drug'),
        ),
        PayeesCompanion.insert(
          id: smSupermarket,
          normalizedName: 'sm supermarket',
          displayName: const Value('SM Supermarket'),
        ),
        PayeesCompanion.insert(
          id: grab,
          normalizedName: 'grab',
          displayName: const Value('Grab'),
        ),
        PayeesCompanion.insert(
          id: angkas,
          normalizedName: 'angkas',
          displayName: const Value('Angkas'),
        ),
        PayeesCompanion.insert(
          id: meralco,
          normalizedName: 'meralco',
          displayName: const Value('Meralco'),
        ),
        PayeesCompanion.insert(
          id: pldt,
          normalizedName: 'pldt',
          displayName: const Value('PLDT'),
        ),
        PayeesCompanion.insert(
          id: converge,
          normalizedName: 'converge',
          displayName: const Value('Converge'),
        ),
        PayeesCompanion.insert(
          id: landers,
          normalizedName: 'landers',
          displayName: const Value('Landers'),
        ),
        PayeesCompanion.insert(
          id: shopee,
          normalizedName: 'shopee',
          displayName: const Value('Shopee'),
        ),
        PayeesCompanion.insert(
          id: lazada,
          normalizedName: 'lazada',
          displayName: const Value('Lazada'),
        ),
        PayeesCompanion.insert(
          id: sevenEleven,
          normalizedName: '7-eleven',
          displayName: const Value('7-Eleven'),
        ),
        PayeesCompanion.insert(
          id: starbucks,
          normalizedName: 'starbucks',
          displayName: const Value('Starbucks'),
        ),
        PayeesCompanion.insert(
          id: puregold,
          normalizedName: 'puregold',
          displayName: const Value('Puregold'),
        ),
        PayeesCompanion.insert(
          id: netflix,
          normalizedName: 'netflix',
          displayName: const Value('Netflix'),
        ),
      ]);

      batch.insertAllOnConflictUpdate(db.transactions, transactions);

      batch.insertAllOnConflictUpdate(db.budgets, [
        BudgetsCompanion.insert(
          id: budgetIds[0],
          ownerUserId: userId,
          categoryId: categoryFood,
          amount: 15000.0,
          month: curMonth,
          year: curYear,
        ),
        BudgetsCompanion.insert(
          id: budgetIds[1],
          ownerUserId: userId,
          categoryId: categoryTransport,
          amount: 5000.0,
          month: curMonth,
          year: curYear,
        ),
        BudgetsCompanion.insert(
          id: budgetIds[2],
          ownerUserId: userId,
          categoryId: categoryShopping,
          amount: 8000.0,
          month: curMonth,
          year: curYear,
        ),
        BudgetsCompanion.insert(
          id: budgetIds[3],
          ownerUserId: userId,
          categoryId: categoryEntertainment,
          amount: 3000.0,
          month: curMonth,
          year: curYear,
        ),
      ]);

      batch.insertAllOnConflictUpdate(db.goals, [
        GoalsCompanion.insert(
          id: goalIds[0],
          ownerUserId: userId,
          name: 'Emergency Fund',
          goalType: 'emergency_fund',
          targetAmount: 100000.0,
          currentAmount: const Value(45000.0),
        ),
        GoalsCompanion.insert(
          id: goalIds[1],
          ownerUserId: userId,
          name: 'Vacation to Japan',
          goalType: 'travel',
          targetAmount: 80000.0,
          currentAmount: const Value(20000.0),
        ),
      ]);

      batch.insertAllOnConflictUpdate(db.debtRecords, [
        DebtRecordsCompanion.insert(
          id: debtIds[0],
          ownerUserId: userId,
          counterpartyName: 'BPI Credit Card',
          debtDirection: 'borrowed',
          amount: 28500.0,
          remainingBalance: 18500.0,
          status: 'partially_paid',
          note: const Value('Credit card statement balance'),
          dueDate: Value(today.add(const Duration(days: 20))),
        ),
        DebtRecordsCompanion.insert(
          id: debtIds[1],
          ownerUserId: userId,
          counterpartyName: 'Home Credit',
          debtDirection: 'borrowed',
          amount: 24000.0,
          remainingBalance: 16000.0,
          status: 'partially_paid',
          note: const Value('BNPL — smartphone, 4 of 6 installments left'),
          dueDate: Value(today.add(const Duration(days: 12))),
        ),
        DebtRecordsCompanion.insert(
          id: debtIds[2],
          ownerUserId: userId,
          counterpartyName: 'Miguel (officemate)',
          debtDirection: 'lent',
          amount: 5000.0,
          remainingBalance: 5000.0,
          status: 'active',
          note: const Value('Lent for emergency, pays back on payday'),
          dueDate: Value(today.add(const Duration(days: 30))),
        ),
      ]);

      batch.insertAllOnConflictUpdate(db.recurringTemplates, [
        RecurringTemplatesCompanion.insert(
          id: recurringIds[0],
          accountId: gcash,
          amount: 549.0,
          recurrenceRule: 'monthly',
          categoryId: const Value(categoryEntertainment),
          payeeId: Value(netflix),
          nextOccurrenceAt: Value(today.add(const Duration(days: 3))),
        ),
        RecurringTemplatesCompanion.insert(
          id: recurringIds[1],
          accountId: bpi,
          amount: 3600.0,
          recurrenceRule: 'monthly',
          categoryId: const Value(categoryBills),
          payeeId: Value(meralco),
          nextOccurrenceAt: Value(today.add(const Duration(days: 5))),
        ),
        RecurringTemplatesCompanion.insert(
          id: recurringIds[2],
          accountId: bpi,
          amount: 35000.0,
          recurrenceRule: 'biweekly',
          categoryId: const Value(categorySalary),
          nextOccurrenceAt: Value(today.add(const Duration(days: 9))),
        ),
        RecurringTemplatesCompanion.insert(
          id: recurringIds[3],
          accountId: bpi,
          amount: 18000.0,
          recurrenceRule: 'monthly',
          categoryId: const Value(categoryHousing),
          nextOccurrenceAt: Value(firstOfNextMonth),
        ),
      ]);

      batch.insertAllOnConflictUpdate(db.demoRecords, [
        for (final id in accountIds)
          DemoRecordsCompanion.insert(
            entityType: DemoEntityType.account.tableName,
            entityId: id,
            seedVersion: const Value(DemoDataManifest.seedVersion),
          ),
        for (final id in payeeIds)
          DemoRecordsCompanion.insert(
            entityType: DemoEntityType.payee.tableName,
            entityId: id,
            seedVersion: const Value(DemoDataManifest.seedVersion),
          ),
        for (final id in transactionIds)
          DemoRecordsCompanion.insert(
            entityType: DemoEntityType.transaction.tableName,
            entityId: id,
            seedVersion: const Value(DemoDataManifest.seedVersion),
          ),
        for (final id in budgetIds)
          DemoRecordsCompanion.insert(
            entityType: DemoEntityType.budget.tableName,
            entityId: id,
            seedVersion: const Value(DemoDataManifest.seedVersion),
          ),
        for (final id in goalIds)
          DemoRecordsCompanion.insert(
            entityType: DemoEntityType.goal.tableName,
            entityId: id,
            seedVersion: const Value(DemoDataManifest.seedVersion),
          ),
        for (final id in debtIds)
          DemoRecordsCompanion.insert(
            entityType: DemoEntityType.debt.tableName,
            entityId: id,
            seedVersion: const Value(DemoDataManifest.seedVersion),
          ),
        for (final id in recurringIds)
          DemoRecordsCompanion.insert(
            entityType: DemoEntityType.recurring.tableName,
            entityId: id,
            seedVersion: const Value(DemoDataManifest.seedVersion),
          ),
      ]);
    });

    return DemoDataResult(
      accountIds: accountIds,
      payeeIds: payeeIds,
      transactionIds: transactionIds,
      budgetIds: budgetIds,
      goalIds: goalIds,
      debtIds: debtIds,
      recurringIds: recurringIds,
    );
  }
}

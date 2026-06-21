import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/transaction_filters_provider.dart';
import 'package:lootr/application/providers/accounts_provider.dart';
import 'package:lootr/application/providers/debts_provider.dart';
import 'package:lootr/application/providers/debt_detail_provider.dart';
import 'package:lootr/application/providers/goals_provider.dart';
import 'package:lootr/application/providers/goal_detail_provider.dart';
import 'package:lootr/application/providers/recurring_provider.dart';
import 'package:lootr/application/providers/more_tab_provider.dart';
import 'package:lootr/application/providers/auth_provider.dart';
import 'package:lootr/application/providers/onboarding_provider.dart';
import 'package:lootr/application/providers/undo_stack_provider.dart';
import 'package:lootr/application/providers/sync_providers.dart';
import 'package:lootr/application/providers/net_worth_provider.dart';
import 'package:lootr/application/providers/dashboard_provider.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/value_objects/transaction_filters.dart';
import 'package:lootr/domain/value_objects/undo_entry.dart';

Future<T?> readStream<T>(
  StreamProvider<T> provider,
  ProviderContainer container,
) async {
  final completer = Completer<T?>();
  final sub = container.listen(provider, (prev, next) {
    if (next.hasValue) {
      completer.complete(next.value);
    }
  });
  final result = await completer.future.timeout(
    const Duration(seconds: 5),
    onTimeout: () => null,
  );
  sub.close();
  return result;
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.inMemory();
  });

  tearDown(() async {
    await db.close();
  });

  group('TransactionFiltersProvider', () {
    test('default filters are empty', () {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);

      final filters = container.read(transactionFiltersProvider);
      expect(filters.isEmpty, isTrue);
    });

    test('update and reset', () {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);

      container
          .read(transactionFiltersProvider.notifier)
          .update(const TransactionFilters(direction: 'expense'));
      expect(container.read(transactionFiltersProvider).direction, 'expense');

      container.read(transactionFiltersProvider.notifier).reset();
      expect(container.read(transactionFiltersProvider).isEmpty, isTrue);
    });
  });

  group('AccountsProvider', () {
    test('emits non-archived accounts', () async {
      await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'acc-1',
              ownerUserId: 'usr-1',
              name: 'Cash',
              accountType: 'cash',
              balance: const Value(1000.0),
            ),
          );

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);

      final accounts = await readStream(accountsProvider, container);
      expect(accounts, isNotNull);
      expect(accounts!.length, 1);
      expect(accounts.first.name, 'Cash');
    });

    test('accountTypesProvider returns all types', () {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);
      expect(container.read(accountTypesProvider).length, 9);
    });
  });

  group('NetWorthProvider', () {
    test('assets minus liabilities', () async {
      await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'acc-1',
              ownerUserId: 'usr-1',
              name: 'Cash',
              accountType: 'cash',
              balance: const Value(10000.0),
            ),
          );
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'acc-2',
              ownerUserId: 'usr-1',
              name: 'Credit Card',
              accountType: 'credit_card',
              balance: const Value(-3000.0),
            ),
          );

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);

      final netWorth = await readStream(netWorthProvider, container);
      expect(netWorth, 7000.0);
    });
  });

  group('DashboardProvider', () {
    test('builds dashboard data with grouped sections', () async {
      final now = DateTime.now();
      await db.users.insertOne(
        UsersCompanion.insert(
          id: 'usr-1',
          displayName: const Value('Taylor'),
          aiEnabled: const Value(true),
        ),
      );
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'acc-1',
              ownerUserId: 'usr-1',
              name: 'Cash',
              accountType: 'cash',
              balance: const Value(12000.0),
            ),
          );
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: 'cat-1',
              name: 'Food',
              categoryGroup: 'expense',
              color: const Value('#ef4444'),
            ),
          );
      await db
          .into(db.payees)
          .insert(
            PayeesCompanion.insert(
              id: 'pay-1',
              normalizedName: 'mcdo',
              displayName: const Value('McDo'),
            ),
          );
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: 'txn-income',
              accountId: 'acc-1',
              amount: 50000.0,
              transactionDirection: 'income',
              transactionMode: 'one_time',
              occurredAt: now.subtract(const Duration(days: 2)),
            ),
          );
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: 'txn-expense',
              accountId: 'acc-1',
              categoryId: const Value('cat-1'),
              payeeId: const Value('pay-1'),
              amount: 2500.0,
              transactionDirection: 'expense',
              transactionMode: 'one_time',
              occurredAt: now.subtract(const Duration(days: 1)),
            ),
          );
      await db
          .into(db.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: 'bud-1',
              ownerUserId: 'usr-1',
              categoryId: 'cat-1',
              amount: 8000.0,
              month: now.month,
              year: now.year,
            ),
          );
      await db
          .into(db.recurringTemplates)
          .insert(
            RecurringTemplatesCompanion.insert(
              id: 'rec-1',
              accountId: 'acc-1',
              categoryId: const Value('cat-1'),
              amount: 900.0,
              recurrenceRule: 'monthly',
              nextOccurrenceAt: Value(now.add(const Duration(days: 3))),
            ),
          );

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);

      final dashboard = await readStream(dashboardProvider, container);
      expect(dashboard, isNotNull);
      expect(dashboard!.accounts.length, 1);
      expect(dashboard.recentTransactions.length, 2);
      expect(dashboard.budgets.single.name, 'Food');
      expect(dashboard.spendingByCategory.single.name, 'Food');
      expect(dashboard.upcomingRecurring.single.payeeName, 'Food');
      expect(dashboard.insights, isNotEmpty);
    });
  });

  group('DebtsProvider', () {
    test('emits debts', () async {
      await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
      await db
          .into(db.debtRecords)
          .insert(
            DebtRecordsCompanion.insert(
              id: 'debt-1',
              ownerUserId: 'usr-1',
              counterpartyName: 'Friend',
              debtDirection: 'borrowed',
              amount: 1000.0,
              status: 'active',
              remainingBalance: 500.0,
            ),
          );

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);

      final debts = await readStream(debtsProvider, container);
      expect(debts, isNotNull);
      expect(debts!.length, 1);
    });
  });

  group('DebtDetailProvider', () {
    test('returns debt by id', () async {
      await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
      await db
          .into(db.debtRecords)
          .insert(
            DebtRecordsCompanion.insert(
              id: 'debt-1',
              ownerUserId: 'usr-1',
              counterpartyName: 'Friend',
              debtDirection: 'lent',
              amount: 2000.0,
              status: 'active',
              remainingBalance: 1000.0,
            ),
          );

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);

      final debt = await readStream(debtDetailProvider('debt-1'), container);
      expect(debt, isNotNull);
      expect(debt!.amount, 2000.0);
    });
  });

  group('GoalsProvider', () {
    test('computes progress', () async {
      await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
      await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              id: 'goal-1',
              ownerUserId: 'usr-1',
              name: 'Emergency Fund',
              goalType: 'emergency_fund',
              targetAmount: 10000.0,
              currentAmount: const Value(2500.0),
            ),
          );

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);

      final goals = await readStream(goalsProvider, container);
      expect(goals, isNotNull);
      expect(goals!.first.progress, 25.0);
    });
  });

  group('GoalDetailProvider', () {
    test('returns goal with progress', () async {
      await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
      await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              id: 'goal-1',
              ownerUserId: 'usr-1',
              name: 'Vacation',
              goalType: 'travel',
              targetAmount: 5000.0,
              currentAmount: const Value(2500.0),
            ),
          );

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);

      final goal = await readStream(goalDetailProvider('goal-1'), container);
      expect(goal, isNotNull);
      expect(goal!.progress, 50.0);
    });
  });

  group('RecurringProvider', () {
    test('emits sorted by nextOccurrenceAt', () async {
      await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'acc-1',
              ownerUserId: 'usr-1',
              name: 'Cash',
              accountType: 'cash',
              balance: const Value(0.0),
            ),
          );
      await db
          .into(db.recurringTemplates)
          .insert(
            RecurringTemplatesCompanion.insert(
              id: 'rec-1',
              accountId: 'acc-1',
              amount: 100.0,
              recurrenceRule: 'monthly',
              nextOccurrenceAt: Value(DateTime(2026, 7, 1)),
            ),
          );
      await db
          .into(db.recurringTemplates)
          .insert(
            RecurringTemplatesCompanion.insert(
              id: 'rec-2',
              accountId: 'acc-1',
              amount: 50.0,
              recurrenceRule: 'weekly',
              nextOccurrenceAt: Value(DateTime(2026, 6, 25)),
            ),
          );

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);

      final recurring = await readStream(recurringProvider, container);
      expect(recurring, isNotNull);
      expect(recurring!.first.id, 'rec-2');
    });
  });

  group('MoreTabProvider', () {
    test('returns static sections', () {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);
      final sections = container.read(moreTabProvider);
      expect(sections.length, 4);
    });
  });

  group('AuthProvider', () {
    test('default is unauthenticated', () {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);
      expect(container.read(authProvider), AuthState.unauthenticated);
    });
  });

  group('OnboardingProvider', () {
    test('complete and skip toggles', () {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);

      expect(container.read(onboardingProvider).completed, isFalse);
      container.read(onboardingProvider.notifier).complete();
      expect(container.read(onboardingProvider).completed, isTrue);
      container.read(onboardingProvider.notifier).skip();
      expect(container.read(onboardingProvider).skipped, isTrue);
    });
  });

  group('UndoStackProvider', () {
    test('push, replace, undo', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);

      container
          .read(undoStackProvider.notifier)
          .push(
            UndoEntry(
              transactionId: 'txn-1',
              message: 'Saved',
              rollback: () async {},
              createdAt: DateTime.now(),
            ),
          );
      expect(container.read(undoStackProvider).length, 1);

      container
          .read(undoStackProvider.notifier)
          .push(
            UndoEntry(
              transactionId: 'txn-2',
              message: 'Second',
              rollback: () async {},
              createdAt: DateTime.now(),
            ),
          );
      expect(container.read(undoStackProvider).first.transactionId, 'txn-2');

      await container.read(undoStackProvider.notifier).undo('txn-2');
      expect(container.read(undoStackProvider), isEmpty);
    });

    test('undoEntryProvider lookup', () {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);
      container
          .read(undoStackProvider.notifier)
          .push(
            UndoEntry(
              transactionId: 'txn-x',
              message: 'Lookup',
              rollback: () async {},
              createdAt: DateTime.now(),
            ),
          );
      expect(container.read(undoEntryProvider('txn-x'))!.message, 'Lookup');
    });
  });

  group('SyncProviders', () {
    test('syncManager and health defaults', () {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);
      expect(container.read(syncManagerProvider), isNotNull);
      expect(container.read(syncStatusIconProvider), SyncIconState.syncing);
    });
  });
}

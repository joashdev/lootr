import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.inMemory();
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase', () {
    test('opens with in-memory database', () async {
      final result = await db.customSelect('SELECT 1').getSingle();
      expect(result.read<int>('1'), 1);
    });

    test('PRAGMA foreign_keys is ON after opening', () async {
      final result =
          await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(result.read<int>('foreign_keys'), 1);
    });

    test('all 16 tables are accessible', () {
      expect(db.users, isNotNull);
      expect(db.households, isNotNull);
      expect(db.householdMembers, isNotNull);
      expect(db.accounts, isNotNull);
      expect(db.transactions, isNotNull);
      expect(db.transfers, isNotNull);
      expect(db.categories, isNotNull);
      expect(db.payees, isNotNull);
      expect(db.budgets, isNotNull);
      expect(db.debtRecords, isNotNull);
      expect(db.goals, isNotNull);
      expect(db.recurringTemplates, isNotNull);
      expect(db.accountBalanceSnapshots, isNotNull);
      expect(db.notifications, isNotNull);
      expect(db.aiProcessingLogs, isNotNull);
      expect(db.syncMetadata, isNotNull);
    });
  });

  group('Table schemas', () {
    test('all 16 tables exist in the schema', () async {
      final tables = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      ).get();

      final tableNames = tables.map((r) => r.read<String>('name')).toSet();
      expect(tableNames, contains('users'));
      expect(tableNames, contains('households'));
      expect(tableNames, contains('household_members'));
      expect(tableNames, contains('accounts'));
      expect(tableNames, contains('transactions'));
      expect(tableNames, contains('transfers'));
      expect(tableNames, contains('categories'));
      expect(tableNames, contains('payees'));
      expect(tableNames, contains('budgets'));
      expect(tableNames, contains('debt_records'));
      expect(tableNames, contains('goals'));
      expect(tableNames, contains('recurring_templates'));
      expect(tableNames, contains('account_balance_snapshots'));
      expect(tableNames, contains('notifications'));
      expect(tableNames, contains('ai_processing_logs'));
      expect(tableNames, contains('sync_metadata'));
    });
  });

  group('Indexes', () {
    test('all required indexes exist', () async {
      final indexes = await db.customSelect(
        "SELECT name, tbl_name FROM sqlite_master WHERE type='index' "
        "AND name NOT LIKE 'sqlite_autoindex_%' ORDER BY name",
      ).get();

      final indexNames = indexes.map((r) => r.read<String>('name')).toSet();

      expect(indexNames, contains('idx_users_email'));
      expect(indexNames, contains('idx_households_created_by'));
      expect(indexNames, contains('idx_hh_members_household'));
      expect(indexNames, contains('idx_hh_members_user'));
      expect(indexNames, contains('idx_accounts_owner'));
      expect(indexNames, contains('idx_accounts_household'));
      expect(indexNames, contains('idx_accounts_type'));
      expect(indexNames, contains('idx_transactions_account'));
      expect(indexNames, contains('idx_transactions_category'));
      expect(indexNames, contains('idx_transactions_payee'));
      expect(indexNames, contains('idx_transactions_parent'));
      expect(indexNames, contains('idx_transactions_occurred_at'));
      expect(indexNames, contains('idx_transactions_direction'));
      expect(indexNames, contains('idx_transfers_source'));
      expect(indexNames, contains('idx_transfers_dest'));
      expect(indexNames, contains('idx_transfers_occurred_at'));
      expect(indexNames, contains('idx_categories_parent'));
      expect(indexNames, contains('idx_payees_normalized'));
      expect(indexNames, contains('idx_budgets_owner_period'));
      expect(indexNames, contains('idx_debt_owner'));
      expect(indexNames, contains('idx_debt_status'));
      expect(indexNames, contains('idx_goals_owner'));
      expect(indexNames, contains('idx_goals_type'));
      expect(indexNames, contains('idx_recurring_account'));
      expect(indexNames, contains('idx_recurring_next'));
      expect(indexNames, contains('idx_snapshots_account_date'));
      expect(indexNames, contains('idx_notifications_scheduled'));
      expect(indexNames, contains('idx_notifications_type'));
      expect(indexNames, contains('idx_ai_logs_source'));
      expect(indexNames, contains('idx_ai_logs_reference'));
      expect(indexNames, contains('uq_hh_members_pair'));
      expect(indexNames, contains('uq_budget_category_period'));
    });
  });

  group('Foreign keys', () {
    test('accounts references users', () async {
      final userId = 'usr-1';
      await db.users.insertOne(
        UsersCompanion.insert(id: userId),
      );

      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-1',
          ownerUserId: userId,
          name: 'Test',
          accountType: 'bank',
        ),
      );

      final account =
          await (db.select(db.accounts)..limit(1)).getSingle();
      expect(account.ownerUserId, userId);
    });

    test('transactions references accounts, categories, payees', () async {
      final userId = 'usr-txn';
      await db.users.insertOne(
        UsersCompanion.insert(id: userId),
      );

      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-txn',
          ownerUserId: userId,
          name: 'Test Acc',
          accountType: 'bank',
        ),
      );

      await db.categories.insertOne(
        CategoriesCompanion.insert(
          id: 'cat-txn',
          name: 'Food',
          categoryGroup: 'expense',
        ),
      );

      await db.payees.insertOne(
        PayeesCompanion.insert(
          id: 'pay-txn',
          normalizedName: 'testmerchant',
        ),
      );

      await db.transactions.insertOne(
        TransactionsCompanion.insert(
          id: 'txn-1',
          accountId: 'acc-txn',
          amount: 100.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 19),
          categoryId: const Value('cat-txn'),
          payeeId: const Value('pay-txn'),
        ),
      );

      final txn =
          await (db.select(db.transactions)..limit(1)).getSingle();
      expect(txn.accountId, 'acc-txn');
      expect(txn.categoryId, 'cat-txn');
      expect(txn.payeeId, 'pay-txn');
    });

    test('transfers references two accounts', () async {
      final userId = 'usr-xfer';
      await db.users.insertOne(
        UsersCompanion.insert(id: userId),
      );

      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'src',
          ownerUserId: userId,
          name: 'Source',
          accountType: 'bank',
        ),
      );
      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'dst',
          ownerUserId: userId,
          name: 'Dest',
          accountType: 'cash',
        ),
      );

      await db.transfers.insertOne(
        TransfersCompanion.insert(
          id: 'xfer-1',
          sourceAccountId: 'src',
          destinationAccountId: 'dst',
          amount: 50.0,
          occurredAt: DateTime(2026, 6, 19),
        ),
      );

      final xfer =
          await (db.select(db.transfers)..limit(1)).getSingle();
      expect(xfer.sourceAccountId, 'src');
      expect(xfer.destinationAccountId, 'dst');
    });
  });

  group('CHECK constraints', () {
    test('valid account_type values are accepted', () async {
      final userId = 'usr-chk';
      await db.users.insertOne(
        UsersCompanion.insert(id: userId),
      );

      final validTypes = [
        'cash',
        'bank',
        'ewallet',
        'savings',
        'investment',
        'crypto',
        'credit_card',
        'loan',
        'bnpl',
      ];

      for (final t in validTypes) {
        await db.accounts.insertOne(
          AccountsCompanion.insert(
            id: 'acc-$t',
            ownerUserId: userId,
            name: t,
            accountType: t,
          ),
        );
      }
    });

    test('invalid account_type value is rejected', () async {
      final userId = 'usr-bad';
      await db.users.insertOne(
        UsersCompanion.insert(id: userId),
      );

      expect(
        () async => db.accounts.insertOne(
          AccountsCompanion.insert(
            id: 'acc-bad',
            ownerUserId: userId,
            name: 'Bad',
            accountType: 'invalid_type',
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('valid transaction_direction values are accepted', () async {
      final userId = 'usr-dir';
      await db.users.insertOne(
        UsersCompanion.insert(id: userId),
      );
      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-dir',
          ownerUserId: userId,
          name: 'Dir Test',
          accountType: 'bank',
        ),
      );

      await db.transactions.insertOne(
        TransactionsCompanion.insert(
          id: 'txn-exp',
          accountId: 'acc-dir',
          amount: 50.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 19),
        ),
      );
      await db.transactions.insertOne(
        TransactionsCompanion.insert(
          id: 'txn-inc',
          accountId: 'acc-dir',
          amount: 100.0,
          transactionDirection: 'income',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 19),
        ),
      );
    });

    test('invalid transaction_direction value is rejected', () async {
      final userId = 'usr-baddir';
      await db.users.insertOne(
        UsersCompanion.insert(id: userId),
      );
      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-baddir',
          ownerUserId: userId,
          name: 'Bad Dir',
          accountType: 'bank',
        ),
      );

      expect(
        () async => db.transactions.insertOne(
          TransactionsCompanion.insert(
            id: 'txn-bad',
            accountId: 'acc-baddir',
            amount: 50.0,
            transactionDirection: 'transfer',
            transactionMode: 'one_time',
            occurredAt: DateTime(2026, 6, 19),
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('valid household_members role values are accepted', () async {
      final userId = 'usr-role';
      await db.users.insertOne(
        UsersCompanion.insert(id: userId),
      );

      await db.households.insertOne(
        HouseholdsCompanion.insert(
          id: 'hh-role',
          name: 'Test HH',
          createdByUserId: userId,
        ),
      );

      await db.householdMembers.insertOne(
        HouseholdMembersCompanion.insert(
          id: 'hh-mem',
          householdId: 'hh-role',
          userId: userId,
          role: 'owner',
        ),
      );
    });

    test('valid budgets month CHECK (1-12)', () async {
      final userId = 'usr-bud';
      await db.users.insertOne(
        UsersCompanion.insert(id: userId),
      );
      await db.categories.insertOne(
        CategoriesCompanion.insert(
          id: 'cat-bud',
          name: 'Test',
          categoryGroup: 'expense',
        ),
      );

      await db.budgets.insertOne(
        BudgetsCompanion.insert(
          id: 'bud-1',
          ownerUserId: userId,
          categoryId: 'cat-bud',
          amount: 1000.0,
          month: 6,
          year: 2026,
        ),
      );
    });

    test('invalid month value is rejected', () async {
      final userId = 'usr-badmon';
      await db.users.insertOne(
        UsersCompanion.insert(id: userId),
      );
      await db.categories.insertOne(
        CategoriesCompanion.insert(
          id: 'cat-badmon',
          name: 'Test',
          categoryGroup: 'expense',
        ),
      );

      expect(
        () async => db.budgets.insertOne(
          BudgetsCompanion.insert(
            id: 'bud-bad',
            ownerUserId: userId,
            categoryId: 'cat-badmon',
            amount: 1000.0,
            month: 13,
            year: 2026,
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('valid sync_status values are accepted', () async {
      final userId = 'usr-sync';
      await db.users.insertOne(
        UsersCompanion.insert(
          id: userId,
          syncStatus: const Value('synced'),
        ),
      );

      final user =
          await (db.select(db.users)..limit(1)).getSingle();
      expect(user.syncStatus, 'synced');
    });

    test('default sync_status is local_only', () async {
      final userId = 'usr-def';
      await db.users.insertOne(
        UsersCompanion.insert(id: userId),
      );

      final user =
          await (db.select(db.users)..limit(1)).getSingle();
      expect(user.syncStatus, 'local_only');
    });
  });

  group('UNIQUE constraints', () {
    test('household_members unique (household_id, user_id)', () async {
      final userId = 'usr-uq';
      await db.users.insertOne(
        UsersCompanion.insert(id: userId),
      );

      await db.households.insertOne(
        HouseholdsCompanion.insert(
          id: 'hh-uq',
          name: 'Test HH',
          createdByUserId: userId,
        ),
      );

      await db.householdMembers.insertOne(
        HouseholdMembersCompanion.insert(
          id: 'hm-1',
          householdId: 'hh-uq',
          userId: userId,
          role: 'owner',
        ),
      );

      expect(
        () async => db.householdMembers.insertOne(
          HouseholdMembersCompanion.insert(
            id: 'hm-2',
            householdId: 'hh-uq',
            userId: userId,
            role: 'member',
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('budgets unique (owner_user_id, category_id, month, year)',
        () async {
      final userId = 'usr-buq';
      await db.users.insertOne(
        UsersCompanion.insert(id: userId),
      );
      await db.categories.insertOne(
        CategoriesCompanion.insert(
          id: 'cat-uq',
          name: 'Test',
          categoryGroup: 'expense',
        ),
      );

      await db.budgets.insertOne(
        BudgetsCompanion.insert(
          id: 'bud-uq-1',
          ownerUserId: userId,
          categoryId: 'cat-uq',
          amount: 500.0,
          month: 6,
          year: 2026,
        ),
      );

      expect(
        () async => db.budgets.insertOne(
          BudgetsCompanion.insert(
            id: 'bud-uq-2',
            ownerUserId: userId,
            categoryId: 'cat-uq',
            amount: 700.0,
            month: 6,
            year: 2026,
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('payees unique normalized_name', () async {
      await db.payees.insertOne(
        PayeesCompanion.insert(
          id: 'pay-uq-1',
          normalizedName: 'starbucks',
        ),
      );

      expect(
        () async => db.payees.insertOne(
          PayeesCompanion.insert(
            id: 'pay-uq-2',
            normalizedName: 'starbucks',
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Syncable tables have sync columns', () {
    test('users has sync_status and last_synced_at', () async {
      final userId = 'usr-synccol';
      await db.users.insertOne(
        UsersCompanion.insert(
          id: userId,
          syncStatus: const Value('pending_sync'),
        ),
      );

      final user =
          await (db.select(db.users)..limit(1)).getSingle();
      expect(user.syncStatus, 'pending_sync');
      expect(user.lastSyncedAt, isNull);
    });

    test('accounts has all sync columns with defaults', () async {
      final userId = 'usr-acsync';
      await db.users.insertOne(
        UsersCompanion.insert(id: userId),
      );

      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-sync',
          ownerUserId: userId,
          name: 'SyncTest',
          accountType: 'bank',
        ),
      );

      final acc =
          await (db.select(db.accounts)..limit(1)).getSingle();
      expect(acc.syncStatus, 'local_only');
      expect(acc.lastSyncedAt, isNull);
      expect(acc.createdAt, isNotNull);
      expect(acc.updatedAt, isNotNull);
    });
  });

  group('Categories seed-compatible', () {
    test('categories default sync_status is synced', () async {
      await db.categories.insertOne(
        CategoriesCompanion.insert(
          id: 'cat-seed',
          name: 'Seeded Category',
          categoryGroup: 'expense',
        ),
      );

      final cat =
          await (db.select(db.categories)..limit(1)).getSingle();
      expect(cat.syncStatus, 'synced');
    });
  });

  group('Local-only tables have no sync columns', () {
    test('account_balance_snapshots has no sync columns', () async {
      final userId = 'usr-loc';
      await db.users.insertOne(
        UsersCompanion.insert(id: userId),
      );
      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-loc',
          ownerUserId: userId,
          name: 'Local',
          accountType: 'cash',
        ),
      );

      await db.accountBalanceSnapshots.insertOne(
        AccountBalanceSnapshotsCompanion.insert(
          id: 'snap-1',
          accountId: 'acc-loc',
          balance: 1000.0,
          snapshotAt: DateTime(2026, 6, 19),
        ),
      );

      final snap = await (db.select(db.accountBalanceSnapshots)
            ..limit(1))
          .getSingle();
      expect(snap.balance, 1000.0);
    });

    test('notifications has no sync columns', () async {
      await db.notifications.insertOne(
        NotificationsCompanion.insert(
          id: 'notif-1',
          notificationType: 'bill_due',
          scheduledAt: DateTime(2026, 6, 20),
        ),
      );

      final n =
          await (db.select(db.notifications)..limit(1)).getSingle();
      expect(n.isCompleted, false);
    });

    test('ai_processing_logs has no sync columns', () async {
      await db.aiProcessingLogs.insertOne(
        AiProcessingLogsCompanion.insert(
          id: 'ailog-1',
          sourceType: 'ocr',
        ),
      );

      final log =
          await (db.select(db.aiProcessingLogs)..limit(1)).getSingle();
      expect(log.sourceType, 'ocr');
    });

    test('sync_metadata is key-value store', () async {
      await db.syncMetadata.insertOne(
        SyncMetadataCompanion.insert(
          key: 'last_synced_at',
          value: '2026-06-19T00:00:00Z',
        ),
      );

      final meta =
          await (db.select(db.syncMetadata)..limit(1)).getSingle();
      expect(meta.key, 'last_synced_at');
      expect(meta.value, '2026-06-19T00:00:00Z');
    });
  });

  group('Soft delete', () {
    test('deleted_at is nullable on syncable tables', () async {
      final userId = 'usr-del';
      await db.users.insertOne(
        UsersCompanion.insert(id: userId),
      );

      final user =
          await (db.select(db.users)..limit(1)).getSingle();
      expect(user.deletedAt, isNull);
    });
  });

  group('Data class field access', () {
    test('UserData has expected fields', () async {
      await db.users.insertOne(
        UsersCompanion.insert(
          id: 'u1',
          currencyCode: const Value('USD'),
        ),
      );

      final user =
          await (db.select(db.users)..limit(1)).getSingle();
      expect(user.id, 'u1');
      expect(user.currencyCode, 'USD');
      expect(user.aiEnabled, false);
    });

    test('AccountData has stored balance', () async {
      final userId = 'usr-bal';
      await db.users.insertOne(
        UsersCompanion.insert(id: userId),
      );

      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-bal',
          ownerUserId: userId,
          name: 'Balance Test',
          accountType: 'savings',
          balance: const Value(5000.0),
        ),
      );

      final acc =
          await (db.select(db.accounts)..limit(1)).getSingle();
      expect(acc.balance, 5000.0);
    });

    test('TransactionData amount is always positive', () async {
      final userId = 'usr-pos';
      await db.users.insertOne(
        UsersCompanion.insert(id: userId),
      );
      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-pos',
          ownerUserId: userId,
          name: 'Pos Test',
          accountType: 'bank',
        ),
      );

      await db.transactions.insertOne(
        TransactionsCompanion.insert(
          id: 'txn-pos',
          accountId: 'acc-pos',
          amount: 250.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 19),
        ),
      );

      final txn =
          await (db.select(db.transactions)..limit(1)).getSingle();
      expect(txn.amount, greaterThan(0));
      expect(txn.transactionDirection, 'expense');
    });

    test('GoalData has default current_amount of 0', () async {
      final userId = 'usr-goal';
      await db.users.insertOne(
        UsersCompanion.insert(id: userId),
      );

      await db.goals.insertOne(
        GoalsCompanion.insert(
          id: 'goal-1',
          ownerUserId: userId,
          name: 'Vacation',
          goalType: 'travel',
          targetAmount: 50000.0,
        ),
      );

      final goal =
          await (db.select(db.goals)..limit(1)).getSingle();
      expect(goal.currentAmount, 0.0);
    });
  });
}

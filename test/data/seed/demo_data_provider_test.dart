import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/demo_data_provider.dart';
import 'package:lootr/application/providers/repo_providers.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/transaction_repo.dart';
import 'package:lootr/data/seed/demo_data_service.dart';

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

    test(
      'build restores present state from the database after restart',
      () async {
        final db = AppDatabase.inMemory();
        addTearDown(db.close);
        final first = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        addTearDown(first.dispose);

        await first.read(demoDataProvider.notifier).seed();

        final restarted = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        addTearDown(restarted.dispose);
        final restored = await restarted.read(demoDataProvider.future);

        expect(restored.status, DemoDataStatus.present);
      },
    );

    test(
      'database records remain authoritative when metadata is stale',
      () async {
        final container = createTestContainer();
        final notifier = container.read(demoDataProvider.notifier);

        await notifier.seed();
        await container
            .read(syncMetadataRepoProvider)
            .set('demo_data_seeded', 'false');

        expect(await notifier.hasDemoData(), true);
      },
    );

    test('partial legacy data stays unverified', () async {
      final container = createTestContainer();
      final db = container.read(databaseProvider);
      await db.into(db.users).insert(UsersCompanion.insert(id: 'demo-user-1'));
      await container
          .read(syncMetadataRepoProvider)
          .set('demo_data_seeded', 'true');

      final state = await container.read(demoDataProvider.future);

      expect(state.status, DemoDataStatus.unverified);
      expect(state.recordCount, 1);
      expect(await db.select(db.demoRecords).get(), isEmpty);
    });

    test('reviewed legacy clear removes only known sample records', () async {
      final container = createTestContainer();
      final db = container.read(databaseProvider);
      await db.into(db.users).insert(UsersCompanion.insert(id: 'demo-user-1'));
      await db
          .into(db.payees)
          .insert(
            PayeesCompanion.insert(
              id: 'personal-payee-1',
              normalizedName: 'personal payee',
            ),
          );
      await container
          .read(syncMetadataRepoProvider)
          .set('demo_data_seeded', 'true');
      final notifier = container.read(demoDataProvider.notifier);
      expect(
        (await container.read(demoDataProvider.future)).status,
        DemoDataStatus.unverified,
      );

      await notifier.clearReviewedLegacy();

      expect(
        await (db.select(
          db.users,
        )..where((row) => row.id.equals('demo-user-1'))).getSingleOrNull(),
        isNull,
      );
      expect(
        await (db.select(
          db.payees,
        )..where((row) => row.id.equals('personal-payee-1'))).getSingleOrNull(),
        isNotNull,
      );
      expect(await notifier.hasDemoData(), isFalse);
    });

    test('personal payees prevent sample loading', () async {
      final container = createTestContainer();
      final db = container.read(databaseProvider);
      await db
          .into(db.payees)
          .insert(
            PayeesCompanion.insert(
              id: 'personal-payee-1',
              normalizedName: 'personal payee',
            ),
          );

      final state = await container.read(demoDataProvider.future);

      expect(state.status, DemoDataStatus.absent);
      expect(state.canSeed, isFalse);
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

      var debts = await db.select(db.debtRecords).get();
      expect(debts.any((d) => d.id.startsWith('demo-')), true);

      var recurring = await db.select(db.recurringTemplates).get();
      expect(recurring.any((r) => r.id.startsWith('demo-')), true);

      await notifier.clear();

      accounts = await db.select(db.accounts).get();
      expect(accounts.any((a) => a.id.startsWith('demo-')), false);

      transactions = await db.select(db.transactions).get();
      expect(transactions.any((t) => t.id.startsWith('demo-')), false);

      debts = await db.select(db.debtRecords).get();
      expect(debts.any((d) => d.id.startsWith('demo-')), false);

      recurring = await db.select(db.recurringTemplates).get();
      expect(recurring.any((r) => r.id.startsWith('demo-')), false);
    });

    test('clear preserves user transactions that use a demo account', () async {
      final container = createTestContainer();
      final db = container.read(databaseProvider);
      await db.into(db.users).insert(UsersCompanion.insert(id: 'local-user-1'));
      final notifier = container.read(demoDataProvider.notifier);
      await notifier.seed();

      await TransactionRepo(db).create(
        TransactionsCompanion.insert(
          id: 'user-txn-1',
          accountId: 'demo-acc-cash',
          amount: 100,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 8, 7),
          syncStatus: const Value('local_only'),
        ),
      );

      final analysis = await notifier.analyzeClear();
      expect(analysis.requiresRecovery, isTrue);
      expect(analysis.personalDependencyCount, 1);

      await notifier.clear();

      final userTransaction = await (db.select(
        db.transactions,
      )..where((row) => row.id.equals('user-txn-1'))).getSingle();
      final recoveredAccount = await (db.select(
        db.accounts,
      )..where((row) => row.id.equals(userTransaction.accountId))).getSingle();
      final remainingDemoTransactions = await (db.select(
        db.transactions,
      )..where((row) => row.id.like('demo-txn-%'))).get();

      expect(userTransaction.id, 'user-txn-1');
      expect(recoveredAccount.ownerUserId, 'local-user-1');
      expect(recoveredAccount.balance, -100);
      expect(remainingDemoTransactions, isEmpty);
      expect(await notifier.hasDemoData(), false);
    });

    test('clear rolls back when dependency recovery is not approved', () async {
      final container = createTestContainer();
      final db = container.read(databaseProvider);
      await db.into(db.users).insert(UsersCompanion.insert(id: 'local-user-1'));
      final notifier = container.read(demoDataProvider.notifier);
      await notifier.seed();
      await TransactionRepo(db).create(
        TransactionsCompanion.insert(
          id: 'user-txn-1',
          accountId: 'demo-acc-cash',
          amount: 100,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 8, 7),
        ),
      );

      await expectLater(
        DemoDataService(db).clear(preservePersonalDependencies: false),
        throwsStateError,
      );

      expect(await notifier.hasDemoData(), true);
      expect(
        await (db.select(
          db.transactions,
        )..where((row) => row.id.equals('demo-txn-m001'))).getSingleOrNull(),
        isNotNull,
      );
      expect(
        await (db.select(
          db.transactions,
        )..where((row) => row.id.equals('user-txn-1'))).getSingleOrNull(),
        isNotNull,
      );
    });

    test('clear does not infer provenance from an ID prefix', () async {
      final container = createTestContainer();
      final db = container.read(databaseProvider);
      final notifier = container.read(demoDataProvider.notifier);
      await notifier.seed();
      await db.into(db.users).insert(UsersCompanion.insert(id: 'local-user-1'));
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'demo-personal-account',
              ownerUserId: 'local-user-1',
              name: 'Personal account',
              accountType: 'bank',
            ),
          );

      await notifier.clear();

      expect(
        await (db.select(db.accounts)
              ..where((row) => row.id.equals('demo-personal-account')))
            .getSingleOrNull(),
        isNotNull,
      );
    });

    test('clear preserves personal records owned by the sample user', () async {
      final container = createTestContainer();
      final db = container.read(databaseProvider);
      final notifier = container.read(demoDataProvider.notifier);
      await notifier.seed();
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'personal-account-1',
              ownerUserId: 'demo-user-1',
              name: 'Personal account',
              accountType: 'bank',
            ),
          );

      await notifier.clear();

      expect(
        await (db.select(db.accounts)
              ..where((row) => row.id.equals('personal-account-1')))
            .getSingleOrNull(),
        isNotNull,
      );
      expect(
        await (db.select(
          db.users,
        )..where((row) => row.id.equals('demo-user-1'))).getSingleOrNull(),
        isNotNull,
      );
      expect(await notifier.hasDemoData(), isFalse);
    });

    test('clear preserves personal budget memberships', () async {
      final container = createTestContainer();
      final db = container.read(databaseProvider);
      final notifier = container.read(demoDataProvider.notifier);
      await notifier.seed();
      await db
          .into(db.budgetDefinitions)
          .insert(
            BudgetDefinitionsCompanion.insert(
              id: 'personal-budget-1',
              ownerUserId: 'demo-user-1',
              amountAtoms: '100000',
              amountScale: 2,
              currencyCode: 'PHP',
            ),
          );
      await db
          .into(db.budgetAccountMemberships)
          .insert(
            BudgetAccountMembershipsCompanion.insert(
              id: 'personal-account-membership-1',
              budgetId: 'personal-budget-1',
              accountId: const Value('demo-acc-cash'),
            ),
          );
      await db
          .into(db.budgetTransactionMemberships)
          .insert(
            BudgetTransactionMembershipsCompanion.insert(
              id: 'personal-transaction-membership-1',
              budgetId: 'personal-budget-1',
              transactionId: const Value('demo-txn-m001'),
            ),
          );

      await notifier.clear();

      expect(
        await (db.select(
          db.accounts,
        )..where((row) => row.id.equals('demo-acc-cash'))).getSingleOrNull(),
        isNotNull,
      );
      expect(
        await (db.select(
          db.transactions,
        )..where((row) => row.id.equals('demo-txn-m001'))).getSingleOrNull(),
        isNotNull,
      );
      expect(await db.select(db.budgetAccountMemberships).get(), hasLength(1));
      expect(
        await db.select(db.budgetTransactionMemberships).get(),
        hasLength(1),
      );
    });

    test('clear removes derived rows attached to sample records', () async {
      final container = createTestContainer();
      final db = container.read(databaseProvider);
      final notifier = container.read(demoDataProvider.notifier);
      await notifier.seed();
      await db
          .into(db.accountBalanceSnapshots)
          .insert(
            AccountBalanceSnapshotsCompanion.insert(
              id: 'snapshot-1',
              accountId: 'demo-acc-cash',
              balance: 1500,
              snapshotAt: DateTime(2026, 8, 7),
            ),
          );
      await db
          .into(db.recurringOccurrences)
          .insert(
            RecurringOccurrencesCompanion.insert(
              id: 'occurrence-1',
              recurringTemplateId: 'demo-rec-netflix',
              status: 'due',
              originalDueAt: DateTime(2026, 8, 7),
              dueAt: DateTime(2026, 8, 7),
              amountAtoms: '54900',
              amountScale: 2,
              currencyCode: 'PHP',
            ),
          );
      await db
          .into(db.notifications)
          .insert(
            NotificationsCompanion.insert(
              id: 'notification-1',
              notificationType: 'recurring_reminder',
              relatedEntityId: const Value('demo-rec-netflix'),
              scheduledAt: DateTime(2026, 8, 7),
            ),
          );
      await db
          .into(db.aiProcessingLogs)
          .insert(
            AiProcessingLogsCompanion.insert(
              id: 'ai-log-1',
              sourceType: 'categorization',
              sourceReferenceId: const Value('demo-txn-m001'),
            ),
          );

      await notifier.clear();

      expect(await db.select(db.accountBalanceSnapshots).get(), isEmpty);
      expect(await db.select(db.recurringOccurrences).get(), isEmpty);
      expect(await db.select(db.notifications).get(), isEmpty);
      expect(await db.select(db.aiProcessingLogs).get(), isEmpty);
    });

    test('clear preserves user-resolved sample occurrences', () async {
      final container = createTestContainer();
      final db = container.read(databaseProvider);
      final notifier = container.read(demoDataProvider.notifier);
      await notifier.seed();
      await db
          .into(db.recurringOccurrences)
          .insert(
            RecurringOccurrencesCompanion.insert(
              id: 'resolved-occurrence-1',
              recurringTemplateId: 'demo-rec-netflix',
              status: 'skipped',
              originalDueAt: DateTime(2026, 8, 7),
              dueAt: DateTime(2026, 8, 7),
              amountAtoms: '54900',
              amountScale: 2,
              currencyCode: 'PHP',
            ),
          );

      await notifier.clear();

      expect(
        await (db.select(db.recurringOccurrences)
              ..where((row) => row.id.equals('resolved-occurrence-1')))
            .getSingleOrNull(),
        isNotNull,
      );
      expect(
        await (db.select(
          db.recurringTemplates,
        )..where((row) => row.id.equals('demo-rec-netflix'))).getSingleOrNull(),
        isNotNull,
      );
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

    test(
      'full lifecycle: seed -> hasDemoData -> clear -> hasDemoData',
      () async {
        final container = createTestContainer();

        await container.read(categoryRepoProvider).seedCategories();

        final notifier = container.read(demoDataProvider.notifier);

        expect(await notifier.hasDemoData(), false);

        await notifier.seed();
        expect(await notifier.hasDemoData(), true);

        await notifier.clear();
        expect(await notifier.hasDemoData(), false);
      },
    );
  });
}

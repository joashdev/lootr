import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/data/database/app_database.dart';

void main() {
  group('schema v4 target model', () {
    test('fresh database exposes exact and migration storage tables', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);

      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
          )
          .get();
      final names = tables.map((row) => row.read<String>('name')).toSet();

      expect(
        names,
        containsAll(<String>[
          'budget_definitions',
          'budget_category_memberships',
          'budget_account_memberships',
          'budget_transaction_memberships',
          'budget_category_limits',
          'budget_periods',
          'recurring_occurrences',
          'goal_contribution_events',
          'debt_payment_events',
          'categorization_rules',
          'transaction_attachment_links',
          'import_runs',
          'import_source_records',
          'import_source_relations',
          'import_provenance',
          'import_discrepancies',
          'import_preserved_payloads',
          'import_checkpoints',
          'rollback_checkpoints',
          'demo_records',
        ]),
      );

      final accountColumns = await db
          .customSelect('PRAGMA table_info(accounts)')
          .get();
      final accountColumnNames = accountColumns
          .map((row) => row.read<String>('name'))
          .toSet();
      expect(
        accountColumnNames,
        containsAll(<String>[
          'balance_atoms',
          'currency_precision',
          'icon',
          'color',
          'emoji_icon',
          'sort_order',
        ]),
      );

      final transferColumns = await db
          .customSelect('PRAGMA table_info(transfers)')
          .get();
      final transferColumnNames = transferColumns
          .map((row) => row.read<String>('name'))
          .toSet();
      expect(
        transferColumnNames,
        containsAll(<String>[
          'source_amount_atoms',
          'source_amount_scale',
          'source_currency_code',
          'destination_amount_atoms',
          'destination_amount_scale',
          'destination_currency_code',
        ]),
      );
    });

    test('stores dual-leg transfers without forcing equal amounts', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);

      await db.users.insertOne(UsersCompanion.insert(id: 'user'));
      await db.accounts.insertAll([
        AccountsCompanion.insert(
          id: 'source',
          ownerUserId: 'user',
          name: 'Source',
          accountType: 'bank',
        ),
        AccountsCompanion.insert(
          id: 'destination',
          ownerUserId: 'user',
          name: 'Destination',
          accountType: 'bank',
        ),
      ]);

      await db.transfers.insertOne(
        TransfersCompanion.insert(
          id: 'transfer',
          sourceAccountId: 'source',
          destinationAccountId: 'destination',
          amount: 1,
          occurredAt: DateTime.utc(2026),
          sourceAmountAtoms: const Value('10000'),
          sourceAmountScale: const Value(4),
          sourceCurrencyCode: const Value('CUR-A'),
          destinationAmountAtoms: const Value('2500000000000'),
          destinationAmountScale: const Value(12),
          destinationCurrencyCode: const Value('CUR-B'),
        ),
      );

      final transfer = await db.transfers.select().getSingle();
      expect(transfer.sourceAmountAtoms, '10000');
      expect(transfer.sourceAmountScale, 4);
      expect(transfer.destinationAmountAtoms, '2500000000000');
      expect(transfer.destinationAmountScale, 12);
      expect(
        transfer.sourceCurrencyCode,
        isNot(transfer.destinationCurrencyCode),
      );
    });

    test('composite budget accepts multiple membership kinds', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);

      await db.users.insertOne(UsersCompanion.insert(id: 'user'));
      await db.categories.insertAll([
        CategoriesCompanion.insert(
          id: 'category-a',
          name: 'A',
          categoryGroup: 'expense',
        ),
        CategoriesCompanion.insert(
          id: 'category-b',
          name: 'B',
          categoryGroup: 'expense',
        ),
      ]);
      await db.budgetDefinitions.insertOne(
        BudgetDefinitionsCompanion.insert(
          id: 'budget',
          ownerUserId: 'user',
          amountAtoms: '500000',
          amountScale: 4,
          currencyCode: 'CUR-A',
          membershipMode: const Value('explicit_only'),
        ),
      );
      await db.budgetCategoryMemberships.insertAll([
        BudgetCategoryMembershipsCompanion.insert(
          id: 'include-a',
          budgetId: 'budget',
          categoryId: const Value('category-a'),
        ),
        BudgetCategoryMembershipsCompanion.insert(
          id: 'exclude-b',
          budgetId: 'budget',
          categoryId: const Value('category-b'),
          membership: const Value('exclude'),
        ),
      ]);
      await db.budgetAccountMemberships.insertOne(
        BudgetAccountMembershipsCompanion.insert(
          id: 'missing-account',
          budgetId: 'budget',
          sourceReference: const Value('opaque-source-reference'),
          reviewState: const Value('missing_reference'),
        ),
      );

      expect(await db.budgetCategoryMemberships.select().get(), hasLength(2));
      final missing = await db.budgetAccountMemberships.select().getSingle();
      expect(missing.accountId, isNull);
      expect(missing.reviewState, 'missing_reference');
    });

    test('requires a disposition for every staged source record', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);

      await db.importRuns.insertOne(
        ImportRunsCompanion.insert(
          id: 'run',
          sourceSystem: 'synthetic',
          sourceFingerprint: 'fingerprint',
          sourceSchemaVersion: 48,
          state: 'staged',
        ),
      );
      await db.importSourceRecords.insertOne(
        ImportSourceRecordsCompanion.insert(
          id: 'record',
          importRunId: 'run',
          sourceTable: 'synthetic_rows',
          sourceEntityId: 'opaque-id',
          sourcePayloadSha256: 'payload-hash',
          disposition: 'preserved_only',
        ),
      );

      final record = await db.importSourceRecords.select().getSingle();
      expect(record.disposition, 'preserved_only');

      await db.importSourceRelations.insertOne(
        ImportSourceRelationsCompanion.insert(
          id: 'safe-relation',
          importRunId: 'run',
          sourceFrom: 'opaque-from',
          relationKind: 'synthetic_relation',
          sourceTo: 'opaque-to',
          disposition: 'ignored_safe',
          reasonCode: const Value('live_table_authoritative'),
        ),
      );
      expect(
        (await db.importSourceRelations.select().getSingle()).disposition,
        'ignored_safe',
      );

      expect(
        () => db.importSourceRecords.insertOne(
          ImportSourceRecordsCompanion.insert(
            id: 'invalid-record',
            importRunId: 'run',
            sourceTable: 'synthetic_rows',
            sourceEntityId: 'another-opaque-id',
            sourcePayloadSha256: 'another-hash',
            disposition: 'unknown',
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('persists resumable cancellation and cleanup state', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);

      await db.importRuns.insertOne(
        ImportRunsCompanion.insert(
          id: 'run',
          sourceSystem: 'synthetic',
          sourceFingerprint: 'fingerprint',
          sourceSchemaVersion: 48,
          state: 'cancel_requested',
          stagingToken: const Value('opaque-staging-token'),
          cleanupStatus: const Value('in_progress'),
          cleanupAttempts: const Value(2),
        ),
      );

      final run = await db.importRuns.select().getSingle();
      expect(run.state, 'cancel_requested');
      expect(run.stagingToken, 'opaque-staging-token');
      expect(run.cleanupStatus, 'in_progress');
      expect(run.cleanupAttempts, 2);

      await db.importRuns.insertOne(
        ImportRunsCompanion.insert(
          id: 'interrupted-run',
          sourceSystem: 'synthetic',
          sourceFingerprint: 'second-fingerprint',
          sourceSchemaVersion: 48,
          state: 'interrupted',
        ),
      );
      expect(
        (await db.importRuns.select().get()).map((row) => row.state),
        contains('interrupted'),
      );
    });
  });

  group('schema v2 to v4 migration', () {
    test('adds exact columns and creates target-model tables', () async {
      final executor = NativeDatabase.memory(
        setup: (raw) {
          for (final table in <String>[
            'accounts',
            'account_balance_snapshots',
            'categories',
            'transactions',
            'transfers',
            'budgets',
            'recurring_templates',
            'goals',
            'debt_records',
          ]) {
            raw.execute('CREATE TABLE $table (id TEXT NOT NULL PRIMARY KEY)');
          }
          raw.execute('PRAGMA user_version = 2');
        },
      );
      final db = AppDatabase(executor);
      addTearDown(db.close);

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 4);

      final transactionColumns = await db
          .customSelect('PRAGMA table_info(transactions)')
          .get();
      expect(
        transactionColumns.map((row) => row.read<String>('name')),
        containsAll(<String>[
          'amount_atoms',
          'amount_scale',
          'currency_code',
          'title',
        ]),
      );

      final importTable = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = 'import_runs'",
          )
          .getSingle();
      expect(importTable.read<String>('name'), 'import_runs');
    });
  });
}

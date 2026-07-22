import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/migration/cashew/cashew_migration.dart';
import 'package:lootr/data/migration/cashew_publication_engine.dart';
import 'package:lootr/data/repositories/composite_budget_repo.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'cashew_fixture_builder.dart';

void main() {
  late AppDatabase database;
  late File source;
  late CashewAnalysis analysis;

  setUp(() async {
    database = AppDatabase.inMemory();
    source = await CashewFixtureBuilder(48).build();
    analysis = await const CashewSourceAdapter().analyzeFile(source);
  });

  tearDown(() async {
    await database.close();
    await source.parent.delete(recursive: true);
  });

  test(
    'publishes exact financial domains atomically and preserves reviews',
    () async {
      await _insertRun(database, 'run-1', analysis);

      final result = await const CashewPublicationEngine().publish(
        database: database,
        importRunId: 'run-1',
        analysis: analysis,
        titlePolicy: 'preserveOnly',
        timezoneId: 'UTC',
        accountTypes: const {'account-partition-1': 'cash'},
      );
      final totalChanges = await database
          .customSelect('SELECT total_changes() AS value')
          .getSingle();

      expect(result.insertedFinancialRecords, greaterThan(0));
      expect(
        result.totalChangesAfterPublication,
        totalChanges.read<int>('value'),
      );
      expect(await _count(database, 'accounts'), 3);
      expect(await _count(database, 'transfers'), 2);
      expect(await _count(database, 'recurring_templates'), 1);
      expect(await _count(database, 'recurring_occurrences'), 3);
      expect(await _count(database, 'goal_contribution_events'), 1);
      expect(await _count(database, 'budget_definitions'), 1);
      expect(await _count(database, 'budget_transaction_memberships'), 1);
      expect(await _count(database, 'categorization_rules'), 1);
      expect(await _count(database, 'transaction_attachment_links'), 1);
      expect(
        await _count(database, 'import_source_records'),
        analysis.records.length,
      );
      expect(
        await _count(database, 'import_preserved_payloads'),
        greaterThan(0),
      );

      final precisions = await database
          .customSelect(
            'SELECT currency_precision, balance_atoms FROM accounts '
            'ORDER BY currency_precision',
          )
          .get();
      expect(precisions.map((row) => row.read<int>('currency_precision')), [
        2,
        4,
        12,
      ]);
      expect(
        precisions.every((row) => row.read<String>('balance_atoms').isNotEmpty),
        isTrue,
      );
      final accountTypes = await database
          .customSelect(
            'SELECT account_type FROM accounts ORDER BY currency_precision',
          )
          .get();
      expect(accountTypes.first.read<String>('account_type'), 'cash');
    },
  );

  test('same analyzed source can be published again without duplicates', () async {
    await _insertRun(database, 'run-1', analysis);
    await const CashewPublicationEngine().publish(
      database: database,
      importRunId: 'run-1',
      analysis: analysis,
      titlePolicy: 'preserveOnly',
      timezoneId: 'UTC',
    );
    final countsBefore = await _financialCounts(database);
    final balancesBefore = await database
        .customSelect('SELECT id, balance_atoms FROM accounts ORDER BY id')
        .get();

    await _insertRun(database, 'run-2', analysis);
    final second = await const CashewPublicationEngine().publish(
      database: database,
      importRunId: 'run-2',
      analysis: analysis,
      titlePolicy: 'preserveOnly',
      timezoneId: 'UTC',
    );

    expect(await _financialCounts(database), countsBefore);
    expect(second.insertedFinancialRecords, 0);
    final balancesAfter = await database
        .customSelect('SELECT id, balance_atoms FROM accounts ORDER BY id')
        .get();
    expect(
      balancesAfter
          .map(
            (row) =>
                '${row.read<String>('id')}:${row.read<String>('balance_atoms')}',
          )
          .toList(),
      balancesBefore
          .map(
            (row) =>
                '${row.read<String>('id')}:${row.read<String>('balance_atoms')}',
          )
          .toList(),
    );
  });

  test('rejects a target mutation after checkpoint capture', () async {
    await _insertRun(database, 'run-target-race', analysis);
    final baseline =
        (await database
                .customSelect('SELECT total_changes() AS value')
                .getSingle())
            .read<int>('value');
    await database
        .into(database.users)
        .insert(UsersCompanion.insert(id: 'post-checkpoint-user'));

    await expectLater(
      const CashewPublicationEngine().publish(
        database: database,
        importRunId: 'run-target-race',
        analysis: analysis,
        titlePolicy: 'preserveOnly',
        timezoneId: 'UTC',
        expectedTotalChanges: baseline,
      ),
      throwsA(
        isA<CashewPublicationFailure>().having(
          (error) => error.code,
          'code',
          'target_changed_during_checkpoint',
        ),
      ),
    );
    expect(await _count(database, 'accounts'), 0);
    expect(await _count(database, 'users'), 1);
  });

  test(
    'publishes due and unpaid lifecycle with earliest unresolved occurrence',
    () async {
      final sourceDatabase = sqlite.sqlite3.open(source.path);
      try {
        sourceDatabase.execute(
          'UPDATE transactions SET original_date_due = ? '
          'WHERE transaction_pk = ?',
          [
            DateTime.utc(2025, 6).millisecondsSinceEpoch ~/ 1000,
            'series::predict::1',
          ],
        );
        sourceDatabase.execute(
          'UPDATE transactions SET original_date_due = ?, skip_paid = 0 '
          'WHERE transaction_pk = ?',
          [
            DateTime.utc(2027).millisecondsSinceEpoch ~/ 1000,
            'series::predict::2',
          ],
        );
      } finally {
        sourceDatabase.close();
      }
      analysis = await const CashewSourceAdapter().analyzeFile(source);
      await _insertRun(database, 'run-lifecycle', analysis);

      await const CashewPublicationEngine().publish(
        database: database,
        importRunId: 'run-lifecycle',
        analysis: analysis,
        titlePolicy: 'preserveOnly',
        timezoneId: 'UTC',
        publicationTime: DateTime.utc(2026, 7),
      );

      final occurrences = await database
          .select(database.recurringOccurrences)
          .get();
      final bySource = {
        for (final occurrence in occurrences)
          occurrence.sourceOccurrenceKey!: occurrence,
      };
      expect(bySource['series']!.status, 'paid');
      expect(bySource['series']!.transactionId, isNotNull);
      expect(bySource['series::predict::1']!.status, 'unpaid');
      expect(bySource['series::predict::2']!.status, 'due');

      final linkedTransaction =
          await (database.select(database.transactions)..where(
                (row) => row.id.equals(bySource['series']!.transactionId!),
              ))
              .getSingleOrNull();
      expect(linkedTransaction?.recurringTemplateId, isNotNull);

      final template = await database
          .select(database.recurringTemplates)
          .getSingle();
      expect(template.nextOccurrenceAt, DateTime.utc(2025, 6));
    },
  );

  test(
    'publishes transaction-level budget exclusions and exclude wins',
    () async {
      final sourceDatabase = sqlite.sqlite3.open(source.path);
      try {
        sourceDatabase.execute(
          'UPDATE transactions SET budget_fks_exclude = ? '
          'WHERE transaction_pk = ?',
          ['["budget-1"]', 'ordinary'],
        );
      } finally {
        sourceDatabase.close();
      }
      analysis = await const CashewSourceAdapter().analyzeFile(source);
      await _insertRun(database, 'run-budget-exclusion', analysis);

      await const CashewPublicationEngine().publish(
        database: database,
        importRunId: 'run-budget-exclusion',
        analysis: analysis,
        titlePolicy: 'preserveOnly',
        timezoneId: 'UTC',
      );

      final memberships = await database
          .select(database.budgetTransactionMemberships)
          .get();
      expect(memberships.map((row) => row.membership).toSet(), {
        'include',
        'exclude',
      });
      final exclusion = memberships.singleWhere(
        (row) => row.membership == 'exclude',
      );
      expect(exclusion.transactionId, isNotNull);
      expect(exclusion.reasonCode, 'source_exclusion');
      expect(exclusion.reviewState, 'ready');

      final budget = await database
          .select(database.budgetDefinitions)
          .getSingle();
      final evaluation = await CompositeBudgetRepo(database).evaluate(
        budget.id,
        period: BudgetPeriodWindow(
          startsAt: DateTime.utc(2026),
          endsAt: DateTime.utc(2026, 2),
        ),
      );
      expect(evaluation.matches, isEmpty);
    },
  );

  test('redacts settings values from the encrypted preserved archive', () async {
    final sourceDatabase = sqlite.sqlite3.open(source.path);
    try {
      sourceDatabase.execute('UPDATE app_settings SET settings_j_s_o_n = ?', [
        '{"oauth_token":"synthetic-secret",'
            '"customCurrencies":{"XAA":{"decimals":4}},'
            '"cachedCurrencyExchange":{"XAA":1.25},'
            '"customCurrencyAmounts":{"XAA":"2.5000"}}',
      ]);
    } finally {
      sourceDatabase.close();
    }
    analysis = await const CashewSourceAdapter().analyzeFile(source);
    await _insertRun(database, 'run-settings-redaction', analysis);

    await const CashewPublicationEngine().publish(
      database: database,
      importRunId: 'run-settings-redaction',
      analysis: analysis,
      titlePolicy: 'preserveOnly',
      timezoneId: 'UTC',
    );

    final archived = await database
        .customSelect(
          "SELECT payload_json FROM import_preserved_payloads "
          "WHERE payload_json LIKE '%sensitive_settings_values_not_retained%'",
        )
        .getSingle();
    expect(
      archived.read<String>('payload_json'),
      isNot(contains('synthetic-secret')),
    );
    expect(archived.read<String>('payload_json'), contains('customCurrencies'));
    expect(
      archived.read<String>('payload_json'),
      contains('cachedCurrencyExchange'),
    );
  });

  test('later category-zero rows remain balance adjustments', () async {
    final sourceDatabase = sqlite.sqlite3.open(source.path);
    try {
      sourceDatabase.execute(
        'UPDATE transactions SET category_fk = ?, date_created = ? '
        'WHERE transaction_pk = ?',
        ['0', DateTime.utc(2026, 3).millisecondsSinceEpoch ~/ 1000, 'ordinary'],
      );
    } finally {
      sourceDatabase.close();
    }
    analysis = await const CashewSourceAdapter().analyzeFile(source);
    await _insertRun(database, 'run-adjustment', analysis);

    await const CashewPublicationEngine().publish(
      database: database,
      importRunId: 'run-adjustment',
      analysis: analysis,
      titlePolicy: 'preserveOnly',
      timezoneId: 'UTC',
    );

    final adjustments = await database
        .customSelect(
          "SELECT id FROM transactions "
          "WHERE metadata LIKE '%balance_adjustment%'",
        )
        .get();
    expect(adjustments, isNotEmpty);
  });
}

Future<void> _insertRun(
  AppDatabase database,
  String id,
  CashewAnalysis analysis,
) {
  return database
      .into(database.importRuns)
      .insert(
        ImportRunsCompanion.insert(
          id: id,
          sourceSystem: 'cashew',
          sourceFingerprint: analysis.report.sourceSha256,
          sourceSchemaVersion: 48,
          state: 'applying',
        ),
      );
}

Future<int> _count(AppDatabase database, String table) async {
  final row = await database
      .customSelect('SELECT COUNT(*) AS count FROM $table')
      .getSingle();
  return row.read<int>('count');
}

Future<List<int>> _financialCounts(AppDatabase database) async {
  return Future.wait([
    _count(database, 'accounts'),
    _count(database, 'categories'),
    _count(database, 'transactions'),
    _count(database, 'transfers'),
    _count(database, 'goals'),
    _count(database, 'budget_definitions'),
    _count(database, 'categorization_rules'),
  ]);
}

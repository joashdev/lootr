import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/migration/cashew/cashew_migration.dart';
import 'package:lootr/data/migration/cashew_publication_engine.dart';

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
      );

      expect(result.insertedFinancialRecords, greaterThan(0));
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

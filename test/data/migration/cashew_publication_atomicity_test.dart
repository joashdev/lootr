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
    await database
        .into(database.importRuns)
        .insert(
          ImportRunsCompanion.insert(
            id: 'atomic-run',
            sourceSystem: 'cashew',
            sourceFingerprint: analysis.report.sourceSha256,
            sourceSchemaVersion: 48,
            state: 'applying',
          ),
        );
  });

  tearDown(() async {
    await database.close();
    await source.parent.delete(recursive: true);
  });

  test(
    'publication failure exposes no partial target or provenance rows',
    () async {
      await database.customStatement('''
      CREATE TRIGGER synthetic_abort_transaction
      BEFORE INSERT ON transactions
      BEGIN
        SELECT RAISE(ABORT, 'synthetic publication interruption');
      END
    ''');

      await expectLater(
        const CashewPublicationEngine().publish(
          database: database,
          importRunId: 'atomic-run',
          analysis: analysis,
          titlePolicy: 'preserveOnly',
          timezoneId: 'UTC',
        ),
        throwsA(anything),
      );

      for (final table in const [
        'users',
        'accounts',
        'categories',
        'transactions',
        'transfers',
        'goals',
        'budget_definitions',
        'categorization_rules',
        'import_source_records',
        'import_source_relations',
        'import_provenance',
        'import_preserved_payloads',
      ]) {
        expect(
          await _count(database, table),
          0,
          reason: 'Atomic rollback must leave $table unpublished.',
        );
      }
    },
  );
}

Future<int> _count(AppDatabase database, String table) async {
  final row = await database
      .customSelect('SELECT COUNT(*) AS count FROM $table')
      .getSingle();
  return row.read<int>('count');
}

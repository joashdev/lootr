import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/migration/migration_models.dart';
import 'package:lootr/application/migration/persistent_migration_coordinator.dart';
import 'package:lootr/data/backup/lootr_backup_service.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/migration/cashew/cashew_migration.dart';
import 'package:lootr/data/migration/cashew_publication_engine.dart';
import 'package:lootr/data/migration/cashew_source_registry.dart';
import 'package:lootr/data/migration/cashew_staging_service.dart';
import 'package:lootr/data/security/database_key_store.dart';
import 'package:lootr/data/security/encrypted_database_connection.dart';

void main() {
  final sourcePath = Platform.environment['CASHEW_EXPORT_PATH'];

  test(
    'real export publishes, rolls back, restores, and reimports idempotently',
    () async {
      final source = File(sourcePath!);
      final sourceHashBefore = await _hash(source);
      final analysis = await const CashewSourceAdapter().analyzeFile(source);
      expect(analysis.report.schemaVersion, 48);
      expect(analysis.report.tableCounts['wallets'], 19);
      expect(analysis.report.tableCounts['transactions'], 2065);
      expect(analysis.report.transfers.resolvedPairs, 269);
      expect(analysis.report.domains.recurringSeries, 31);
      expect(analysis.report.domains.objectives, 8);
      expect(analysis.report.domains.objectiveFinancialRows, 235);
      expect(analysis.report.domains.budgets, 5);
      expect(analysis.report.domains.categorizationRules, 277);
      expect(analysis.report.everySourceRowDisposed, isTrue);
      expect(analysis.report.reconciliation.passed, isTrue);
      expect(analysis.report.hasBlockingIssues, isFalse);

      final temporary = await Directory.systemTemp.createTemp(
        'lootr-real-import-e2e-',
      );
      final keys = InMemoryDatabaseKeyStore(
        List<int>.generate(32, (index) => 255 - index),
      );
      final backups = LootrBackupService(keyStore: keys);
      final liveFile = File('${temporary.path}/lootr.sqlite');
      final preImportBackup = File('${temporary.path}/pre-import.lootr');
      final importedBackup = File('${temporary.path}/imported.lootr');

      AppDatabase openDatabase() => AppDatabase(
        EncryptedDatabaseConnection(
          keyStore: keys,
          documentsDirectory: () async => temporary,
        ).lazy(),
      );

      var database = openDatabase();
      try {
        await _insertRun(database, 'real-run-1', analysis);
        await database.customSelect('SELECT 1').getSingle();
        await backups.create(
          liveDatabase: liveFile,
          destination: preImportBackup,
        );

        final first = await const CashewPublicationEngine().publish(
          database: database,
          importRunId: 'real-run-1',
          analysis: analysis,
          titlePolicy: 'preserveOnly',
          timezoneId: 'device',
        );
        expect(first.insertedFinancialRecords, greaterThan(0));
        final importedCounts = await _importantCounts(database);
        expect(await _count(database, 'import_source_records'), 4369);
        expect(await _count(database, 'transfers'), 259);
        expect(await _count(database, 'recurring_templates'), 31);
        expect(
          await _count(database, 'goal_contribution_events') +
              await _count(database, 'debt_payment_events'),
          235,
        );
        expect(await _count(database, 'budget_definitions'), 5);
        expect(await _count(database, 'categorization_rules'), 277);
        await backups.create(
          liveDatabase: liveFile,
          destination: importedBackup,
        );
        await database.close();

        final importedCheckpoint = await backups.restoreAtomically(
          backup: preImportBackup,
          liveDatabase: liveFile,
        );
        database = openDatabase();
        expect(await _count(database, 'accounts'), 0);
        expect(await _count(database, 'transactions'), 0);
        expect(await _count(database, 'transfers'), 0);
        await database.close();
        await backups.discardCheckpoint(importedCheckpoint);

        final emptyCheckpoint = await backups.restoreAtomically(
          backup: importedBackup,
          liveDatabase: liveFile,
        );
        database = openDatabase();
        expect(await _importantCounts(database), importedCounts);
        await _insertRun(database, 'real-run-2', analysis);
        final second = await const CashewPublicationEngine().publish(
          database: database,
          importRunId: 'real-run-2',
          analysis: analysis,
          titlePolicy: 'preserveOnly',
          timezoneId: 'device',
        );
        expect(second.insertedFinancialRecords, 0);
        expect(await _importantCounts(database), importedCounts);
        await database.close();
        await backups.discardCheckpoint(emptyCheckpoint);

        expect(await _hash(source), sourceHashBefore);
      } finally {
        try {
          await database.close();
        } on Object {
          // It may already be closed between file-level restore steps.
        }
        await temporary.delete(recursive: true);
      }
    },
    skip: sourcePath == null
        ? 'Set CASHEW_EXPORT_PATH to run the private end-to-end test.'
        : false,
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'real export completes the staged persistent coordinator path',
    () async {
      final source = File(sourcePath!);
      final sourceHashBefore = await _hash(source);
      final temporary = await Directory.systemTemp.createTemp(
        'lootr-real-coordinator-e2e-',
      );
      final databaseDirectory = Directory('${temporary.path}/database');
      final stagingDirectory = Directory('${temporary.path}/support');
      final rollbackDirectory = Directory('${temporary.path}/rollback');
      final keys = InMemoryDatabaseKeyStore(
        List<int>.generate(32, (index) => index + 1),
      );
      final backups = LootrBackupService(keyStore: keys);
      final database = AppDatabase(
        EncryptedDatabaseConnection(
          keyStore: keys,
          documentsDirectory: () async => databaseDirectory,
        ).lazy(),
      );
      final registry = CashewSourceRegistry();
      final staging = CashewStagingService(
        supportDirectory: () async => stagingDirectory,
      );
      final coordinator = PersistentMigrationCoordinator(
        database: () => database,
        liveDatabaseFile: () async =>
            File('${databaseDirectory.path}/lootr.sqlite'),
        rollbackDirectory: () async => rollbackDirectory,
        registry: registry,
        staging: staging,
        backups: backups,
        restoreCheckpoint: (_) async {
          throw StateError('Restore is not exercised in this path.');
        },
      );
      try {
        final selection = registry.register(XFile(source.path));
        final created = await coordinator.createRun(
          source: selection,
          timezone: const MigrationTimezoneOption(
            id: 'device',
            label: 'Device timezone',
          ),
          titlePolicy: MigrationTitlePolicy.preserveOnly,
        );
        await coordinator.analyze(created.id);
        var projection = await coordinator.watchRun(created.id).first;
        expect(projection?.schemaVersion, 48);
        expect(projection?.accountCount, 19);
        expect(projection?.dispositions.blocking, 0);
        expect(projection?.partitions, hasLength(19));

        for (final group in projection!.reviewGroups.where(
          (group) => !group.resolved,
        )) {
          await coordinator.resolveReviewGroup(created.id, group.id);
        }
        await coordinator.reconcile(created.id);
        projection = await coordinator.watchRun(created.id).first;
        expect(projection?.phase, MigrationRunPhase.ready);

        await coordinator.apply(created.id);
        projection = await coordinator.watchRun(created.id).first;
        expect(projection?.phase, MigrationRunPhase.complete);
        expect(await _count(database, 'import_source_records'), 4369);
        expect(await _count(database, 'accounts'), 19);
        expect(await _count(database, 'transfers'), 259);
        expect(await _count(database, 'budget_definitions'), 5);
        expect(await _count(database, 'categorization_rules'), 277);
        expect(await _hash(source), sourceHashBefore);
      } finally {
        await coordinator.dispose();
        await database.close();
        await temporary.delete(recursive: true);
      }
    },
    skip: sourcePath == null
        ? 'Set CASHEW_EXPORT_PATH to run the private coordinator test.'
        : false,
    timeout: const Timeout(Duration(minutes: 10)),
  );
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

Future<List<int>> _importantCounts(AppDatabase database) {
  return Future.wait([
    _count(database, 'accounts'),
    _count(database, 'categories'),
    _count(database, 'transactions'),
    _count(database, 'transfers'),
    _count(database, 'recurring_templates'),
    _count(database, 'recurring_occurrences'),
    _count(database, 'goals'),
    _count(database, 'debt_records'),
    _count(database, 'goal_contribution_events'),
    _count(database, 'debt_payment_events'),
    _count(database, 'budget_definitions'),
    _count(database, 'budget_account_memberships'),
    _count(database, 'budget_category_memberships'),
    _count(database, 'budget_transaction_memberships'),
    _count(database, 'categorization_rules'),
    _count(database, 'import_preserved_payloads'),
    _count(database, 'import_provenance'),
  ]);
}

Future<int> _count(AppDatabase database, String table) async {
  final row = await database
      .customSelect('SELECT COUNT(*) AS count FROM $table')
      .getSingle();
  return row.read<int>('count');
}

Future<String> _hash(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value, Variable, driftRuntimeOptions;
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
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../data/migration/cashew_fixture_builder.dart';

void main() {
  late Directory temporary;
  late AppDatabase database;
  late CashewStagingService staging;
  late CashewSourceRegistry registry;
  late LootrBackupService backups;
  PersistentMigrationCoordinator? coordinator;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp(
      'lootr-persistent-migration-test-',
    );
    database = AppDatabase.inMemory();
    staging = CashewStagingService(supportDirectory: () async => temporary);
    registry = CashewSourceRegistry();
    backups = LootrBackupService(
      keyStore: InMemoryDatabaseKeyStore(
        List<int>.generate(32, (index) => index + 1),
      ),
    );
  });

  tearDown(() async {
    await coordinator?.dispose();
    await database.close();
    if (await temporary.exists()) {
      await temporary.delete(recursive: true);
    }
  });

  test(
    'synthetic schema-48 run stages, analyzes, reviews, reconciles, and cancels',
    () async {
      coordinator = _coordinator(
        database: database,
        staging: staging,
        registry: registry,
        backups: backups,
        temporary: temporary,
      );
      final source = await CashewFixtureBuilder(48).build();
      addTearDown(() async {
        if (await source.parent.exists()) {
          await source.parent.delete(recursive: true);
        }
      });
      final selection = registry.register(
        XFile(source.path, name: 'synthetic-cashew.sqlite'),
      );

      final created = await coordinator!.createRun(
        source: selection,
        timezone: const MigrationTimezoneOption(id: 'UTC', label: 'UTC'),
        titlePolicy: MigrationTitlePolicy.preserveAndSuggest,
      );
      expect(created.phase, MigrationRunPhase.selected);

      await coordinator!.analyze(created.id);
      var projection = await coordinator!.watchRun(created.id).first;
      expect(projection, isNotNull);
      expect(projection!.schemaVersion, 48);
      expect(projection.accountCount, 3);
      expect(projection.partitions.map((row) => row.precision), [2, 4, 12]);
      expect(projection.dispositions.total, greaterThan(0));
      expect(projection.phase, MigrationRunPhase.needsReview);
      expect(
        projection.reviewGroups.map((group) => group.id),
        containsAll([
          'policy.timezone_confirmation',
          'policy.title_confirmation',
        ]),
      );

      if (projection.phase == MigrationRunPhase.needsReview) {
        for (final group in projection.reviewGroups.where(
          (group) => group.level != MigrationIssueLevel.blocking,
        )) {
          await coordinator!.resolveReviewGroup(created.id, group.id);
        }
        await coordinator!.reconcile(created.id);
        projection = await coordinator!.watchRun(created.id).first;
      }
      expect(projection?.phase, MigrationRunPhase.ready);

      final runBeforeCancel = await _run(database, created.id);
      final stagedFile = File(
        '${temporary.path}/cashew-import/'
        '${runBeforeCancel.stagingToken}/source.sqlite',
      );
      expect(await stagedFile.exists(), isTrue);

      await coordinator!.cancel(created.id);

      final cancelled = await _run(database, created.id);
      expect(cancelled.state, 'cancelled');
      expect(cancelled.cleanupStatus, 'complete');
      expect(cancelled.cleanupAttempts, 1);
      expect(cancelled.stagingToken, isNull);
      expect(await stagedFile.exists(), isFalse);
      expect(await source.exists(), isTrue);
    },
  );

  test('an interrupted staged run can resume analysis from its copy', () async {
    final source = await CashewFixtureBuilder(48).build();
    addTearDown(() async {
      if (await source.parent.exists()) {
        await source.parent.delete(recursive: true);
      }
    });
    final staged = await staging.stage(XFile(source.path));
    await _insertRun(
      database,
      id: 'resume-run',
      state: 'interrupted',
      fingerprint: staged.sourceFingerprint,
      stagingToken: staged.stagingToken,
    );
    coordinator = _coordinator(
      database: database,
      staging: staging,
      registry: registry,
      backups: backups,
      temporary: temporary,
    );

    await coordinator!.analyze('resume-run');

    final projection = await coordinator!.watchRun('resume-run').first;
    expect(projection?.schemaVersion, 48);
    expect(projection?.phase, MigrationRunPhase.needsReview);
    expect((await _run(database, 'resume-run')).cleanupStatus, 'pending');
  });

  test(
    'startup recovery interrupts validation and uncommitted publication',
    () async {
      await _insertRun(database, id: 'validating', state: 'validating');
      await _insertRun(database, id: 'applying', state: 'applying');
      await _insertRun(database, id: 'verifying', state: 'verifying');

      coordinator = _coordinator(
        database: database,
        staging: staging,
        registry: registry,
        backups: backups,
        temporary: temporary,
      );

      await _eventually(() async {
        final states = await Future.wait([
          _run(database, 'validating'),
          _run(database, 'applying'),
          _run(database, 'verifying'),
        ]);
        return states[0].state == 'staged' &&
            states[1].state == 'interrupted' &&
            states[2].state == 'interrupted';
      });
    },
  );

  test(
    'startup recovery finishes requested cancellation and cleanup',
    () async {
      final source = await CashewFixtureBuilder(48).build();
      addTearDown(() async {
        if (await source.parent.exists()) {
          await source.parent.delete(recursive: true);
        }
      });
      final staged = await staging.stage(XFile(source.path));
      await _insertRun(
        database,
        id: 'cancel-run',
        state: 'cancel_requested',
        fingerprint: staged.sourceFingerprint,
        stagingToken: staged.stagingToken,
      );
      coordinator = _coordinator(
        database: database,
        staging: staging,
        registry: registry,
        backups: backups,
        temporary: temporary,
      );

      await _eventually(() async {
        final run = await _run(database, 'cancel-run');
        return run.state == 'cancelled' && run.cleanupStatus == 'complete';
      });

      final recovered = await _run(database, 'cancel-run');
      expect(recovered.cleanupAttempts, 1);
      expect(recovered.stagingToken, isNull);
      expect(await staged.file.exists(), isFalse);
    },
  );

  test('startup removes a staged copy that has no persisted run', () async {
    final source = await CashewFixtureBuilder(48).build();
    addTearDown(() async {
      if (await source.parent.exists()) {
        await source.parent.delete(recursive: true);
      }
    });
    final orphan = await staging.stage(XFile(source.path));
    expect(await orphan.file.exists(), isTrue);

    coordinator = _coordinator(
      database: database,
      staging: staging,
      registry: registry,
      backups: backups,
      temporary: temporary,
    );

    await _eventually(() async => !await orphan.file.exists());
  });

  test('creating a run waits for startup orphan cleanup', () async {
    final source = await CashewFixtureBuilder(48).build();
    addTearDown(() async {
      if (await source.parent.exists()) {
        await source.parent.delete(recursive: true);
      }
    });
    final blockingStaging = _BlockingCleanupStagingService(temporary);
    coordinator = _coordinator(
      database: database,
      staging: blockingStaging,
      registry: registry,
      backups: backups,
      temporary: temporary,
    );
    final selection = registry.register(XFile(source.path));

    final creating = coordinator!.createRun(
      source: selection,
      timezone: const MigrationTimezoneOption(id: 'UTC', label: 'UTC'),
      titlePolicy: MigrationTitlePolicy.preserveOnly,
    );
    await blockingStaging.cleanupStarted.future;
    var completed = false;
    unawaited(creating.whenComplete(() => completed = true));
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    blockingStaging.allowCleanup.complete();
    final created = await creating;
    final run = await _run(database, created.id);
    final stagedFile = File(
      '${temporary.path}/cashew-import/${run.stagingToken}/source.sqlite',
    );
    expect(await stagedFile.exists(), isTrue);
  });

  test(
    'cleanup remains successful when the staged file is already absent',
    () async {
      final source = await CashewFixtureBuilder(48).build();
      addTearDown(() async {
        if (await source.parent.exists()) {
          await source.parent.delete(recursive: true);
        }
      });
      final staged = await staging.stage(XFile(source.path));
      await staged.file.delete();
      await _insertRun(
        database,
        id: 'cleanup-run',
        state: 'ready',
        fingerprint: staged.sourceFingerprint,
        stagingToken: staged.stagingToken,
      );
      coordinator = _coordinator(
        database: database,
        staging: staging,
        registry: registry,
        backups: backups,
        temporary: temporary,
      );

      await coordinator!.cancel('cleanup-run');

      final cancelled = await _run(database, 'cleanup-run');
      expect(cancelled.state, 'cancelled');
      expect(cancelled.cleanupStatus, 'complete');
      expect(cancelled.cleanupAttempts, 1);
      expect(cancelled.stagingToken, isNull);
    },
  );

  test(
    'a crash after committed publication retains the whole set for recovery',
    () async {
      final source = await CashewFixtureBuilder(48).build();
      addTearDown(() async {
        if (await source.parent.exists()) {
          await source.parent.delete(recursive: true);
        }
      });
      final analysis = await const CashewSourceAdapter().analyzeFile(source);
      await _insertRun(
        database,
        id: 'published-run',
        state: 'applying',
        fingerprint: analysis.report.sourceSha256,
      );
      await const CashewPublicationEngine().publish(
        database: database,
        importRunId: 'published-run',
        analysis: analysis,
        titlePolicy: 'preserveOnly',
        timezoneId: 'UTC',
      );
      await (database.update(database.importRuns)
            ..where((row) => row.id.equals('published-run')))
          .write(const ImportRunsCompanion(state: Value('verifying')));
      final before = await _publicationCounts(database, 'published-run');
      expect(before.every((count) => count > 0), isTrue);

      coordinator = _coordinator(
        database: database,
        staging: staging,
        registry: registry,
        backups: backups,
        temporary: temporary,
      );

      await _eventually(
        () async =>
            (await _run(database, 'published-run')).state != 'verifying',
      );

      expect((await _run(database, 'published-run')).state, 'interrupted');
      expect(await _publicationCounts(database, 'published-run'), before);
    },
  );

  test(
    'rollback returns the restored run to an explicit terminal state',
    () async {
      final previousWarningSetting =
          driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(() {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases =
            previousWarningSetting;
      });
      const runId = 'rollback-run';
      await _insertRun(database, id: runId, state: 'complete');
      final encryptedLive = File('${temporary.path}/checkpoint-source.sqlite');
      _createEncryptedPlaceholder(encryptedLive);
      final backup = await backups.create(
        liveDatabase: encryptedLive,
        destination: File('${temporary.path}/rollback.lootr'),
      );
      await database
          .into(database.rollbackCheckpoints)
          .insert(
            RollbackCheckpointsCompanion.insert(
              id: 'rollback-$runId',
              importRunId: runId,
              backupPath: backup.file.path,
              backupSha256: backup.fingerprint,
              backupFormatVersion: backup.manifest.formatVersion,
              keyAlias: 'synthetic-test-key',
            ),
          );

      final restored = AppDatabase.inMemory();
      addTearDown(restored.close);
      await _insertRun(restored, id: runId, state: 'applying');
      await restored
          .into(restored.users)
          .insert(
            UsersCompanion.insert(
              id: 'synthetic-pre-import-user',
              timezone: const Value('UTC'),
              syncStatus: const Value('local_only'),
            ),
          );
      var activeDatabase = database;
      coordinator = PersistentMigrationCoordinator(
        database: () => activeDatabase,
        liveDatabaseFile: () async => encryptedLive,
        rollbackDirectory: () async => Directory('${temporary.path}/rollback'),
        registry: registry,
        staging: staging,
        backups: backups,
        restoreCheckpoint: (_) async {
          activeDatabase = restored;
        },
        now: () => DateTime.utc(2026, 7, 18, 12),
      );

      await coordinator!.rollback(runId);

      expect((await _run(restored, runId)).state, 'rolled_back');
      expect(await _count(restored, 'users'), 1);
      expect(await _count(restored, 'accounts'), 0);
      expect(await backup.file.exists(), isFalse);
    },
  );
}

PersistentMigrationCoordinator _coordinator({
  required AppDatabase database,
  required CashewStagingService staging,
  required CashewSourceRegistry registry,
  required LootrBackupService backups,
  required Directory temporary,
}) {
  return PersistentMigrationCoordinator(
    database: () => database,
    liveDatabaseFile: () async => File('${temporary.path}/live.sqlite'),
    rollbackDirectory: () async => Directory('${temporary.path}/rollback'),
    registry: registry,
    staging: staging,
    backups: backups,
    restoreCheckpoint: (_) async {},
    now: () => DateTime.utc(2026, 7, 18, 12),
  );
}

Future<void> _insertRun(
  AppDatabase database, {
  required String id,
  required String state,
  String fingerprint = 'synthetic-fingerprint',
  String? stagingToken,
}) {
  return database
      .into(database.importRuns)
      .insert(
        ImportRunsCompanion.insert(
          id: id,
          sourceSystem: 'cashew',
          sourceFingerprint: fingerprint,
          sourceSchemaVersion: 48,
          state: state,
          stagingToken: Value(stagingToken),
          policyJson: const Value(
            '{"timezone_id":"UTC","timezone_label":"UTC",'
            '"title_policy":"preserveAndSuggest"}',
          ),
        ),
      );
}

Future<ImportRunData> _run(AppDatabase database, String id) {
  return (database.select(
    database.importRuns,
  )..where((row) => row.id.equals(id))).getSingle();
}

Future<List<int>> _publicationCounts(AppDatabase database, String runId) async {
  Future<int> count(String table, {bool scoped = false}) async {
    final row = await database
        .customSelect(
          'SELECT COUNT(*) AS count FROM $table'
          '${scoped ? ' WHERE import_run_id = ?' : ''}',
          variables: scoped ? [Variable.withString(runId)] : const [],
        )
        .getSingle();
    return row.read<int>('count');
  }

  return Future.wait([
    count('accounts'),
    count('transactions'),
    count('transfers'),
    count('import_source_records', scoped: true),
    count('import_provenance', scoped: true),
    count('import_preserved_payloads', scoped: true),
  ]);
}

Future<int> _count(AppDatabase database, String table) async {
  final row = await database
      .customSelect('SELECT COUNT(*) AS count FROM $table')
      .getSingle();
  return row.read<int>('count');
}

void _createEncryptedPlaceholder(File file) {
  final connection = sqlite.sqlite3.open(file.path);
  try {
    connection.execute('PRAGMA key = ${_keyLiteral()}');
    connection.execute('PRAGMA user_version = 3');
    connection.execute(
      'CREATE TABLE synthetic_checkpoint (id INTEGER PRIMARY KEY)',
    );
  } finally {
    connection.close();
  }
}

String _keyLiteral() {
  final bytes = List<int>.generate(32, (index) => index + 1);
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '"x\'$hex\'"';
}

Future<void> _eventually(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Condition was not met before the redacted test timeout.');
}

class _BlockingCleanupStagingService extends CashewStagingService {
  _BlockingCleanupStagingService(Directory support)
    : super(supportDirectory: () async => support);

  final cleanupStarted = Completer<void>();
  final allowCleanup = Completer<void>();

  @override
  Future<void> cleanupOrphans(Set<String> activeTokens) async {
    cleanupStarted.complete();
    await allowCleanup.future;
    await super.cleanupOrphans(activeTokens);
  }
}

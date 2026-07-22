import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../data/backup/lootr_backup_service.dart';
import '../../data/database/app_database.dart';
import '../../data/migration/cashew/cashew_migration.dart';
import '../../data/migration/cashew_publication_engine.dart';
import '../../data/migration/cashew_source_registry.dart';
import '../../data/migration/cashew_staging_service.dart';
import 'migration_coordinator.dart';
import 'migration_models.dart';

class PersistentMigrationCoordinator implements MigrationCoordinator {
  PersistentMigrationCoordinator({
    required this.database,
    required this.liveDatabaseFile,
    required this.rollbackDirectory,
    required this.registry,
    required this.staging,
    required this.backups,
    required this.restoreCheckpoint,
    this.beginMaintenance,
    this.endMaintenance,
    this.adapter = const CashewSourceAdapter(),
    this.publication = const CashewPublicationEngine(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _startupRecovery = _recoverInterruptedRuns();
  }

  final AppDatabase Function() database;
  final Future<File> Function() liveDatabaseFile;
  final Future<Directory> Function() rollbackDirectory;
  final CashewSourceRegistry registry;
  final CashewStagingService staging;
  final LootrBackupService backups;
  final Future<File> Function(File backup, String runId) restoreCheckpoint;
  final Future<void> Function()? beginMaintenance;
  final Future<void> Function()? endMaintenance;
  final CashewSourceAdapter adapter;
  final CashewPublicationEngine publication;
  final DateTime Function() _now;
  late final Future<void> _startupRecovery;

  final Map<String, CashewAnalysis> _analysis = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  var _disposed = false;

  @override
  Stream<List<MigrationRunProjection>> watchRuns() async* {
    yield await _loadRuns();
    yield* _changes.stream.asyncMap((_) => _loadRuns());
  }

  @override
  Stream<MigrationRunProjection?> watchRun(String runId) async* {
    yield await _loadRun(runId);
    yield* _changes.stream.asyncMap((_) => _loadRun(runId)).distinct();
  }

  @override
  Future<MigrationRunProjection> createRun({
    required MigrationSourceSelection source,
    required MigrationTimezoneOption timezone,
    required MigrationTitlePolicy titlePolicy,
  }) async {
    _ensureActive();
    // Startup recovery owns orphan cleanup. Let it finish before creating a
    // new staging directory so it cannot mistake the new run for an orphan.
    await _startupRecovery;
    final selected = registry.consume(source.opaqueToken);
    final staged = await staging.stage(selected);
    try {
      final existing =
          await (database().select(database().importRuns)
                ..where(
                  (run) =>
                      run.sourceFingerprint.equals(staged.sourceFingerprint) &
                      run.state.isIn(['complete', 'ready', 'needs_review']),
                )
                ..orderBy([(run) => OrderingTerm.desc(run.startedAt)])
                ..limit(1))
              .getSingleOrNull();
      if (existing != null) {
        await staging.cleanup(staged);
        return (await _projection(existing))!;
      }

      final runId = _runId(staged.sourceFingerprint);
      await database()
          .into(database().importRuns)
          .insert(
            ImportRunsCompanion.insert(
              id: runId,
              sourceSystem: 'cashew',
              sourceFingerprint: staged.sourceFingerprint,
              sourceSchemaVersion: 0,
              assumedTimezone: Value(timezone.id),
              state: 'staged',
              policyJson: Value(
                jsonEncode({
                  'timezone_id': timezone.id,
                  'timezone_label': timezone.label,
                  'title_policy': titlePolicy.name,
                }),
              ),
              stagingToken: Value(staged.stagingToken),
            ),
          );
      _emit();
      return (await _loadRun(runId))!;
    } catch (_) {
      await staging.cleanup(staged);
      rethrow;
    }
  }

  @override
  Future<void> analyze(String runId) async {
    await _startupRecovery;
    final run = await _requireRun(runId);
    if (!const {'staged', 'selected', 'interrupted'}.contains(run.state)) {
      return;
    }
    await _setState(runId, 'validating');
    try {
      final source = await _resolve(run);
      final analysis = await adapter.analyzeFile(source.file);
      _analysis[runId] = analysis;
      final safe = _safeAnalysisJson(analysis);
      // Timezone and title/payee behavior are always explicitly confirmed
      // after the user can see the analyzed date range and dispositions.
      const nextState = 'needs_review';
      await (database().update(
        database().importRuns,
      )..where((table) => table.id.equals(runId))).write(
        ImportRunsCompanion(
          sourceSchemaVersion: Value(
            analysis.report.schemaVersion ?? run.sourceSchemaVersion,
          ),
          state: Value(nextState),
          countsJson: Value(jsonEncode(safe)),
        ),
      );
      await _replaceDryRunDetails(runId, analysis);
      _emit();
    } catch (_) {
      await _setState(runId, 'failed');
      await _cleanup(await _requireRun(runId));
      rethrow;
    }
  }

  @override
  Future<void> resolveReviewGroup(String runId, String groupId) async {
    await _startupRecovery;
    final run = await _requireRun(runId);
    if (run.state != 'needs_review') return;
    if (groupId.startsWith('policy.account_type:')) {
      final parts = groupId.split(':');
      const allowed = {
        'cash',
        'bank',
        'ewallet',
        'savings',
        'investment',
        'crypto',
        'credit_card',
        'loan',
        'bnpl',
      };
      if (parts.length != 3 || !allowed.contains(parts[2])) return;
      final json = Map<String, dynamic>.from(
        run.policyJson == null
            ? const <String, dynamic>{}
            : jsonDecode(run.policyJson!) as Map<String, dynamic>,
      );
      final accountTypes = Map<String, dynamic>.from(
        json['account_types'] as Map<String, dynamic>? ?? const {},
      );
      accountTypes[parts[1]] = parts[2];
      json['account_types'] = accountTypes;
      await (database().update(database().importRuns)
            ..where((row) => row.id.equals(runId)))
          .write(ImportRunsCompanion(policyJson: Value(jsonEncode(json))));
      await (database().update(database().importDiscrepancies)..where(
            (row) =>
                row.importRunId.equals(runId) &
                row.issueCode.equals(
                  'policy.account_type_confirmation:${parts[1]}',
                ),
          ))
          .write(const ImportDiscrepanciesCompanion(isResolved: Value(true)));
      _emit();
      return;
    }
    if (groupId.startsWith('policy.account_type_confirmation:')) return;
    final discrepancies = database().importDiscrepancies;
    final blocking =
        await (database().select(discrepancies)..where(
              (row) =>
                  row.importRunId.equals(runId) &
                  row.issueCode.equals(groupId) &
                  row.severity.equals('blocking'),
            ))
            .get();
    if (blocking.isNotEmpty) return;
    await (database().update(discrepancies)..where(
          (row) =>
              row.importRunId.equals(runId) & row.issueCode.equals(groupId),
        ))
        .write(const ImportDiscrepanciesCompanion(isResolved: Value(true)));
    _emit();
  }

  @override
  Future<void> reconcile(String runId) async {
    await _startupRecovery;
    final run = await _requireRun(runId);
    if (run.state == 'interrupted') {
      final mappings =
          await (database().selectOnly(database().importProvenance)
                ..addColumns([database().importProvenance.id.count()])
                ..where(database().importProvenance.importRunId.equals(runId)))
              .map((row) => row.read(database().importProvenance.id.count())!)
              .getSingle();
      if (mappings == 0) {
        await _setState(runId, 'ready');
        return;
      }
      try {
        final analysis = await _loadAnalysis(run);
        await _verifyPublication(
          runId,
          analysis,
          CashewPublicationResult(
            insertedFinancialRecords: 0,
            preservedRecords: 0,
            reusedRecords: mappings,
            accountPartitions: analysis.report.tableCounts['wallets'] ?? 0,
            reviewAccountPartitions: 0,
            totalChangesAfterPublication: await _totalChanges(),
          ),
        );
        await (database().update(
          database().importRuns,
        )..where((table) => table.id.equals(runId))).write(
          ImportRunsCompanion(
            state: const Value('complete'),
            completedAt: Value(_now().toUtc()),
          ),
        );
        await _cleanup(await _requireRun(runId));
        _emit();
      } catch (_) {
        await rollback(runId);
      }
      return;
    }
    if (run.state != 'needs_review') return;
    final unresolved =
        await (database().select(database().importDiscrepancies)..where(
              (row) =>
                  row.importRunId.equals(runId) &
                  row.isResolved.equals(false) &
                  row.severity.isIn(['review', 'blocking']),
            ))
            .get();
    if (unresolved.isNotEmpty) return;
    final report = _reportJson(run);
    final reconciliation =
        report['reconciliation'] as Map<String, dynamic>? ?? const {};
    if (reconciliation['passed'] != true) {
      throw const PersistentMigrationFailure('reconciliation_blocking');
    }
    await _setState(runId, 'ready');
  }

  @override
  Future<void> apply(String runId) async {
    await _startupRecovery;
    try {
      await beginMaintenance?.call();
    } on StateError {
      // Another publication, restore, or rollback owns the database session.
      return;
    }
    try {
      final claimed = await database().customUpdate(
        "UPDATE import_runs SET state = 'applying' "
        "WHERE id = ? AND state = 'ready'",
        variables: [Variable.withString(runId)],
      );
      if (claimed != 1) return;
      var run = await _requireRun(runId);
      final analysis = await _loadAnalysis(run);
      if (analysis.report.hasBlockingIssues ||
          !analysis.report.reconciliation.passed) {
        await _setState(runId, 'ready');
        throw const PersistentMigrationFailure('publication_not_safe');
      }

      late _PreparedRollbackCheckpoint checkpoint;
      try {
        checkpoint = await _createRollbackCheckpoint(run);
      } catch (_) {
        await _setState(runId, 'ready');
        rethrow;
      }
      int? expectedVerificationChanges;
      var publicationVerified = false;
      try {
        final policy = _policy(run);
        final result = await publication.publish(
          database: database(),
          importRunId: runId,
          analysis: analysis,
          titlePolicy: policy.titlePolicy.name,
          timezoneId: policy.timezoneId,
          accountTypes: policy.accountTypes,
          expectedTotalChanges: checkpoint.expectedTotalChanges,
        );
        expectedVerificationChanges = result.totalChangesAfterPublication;
        await _setState(runId, 'verifying');
        expectedVerificationChanges++;
        await _assertTargetUnchanged(expectedVerificationChanges);
        await _verifyPublication(runId, analysis, result);
        await _assertTargetUnchanged(expectedVerificationChanges);
        publicationVerified = true;

        // Verification succeeded. Errors after this point must never trigger
        // an automatic restore of the pre-import checkpoint.
        await (database().update(
          database().importRuns,
        )..where((table) => table.id.equals(runId))).write(
          ImportRunsCompanion(
            state: const Value('complete'),
            completedAt: Value(_now().toUtc()),
            countsJson: Value(
              jsonEncode({
                ..._safeAnalysisJson(analysis),
                'publication': {
                  'inserted_financial_records': result.insertedFinancialRecords,
                  'preserved_records': result.preservedRecords,
                  'reused_records': result.reusedRecords,
                  'account_partitions': result.accountPartitions,
                  'review_account_partitions': result.reviewAccountPartitions,
                },
              }),
            ),
          ),
        );
        run = await _requireRun(runId);
        await _cleanup(run);
        _analysis.remove(runId);
        _emit();
      } on CashewPublicationFailure catch (error, stackTrace) {
        if (publicationVerified) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        if (error.code == 'target_changed_during_checkpoint') {
          await _discardPreparedCheckpoint(runId, checkpoint);
          await _setState(runId, 'ready');
          rethrow;
        }
        if (expectedVerificationChanges == null) {
          // The publication transaction did not commit, so restoring an older
          // file could only discard an unrelated write made after checkpoint.
          await _discardPreparedCheckpoint(runId, checkpoint);
          await _setState(runId, 'ready');
          Error.throwWithStackTrace(error, stackTrace);
        }
        if (await _targetChanged(expectedVerificationChanges)) {
          await _setState(runId, 'interrupted');
          throw const PersistentMigrationFailure(
            'target_changed_during_verification',
          );
        }
        await _setState(runId, 'failed');
        if (expectedVerificationChanges != null) {
          expectedVerificationChanges++;
          if (await _targetChanged(expectedVerificationChanges)) {
            await _setState(runId, 'interrupted');
            throw const PersistentMigrationFailure(
              'target_changed_during_verification',
            );
          }
        }
        if (!await checkpoint.backup.file.exists()) {
          await _cleanup(await _requireRun(runId));
          throw const PersistentMigrationFailure('checkpoint_lost');
        }
        try {
          await _rollbackInternal(
            runId,
            expectedTotalChangesBeforeRestore: expectedVerificationChanges,
          );
        } on PersistentMigrationFailure catch (rollbackError) {
          if (rollbackError.code == 'target_changed_during_verification') {
            await _setState(runId, 'interrupted');
            throw rollbackError;
          }
          // Preserve the publication failure; startup recovery retains both
          // the run and checkpoint if automatic rollback cannot complete.
        } catch (_) {
          // Preserve the publication failure for other recovery errors.
        }
        Error.throwWithStackTrace(error, stackTrace);
      } catch (error, stackTrace) {
        if (publicationVerified) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        if (expectedVerificationChanges == null) {
          // A thrown publication future is atomic and has already rolled back
          // its transaction. Keep the live database instead of replacing it.
          await _discardPreparedCheckpoint(runId, checkpoint);
          await _setState(runId, 'ready');
          Error.throwWithStackTrace(error, stackTrace);
        }
        if (await _targetChanged(expectedVerificationChanges)) {
          await _setState(runId, 'interrupted');
          throw const PersistentMigrationFailure(
            'target_changed_during_verification',
          );
        }
        await _setState(runId, 'failed');
        if (expectedVerificationChanges != null) {
          expectedVerificationChanges++;
          if (await _targetChanged(expectedVerificationChanges)) {
            await _setState(runId, 'interrupted');
            throw const PersistentMigrationFailure(
              'target_changed_during_verification',
            );
          }
        }
        if (!await checkpoint.backup.file.exists()) {
          await _cleanup(await _requireRun(runId));
          throw const PersistentMigrationFailure('checkpoint_lost');
        }
        try {
          await _rollbackInternal(
            runId,
            expectedTotalChangesBeforeRestore: expectedVerificationChanges,
          );
        } on PersistentMigrationFailure catch (rollbackError) {
          if (rollbackError.code == 'target_changed_during_verification') {
            await _setState(runId, 'interrupted');
            throw rollbackError;
          }
          // Preserve the original failure for diagnosis and retry recovery.
        } catch (_) {
          // Preserve the original failure for other recovery errors.
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    } finally {
      await endMaintenance?.call();
    }
  }

  @override
  Future<void> cancel(String runId) async {
    await _startupRecovery;
    final run = await _requireRun(runId);
    if (!const {
      'selected',
      'staged',
      'validating',
      'validated',
      'needs_review',
      'ready',
      'interrupted',
    }.contains(run.state)) {
      return;
    }
    await _setState(runId, 'cancel_requested');
    await _cleanup(await _requireRun(runId));
    await _setState(runId, 'cancelled');
    _analysis.remove(runId);
  }

  @override
  Future<void> rollback(String runId) async {
    await _startupRecovery;
    try {
      await beginMaintenance?.call();
    } on StateError {
      // A concurrent maintenance operation will leave the run resumable.
      return;
    }
    try {
      await _rollbackInternal(runId);
    } finally {
      await endMaintenance?.call();
    }
  }

  Future<void> _rollbackInternal(
    String runId, {
    int? expectedTotalChangesBeforeRestore,
  }) async {
    final run = await _requireRun(runId);
    if (run.state != 'complete' &&
        run.state != 'failed' &&
        run.state != 'interrupted') {
      return;
    }
    final checkpoint = await (database().select(
      database().rollbackCheckpoints,
    )..where((row) => row.importRunId.equals(runId))).getSingleOrNull();
    if (checkpoint == null || checkpoint.state != 'ready') {
      throw const PersistentMigrationFailure('rollback_checkpoint_missing');
    }
    final file = File(checkpoint.backupPath);
    final actualFingerprint = await sha256.bind(file.openRead()).first;
    if (actualFingerprint.toString() != checkpoint.backupSha256) {
      throw const PersistentMigrationFailure('rollback_checkpoint_changed');
    }
    final manifest = await backups.verify(file);
    if (manifest.formatVersion != checkpoint.backupFormatVersion) {
      throw const PersistentMigrationFailure('rollback_checkpoint_invalid');
    }
    if (expectedTotalChangesBeforeRestore != null) {
      await _assertTargetUnchanged(expectedTotalChangesBeforeRestore);
    }
    final restoreSafetyCheckpoint = await restoreCheckpoint(file, runId);
    await _cleanup(await _requireRun(runId));
    await (database().update(
      database().importRuns,
    )..where((row) => row.id.equals(runId))).write(
      ImportRunsCompanion(
        state: const Value('rolled_back'),
        completedAt: Value(_now().toUtc()),
      ),
    );
    await backups.discardCheckpoint(restoreSafetyCheckpoint);
    await backups.discardCheckpoint(file);
    _emit();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _changes.close();
  }

  Future<_PreparedRollbackCheckpoint> _createRollbackCheckpoint(
    ImportRunData run,
  ) async {
    final root = await rollbackDirectory();
    await root.create(recursive: true);
    final destination = File(p.join(root.path, '${run.id}.lootr'));
    final before = await _totalChanges();
    final result = await backups.create(
      liveDatabase: await liveDatabaseFile(),
      destination: destination,
    );
    final afterBackup = await _totalChanges();
    if (afterBackup != before) {
      await backups.discardCheckpoint(result.file);
      throw const PersistentMigrationFailure(
        'database_changed_during_checkpoint',
      );
    }
    await database()
        .into(database().rollbackCheckpoints)
        .insert(
          RollbackCheckpointsCompanion.insert(
            id: 'rollback-${run.id}',
            importRunId: run.id,
            backupPath: result.file.path,
            backupSha256: result.fingerprint,
            backupFormatVersion: result.manifest.formatVersion,
            keyAlias: 'platform-secure-database-key',
          ),
          mode: InsertMode.insert,
        );
    return _PreparedRollbackCheckpoint(
      backup: result,
      expectedTotalChanges: afterBackup + 1,
    );
  }

  Future<void> _assertTargetUnchanged(int expectedTotalChanges) async {
    if (await _totalChanges() != expectedTotalChanges) {
      throw const PersistentMigrationFailure(
        'target_changed_during_verification',
      );
    }
  }

  Future<bool> _targetChanged(int? expectedTotalChanges) async =>
      expectedTotalChanges != null &&
      await _totalChanges() != expectedTotalChanges;

  Future<void> _discardPreparedCheckpoint(
    String runId,
    _PreparedRollbackCheckpoint checkpoint,
  ) async {
    await (database().delete(
      database().rollbackCheckpoints,
    )..where((row) => row.importRunId.equals(runId))).go();
    await backups.discardCheckpoint(checkpoint.backup.file);
  }

  Future<int> _totalChanges() async {
    final row = await database()
        .customSelect('SELECT total_changes() AS value')
        .getSingle();
    return row.read<int>('value');
  }

  Future<void> _verifyPublication(
    String runId,
    CashewAnalysis analysis,
    CashewPublicationResult result,
  ) async {
    final foreignKeys = await database()
        .customSelect('PRAGMA foreign_key_check')
        .get();
    if (foreignKeys.isNotEmpty) {
      throw const PersistentMigrationFailure('target_foreign_key_failed');
    }
    final sourceCount =
        await (database().selectOnly(database().importSourceRecords)
              ..addColumns([database().importSourceRecords.id.count()])
              ..where(database().importSourceRecords.importRunId.equals(runId)))
            .map((row) => row.read(database().importSourceRecords.id.count())!)
            .getSingle();
    if (sourceCount != analysis.records.length ||
        result.accountPartitions !=
            (analysis.report.tableCounts['wallets'] ?? 0)) {
      throw const PersistentMigrationFailure('publication_count_mismatch');
    }
    final relationCount = await _runTableCount(
      'import_source_relations',
      runId,
    );
    final preservedCount = await _runTableCount(
      'import_preserved_payloads',
      runId,
    );
    final discrepancyCount = await _runTableCount(
      'import_discrepancies',
      runId,
    );
    if (relationCount != analysis.relationships.length ||
        preservedCount != analysis.records.length ||
        discrepancyCount !=
            analysis.issues.length +
                2 +
                (analysis.report.tableCounts['wallets'] ?? 0)) {
      throw const PersistentMigrationFailure('publication_inventory_mismatch');
    }
    await _verifyDomainCounts(runId, analysis);
    await _verifyTransferLegs(runId, analysis);
    await _verifyTransactionMappings(runId, analysis);
    await _verifyObjectiveEventTotals(runId, analysis);
    await _verifySourceAccountPartitions(runId, analysis);
    await _verifyStoredBalances(runId);
  }

  Future<void> _verifySourceAccountPartitions(
    String runId,
    CashewAnalysis analysis,
  ) async {
    final transactions = analysis.records
        .where((record) => record.sourceTable == 'transactions')
        .toList();
    final reviewWallets = transactions
        .where(
          (record) =>
              record.disposition == CashewDisposition.reviewRequired ||
              record.disposition == CashewDisposition.invalidBlocking,
        )
        .map((record) => record.privatePayload['wallet_fk'])
        .toSet();
    final byToken = {
      for (final transaction in transactions)
        transaction.sourceToken: transaction,
    };
    for (final relation in analysis.relationships.where(
      (relation) =>
          relation.disposition == CashewDisposition.reviewRequired ||
          relation.disposition == CashewDisposition.invalidBlocking,
    )) {
      final from = byToken[relation.fromToken];
      final to = relation.toToken == null ? null : byToken[relation.toToken];
      if (from != null) reviewWallets.add(from.privatePayload['wallet_fk']);
      if (to != null) reviewWallets.add(to.privatePayload['wallet_fk']);
    }
    for (final wallet in analysis.records.where(
      (record) => record.sourceTable == 'wallets',
    )) {
      final sourceWalletId = wallet.privatePayload['wallet_pk'];
      if (reviewWallets.contains(sourceWalletId)) continue;
      final precision = wallet.privatePayload['decimals'] as int;
      final currency = (wallet.privatePayload['currency'] as String?)?.trim();
      var expected = BigInt.zero;
      for (final transaction in transactions.where(
        (record) =>
            record.privatePayload['wallet_fk'] == sourceWalletId &&
            record.privatePayload['paid'] == 1,
      )) {
        final raw = transaction.privatePayload['canonical_amount_decimal'];
        if (raw is! CashewDecimal) {
          throw const PersistentMigrationFailure('source_amount_missing');
        }
        final atoms = raw.absolute.quantized(precision).coefficient.abs();
        expected += transaction.privatePayload['income'] == 1 ? atoms : -atoms;
      }
      final target = await database()
          .customSelect(
            '''
            SELECT account.balance_atoms, account.currency_precision,
                   account.currency_code
            FROM accounts account
            INNER JOIN import_provenance provenance
              ON provenance.target_table = 'accounts'
             AND provenance.target_id = account.id
            WHERE provenance.import_run_id = ?
              AND provenance.source_entity_id = ?
            LIMIT 1
            ''',
            variables: [
              Variable.withString(runId),
              Variable.withString(_sourceEntityId(wallet)),
            ],
          )
          .getSingleOrNull();
      final expectedCurrency = currency == null || currency.isEmpty
          ? 'UNKNOWN'
          : currency;
      if (target == null ||
          target.read<String>('balance_atoms') != expected.toString() ||
          target.read<int>('currency_precision') != precision ||
          target.read<String>('currency_code') != expectedCurrency) {
        throw const PersistentMigrationFailure(
          'publication_account_partition_mismatch',
        );
      }
    }
  }

  Future<int> _runTableCount(String table, String runId) async {
    const allowed = {
      'import_source_relations',
      'import_preserved_payloads',
      'import_discrepancies',
    };
    if (!allowed.contains(table)) throw ArgumentError.value(table, 'table');
    final row = await database()
        .customSelect(
          'SELECT COUNT(*) AS count FROM $table WHERE import_run_id = ?',
          variables: [Variable.withString(runId)],
        )
        .getSingle();
    return row.read<int>('count');
  }

  Future<void> _verifyDomainCounts(
    String runId,
    CashewAnalysis analysis,
  ) async {
    Future<int> provenanceTargets(String targetTable) async {
      final row = await database()
          .customSelect(
            '''
            SELECT COUNT(DISTINCT target_id) AS count
            FROM import_provenance
            WHERE import_run_id = ? AND target_table = ?
            ''',
            variables: [
              Variable.withString(runId),
              Variable.withString(targetTable),
            ],
            readsFrom: {database().importProvenance},
          )
          .getSingle();
      return row.read<int>('count');
    }

    final expectedTransfers =
        analysis.report.transfers.resolvedPairs -
        analysis.report.transfers.reviewPairs;
    final actual = await Future.wait([
      provenanceTargets('accounts'),
      provenanceTargets('transfers'),
      provenanceTargets('recurring_templates'),
      provenanceTargets('budget_definitions'),
      provenanceTargets('categorization_rules'),
    ]);
    final expected = [
      analysis.report.tableCounts['wallets'] ?? 0,
      expectedTransfers,
      analysis.report.domains.recurringSeries,
      analysis.report.domains.budgets,
      analysis.report.domains.categorizationRules,
    ];
    if (!_sameCounts(actual, expected)) {
      throw const PersistentMigrationFailure(
        'publication_domain_count_mismatch',
      );
    }

    final membershipRow = await database()
        .customSelect(
          '''
          SELECT COUNT(*) AS count
          FROM budget_transaction_memberships membership
          WHERE EXISTS (
            SELECT 1 FROM import_provenance provenance
            WHERE provenance.import_run_id = ?
              AND provenance.target_table = 'budget_definitions'
              AND provenance.target_id = membership.budget_id
          )
          ''',
          variables: [Variable.withString(runId)],
        )
        .getSingle();
    if (membershipRow.read<int>('count') !=
        analysis.report.domains.explicitBudgetMemberships) {
      throw const PersistentMigrationFailure(
        'publication_budget_membership_mismatch',
      );
    }
  }

  bool _sameCounts(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  Future<void> _verifyTransferLegs(
    String runId,
    CashewAnalysis analysis,
  ) async {
    final records = {
      for (final record in analysis.records) record.sourceToken: record,
    };
    final wallets = {
      for (final record in analysis.records.where(
        (record) => record.sourceTable == 'wallets',
      ))
        record.privatePayload['wallet_pk']: record,
    };
    final checked = <String>{};
    for (final relation in analysis.relationships.where(
      (relation) =>
          relation.disposition == CashewDisposition.transformedImport &&
          (relation.kind == 'same_currency_transfer' ||
              relation.kind == 'cross_currency_transfer'),
    )) {
      final toToken = relation.toToken;
      if (toToken == null) continue;
      final key = [relation.fromToken, toToken]..sort();
      if (!checked.add(key.join('\u0000'))) continue;
      final left = records[relation.fromToken];
      final right = records[toToken];
      if (left == null || right == null) {
        throw const PersistentMigrationFailure(
          'publication_transfer_mapping_mismatch',
        );
      }
      final source = left.privatePayload['income'] == 1 ? right : left;
      final destination = identical(source, left) ? right : left;
      final sourceAmount = _sourceAmount(source, wallets);
      final destinationAmount = _sourceAmount(destination, wallets);
      final sourceId = _sourceEntityId(source);
      final row = await database()
          .customSelect(
            '''
            SELECT transfer.source_amount_atoms,
                   transfer.source_currency_code,
                   transfer.destination_amount_atoms,
                   transfer.destination_currency_code
            FROM transfers transfer
            INNER JOIN import_provenance provenance
              ON provenance.target_table = 'transfers'
             AND provenance.target_id = transfer.id
            WHERE provenance.import_run_id = ?
              AND provenance.source_entity_id = ?
            LIMIT 1
            ''',
            variables: [
              Variable.withString(runId),
              Variable.withString(sourceId),
            ],
          )
          .getSingleOrNull();
      if (row == null ||
          row.read<String>('source_amount_atoms') !=
              sourceAmount.$1.toString() ||
          row.read<String>('source_currency_code') != sourceAmount.$2 ||
          row.read<String>('destination_amount_atoms') !=
              destinationAmount.$1.toString() ||
          row.read<String>('destination_currency_code') !=
              destinationAmount.$2) {
        throw const PersistentMigrationFailure(
          'publication_transfer_amount_mismatch',
        );
      }
    }
  }

  Future<void> _verifyTransactionMappings(
    String runId,
    CashewAnalysis analysis,
  ) async {
    final transformedTransferTokens = <String>{};
    final reviewedTransferTokens = <String>{};
    for (final relation in analysis.relationships.where(
      (relation) =>
          relation.kind == 'same_currency_transfer' ||
          relation.kind == 'cross_currency_transfer',
    )) {
      final destination =
          relation.disposition == CashewDisposition.transformedImport
          ? transformedTransferTokens
          : reviewedTransferTokens;
      destination.add(relation.fromToken);
      if (relation.toToken != null) destination.add(relation.toToken!);
    }
    final wallets = {
      for (final record in analysis.records.where(
        (record) => record.sourceTable == 'wallets',
      ))
        record.privatePayload['wallet_pk']: record,
    };
    for (final record in analysis.records.where(
      (candidate) =>
          candidate.sourceTable == 'transactions' &&
          candidate.privatePayload['paid'] == 1,
    )) {
      if (transformedTransferTokens.contains(record.sourceToken) ||
          reviewedTransferTokens.contains(record.sourceToken) ||
          record.disposition == CashewDisposition.reviewRequired) {
        continue;
      }
      final amount = _sourceAmount(record, wallets);
      final target = await database()
          .customSelect(
            '''
            SELECT target_transaction.amount_atoms,
                   target_transaction.amount_scale,
                   target_transaction.currency_code,
                   target_transaction.transaction_direction
            FROM transactions target_transaction
            INNER JOIN import_provenance provenance
              ON provenance.target_table = 'transactions'
             AND provenance.target_id = target_transaction.id
            WHERE provenance.import_run_id = ?
              AND provenance.source_entity_id = ?
            LIMIT 1
            ''',
            variables: [
              Variable.withString(runId),
              Variable.withString(_sourceEntityId(record)),
            ],
          )
          .getSingleOrNull();
      final wallet = wallets[record.privatePayload['wallet_fk']];
      final scale =
          wallet?.privatePayload['decimals'] as int? ??
          (record.privatePayload['canonical_amount_decimal'] as CashewDecimal)
              .scale;
      final direction = record.privatePayload['income'] == 1
          ? 'income'
          : 'expense';
      if (target == null ||
          target.read<String>('amount_atoms') != amount.$1.toString() ||
          target.read<int>('amount_scale') != scale ||
          target.read<String>('currency_code') != amount.$2 ||
          target.read<String>('transaction_direction') != direction) {
        throw const PersistentMigrationFailure(
          'publication_transaction_mapping_mismatch',
        );
      }
    }
  }

  (BigInt, String) _sourceAmount(
    CanonicalCashewRecord record,
    Map<Object?, CanonicalCashewRecord> wallets,
  ) {
    final wallet = wallets[record.privatePayload['wallet_fk']];
    final precision = wallet?.privatePayload['decimals'] as int?;
    final currency =
        (wallet?.privatePayload['currency'] as String?)?.trim() ?? 'UNKNOWN';
    final raw = record.privatePayload['canonical_amount_decimal'];
    if (raw is! CashewDecimal) {
      throw const PersistentMigrationFailure('source_amount_missing');
    }
    final exact = precision == null
        ? raw.absolute
        : raw.absolute.quantized(precision);
    return (exact.coefficient.abs(), currency.isEmpty ? 'UNKNOWN' : currency);
  }

  Future<void> _verifyObjectiveEventTotals(
    String runId,
    CashewAnalysis analysis,
  ) async {
    final objectives = {
      for (final record in analysis.records.where(
        (record) => record.sourceTable == 'objectives',
      ))
        record.privatePayload['objective_pk']: record,
    };
    final wallets = {
      for (final record in analysis.records.where(
        (record) => record.sourceTable == 'wallets',
      ))
        record.privatePayload['wallet_pk']: record,
    };
    final expectedTotals = <Object, Map<String, BigInt>>{};
    var expected = 0;
    for (final transaction in analysis.records.where(
      (record) =>
          record.sourceTable == 'transactions' &&
          record.privatePayload['paid'] == 1,
    )) {
      final references = [
        (transaction.privatePayload['objective_fk'], false),
        (transaction.privatePayload['objective_loan_fk'], true),
      ];
      for (final reference in references) {
        final sourceId = reference.$1;
        final objective = objectives[sourceId];
        if (sourceId == null ||
            objective == null ||
            (objective.privatePayload['type'] == 1) != reference.$2) {
          continue;
        }
        final amount = _sourceAmount(transaction, wallets);
        final wallet = wallets[transaction.privatePayload['wallet_fk']];
        final scale =
            wallet?.privatePayload['decimals'] as int? ??
            (transaction.privatePayload['canonical_amount_decimal']
                    as CashewDecimal)
                .scale;
        final partition = '${amount.$2}\u0000$scale';
        final totals = expectedTotals.putIfAbsent(
          sourceId,
          () => <String, BigInt>{},
        );
        totals[partition] = (totals[partition] ?? BigInt.zero) + amount.$1;
        expected++;
      }
    }
    final row = await database()
        .customSelect(
          '''
          SELECT
            (SELECT COUNT(*) FROM goal_contribution_events event
              WHERE EXISTS (
                SELECT 1 FROM import_provenance provenance
                WHERE provenance.import_run_id = ?
                  AND provenance.target_table = 'goals'
                  AND provenance.target_id = event.goal_id
              )) +
            (SELECT COUNT(*) FROM debt_payment_events event
              WHERE EXISTS (
                SELECT 1 FROM import_provenance provenance
                WHERE provenance.import_run_id = ?
                  AND provenance.target_table = 'debt_records'
                  AND provenance.target_id = event.debt_record_id
              )) AS count
          ''',
          variables: [Variable.withString(runId), Variable.withString(runId)],
        )
        .getSingle();
    if (row.read<int>('count') != expected) {
      throw const PersistentMigrationFailure(
        'publication_objective_event_mismatch',
      );
    }

    for (final entry in expectedTotals.entries) {
      final objective = objectives[entry.key]!;
      final debt = objective.privatePayload['type'] == 1;
      final targetTable = debt ? 'debt_records' : 'goals';
      final targetIdRow = await database()
          .customSelect(
            '''
            SELECT target_id FROM import_provenance
            WHERE import_run_id = ?
              AND source_entity_type = 'objectives'
              AND source_entity_id = ?
              AND target_table = ?
            LIMIT 1
            ''',
            variables: [
              Variable.withString(runId),
              Variable.withString(_sourceEntityId(objective)),
              Variable.withString(targetTable),
            ],
          )
          .getSingleOrNull();
      if (targetIdRow == null) {
        throw const PersistentMigrationFailure(
          'publication_objective_total_mismatch',
        );
      }
      final targetId = targetIdRow.read<String>('target_id');
      final eventRows = await database()
          .customSelect(
            debt
                ? 'SELECT amount_atoms, amount_scale, currency_code '
                      'FROM debt_payment_events '
                      'WHERE debt_record_id = ?'
                : 'SELECT amount_atoms, amount_scale, currency_code '
                      'FROM goal_contribution_events '
                      'WHERE goal_id = ?',
            variables: [Variable.withString(targetId)],
          )
          .get();
      final actualTotals = <String, BigInt>{};
      for (final event in eventRows) {
        final partition =
            '${event.read<String>('currency_code')}\u0000'
            '${event.read<int>('amount_scale')}';
        actualTotals[partition] =
            (actualTotals[partition] ?? BigInt.zero) +
            BigInt.parse(event.read<String>('amount_atoms'));
      }
      if (actualTotals.length != entry.value.length ||
          entry.value.entries.any(
            (expected) => actualTotals[expected.key] != expected.value,
          )) {
        throw const PersistentMigrationFailure(
          'publication_objective_total_mismatch',
        );
      }
    }
  }

  Future<void> _verifyStoredBalances(String runId) async {
    final accounts = await database()
        .customSelect(
          '''
          SELECT account.id, account.balance_atoms
          FROM accounts account
          WHERE account.deleted_at IS NULL
            AND EXISTS (
              SELECT 1 FROM import_provenance provenance
              WHERE provenance.import_run_id = ?
                AND provenance.target_table = 'accounts'
                AND provenance.target_id = account.id
            )
          ''',
          variables: [Variable.withString(runId)],
        )
        .get();
    for (final account in accounts) {
      final id = account.read<String>('id');
      var expected = BigInt.zero;
      final transactions = await database()
          .customSelect(
            '''
        SELECT amount_atoms, transaction_direction
        FROM transactions
        WHERE account_id = ? AND deleted_at IS NULL AND amount_atoms IS NOT NULL
        ''',
            variables: [Variable.withString(id)],
          )
          .get();
      for (final row in transactions) {
        final amount = BigInt.parse(row.read<String>('amount_atoms'));
        expected += row.read<String>('transaction_direction') == 'income'
            ? amount
            : -amount;
      }
      final outgoing = await database()
          .customSelect(
            '''
        SELECT source_amount_atoms FROM transfers
        WHERE source_account_id = ? AND deleted_at IS NULL
          AND source_amount_atoms IS NOT NULL
        ''',
            variables: [Variable.withString(id)],
          )
          .get();
      for (final row in outgoing) {
        expected -= BigInt.parse(row.read<String>('source_amount_atoms'));
      }
      final incoming = await database()
          .customSelect(
            '''
        SELECT destination_amount_atoms FROM transfers
        WHERE destination_account_id = ? AND deleted_at IS NULL
          AND destination_amount_atoms IS NOT NULL
        ''',
            variables: [Variable.withString(id)],
          )
          .get();
      for (final row in incoming) {
        expected += BigInt.parse(row.read<String>('destination_amount_atoms'));
      }
      if (account.read<String>('balance_atoms') != expected.toString()) {
        throw const PersistentMigrationFailure('target_balance_mismatch');
      }
    }
  }

  Future<void> _replaceDryRunDetails(
    String runId,
    CashewAnalysis analysis,
  ) async {
    await database().transaction(() async {
      await (database().delete(
        database().importDiscrepancies,
      )..where((row) => row.importRunId.equals(runId))).go();
      await (database().delete(
        database().importSourceRecords,
      )..where((row) => row.importRunId.equals(runId))).go();
      for (var ordinal = 0; ordinal < analysis.records.length; ordinal++) {
        final record = analysis.records[ordinal];
        final payloadHash = sha256
            .convert(utf8.encode(_canonicalPrivateJson(record.privatePayload)))
            .toString();
        await database()
            .into(database().importSourceRecords)
            .insert(
              ImportSourceRecordsCompanion.insert(
                id: 'dry-record-$runId-$ordinal',
                importRunId: runId,
                sourceTable: record.sourceTable,
                sourceEntityId: _sourceEntityId(record),
                sourcePayloadSha256: payloadHash,
                canonicalKind: Value(record.kind),
                canonicalPayloadSha256: Value(payloadHash),
                disposition: _disposition(record.disposition),
                reasonCode: Value(
                  record.issueCodes.isEmpty ? null : record.issueCodes.first,
                ),
              ),
            );
      }
      for (var ordinal = 0; ordinal < analysis.issues.length; ordinal++) {
        final issue = analysis.issues[ordinal];
        await database()
            .into(database().importDiscrepancies)
            .insert(
              ImportDiscrepanciesCompanion.insert(
                id: 'dry-$runId-$ordinal',
                importRunId: runId,
                severity: _severity(issue.severity),
                issueCode: issue.code,
                sourceLocatorHash: Value(
                  issue.sourceToken == null
                      ? null
                      : _hashLocator(issue.sourceToken!),
                ),
                messageCode: issue.code,
                redactedDetailsJson: const Value('{"redacted":true}'),
                isResolved: Value(
                  issue.severity == CashewIssueSeverity.info ||
                      issue.severity == CashewIssueSeverity.warning,
                ),
              ),
            );
      }
      const confirmationCodes = [
        'policy.timezone_confirmation',
        'policy.title_confirmation',
      ];
      for (var ordinal = 0; ordinal < confirmationCodes.length; ordinal++) {
        final code = confirmationCodes[ordinal];
        await database()
            .into(database().importDiscrepancies)
            .insert(
              ImportDiscrepanciesCompanion.insert(
                id: 'confirmation-$runId-$ordinal',
                importRunId: runId,
                severity: 'review',
                issueCode: code,
                messageCode: code,
                redactedDetailsJson: const Value('{"redacted":true}'),
              ),
            );
      }
      final accountCount = analysis.records
          .where((record) => record.sourceTable == 'wallets')
          .length;
      for (var ordinal = 1; ordinal <= accountCount; ordinal++) {
        final partitionId = 'account-partition-$ordinal';
        final code = 'policy.account_type_confirmation:$partitionId';
        await database()
            .into(database().importDiscrepancies)
            .insert(
              ImportDiscrepanciesCompanion.insert(
                id: 'confirmation-$runId-account-$ordinal',
                importRunId: runId,
                severity: 'review',
                issueCode: code,
                messageCode: code,
                redactedDetailsJson: const Value('{"redacted":true}'),
              ),
            );
      }
    });
  }

  Future<CashewAnalysis> _loadAnalysis(ImportRunData run) async {
    final existing = _analysis[run.id];
    if (existing != null) return existing;
    final source = await _resolve(run);
    final analysis = await adapter.analyzeFile(source.file);
    if (analysis.report.sourceSha256 != run.sourceFingerprint) {
      throw const PersistentMigrationFailure('staged_fingerprint_mismatch');
    }
    _analysis[run.id] = analysis;
    return analysis;
  }

  Future<StagedCashewSource> _resolve(ImportRunData run) {
    final token = run.stagingToken;
    if (token == null) {
      throw const PersistentMigrationFailure('staging_token_missing');
    }
    return staging.resolve(
      stagingToken: token,
      sourceFingerprint: run.sourceFingerprint,
    );
  }

  Future<void> _cleanup(ImportRunData run) async {
    if (run.cleanupStatus == 'complete' && run.stagingToken == null) return;
    await (database().update(
      database().importRuns,
    )..where((row) => row.id.equals(run.id))).write(
      ImportRunsCompanion(
        cleanupStatus: const Value('in_progress'),
        cleanupAttempts: Value(run.cleanupAttempts + 1),
      ),
    );
    try {
      if (run.stagingToken != null) {
        await staging.cleanupToken(run.stagingToken!);
      }
      await (database().update(
        database().importRuns,
      )..where((row) => row.id.equals(run.id))).write(
        const ImportRunsCompanion(
          cleanupStatus: Value('complete'),
          stagingToken: Value(null),
        ),
      );
    } catch (_) {
      await (database().update(
        database().importRuns,
      )..where((row) => row.id.equals(run.id))).write(
        const ImportRunsCompanion(
          cleanupStatus: Value('best_effort_incomplete'),
        ),
      );
    }
  }

  Future<void> _recoverInterruptedRuns() async {
    try {
      await _recoverInterruptedRollback();
      final allRuns = await database().select(database().importRuns).get();
      final activeTokens = allRuns
          .map((run) => run.stagingToken)
          .whereType<String>()
          .toSet();
      await staging.cleanupOrphans(activeTokens);
      for (final run in allRuns.where(
        (candidate) =>
            candidate.stagingToken != null &&
            (const {
                  'in_progress',
                  'best_effort_incomplete',
                }.contains(candidate.cleanupStatus) ||
                const {
                  'complete',
                  'failed',
                  'cancelled',
                  'rolled_back',
                }.contains(candidate.state)),
      )) {
        await _cleanup(run);
      }
      final runs =
          await (database().select(database().importRuns)..where(
                (run) => run.state.isIn([
                  'validating',
                  'applying',
                  'verifying',
                  'cancel_requested',
                ]),
              ))
              .get();
      for (final run in runs) {
        if (run.state == 'cancel_requested') {
          await _cleanup(run);
          await _setState(run.id, 'cancelled');
          continue;
        }
        if (run.state == 'validating') {
          await _setState(run.id, 'staged');
          continue;
        }
        // Publication itself is transactional, so a restart can observe only
        // the complete committed set or no publication rows at all. Never
        // leave an applying/verifying run stuck in a non-interactive state:
        // explicit recovery can verify the retained provenance/checkpoint or
        // restore the pre-import checkpoint.
        await _setState(run.id, 'interrupted');
      }
    } catch (_) {
      // Opening the encrypted database may still be in progress. The first
      // explicit user action will perform the same state checks.
    }
  }

  Future<void> _recoverInterruptedRollback() async {
    final live = await liveDatabaseFile();
    final marker = File('${live.path}.restore-pending');
    if (!await marker.exists()) return;
    final payload = await marker.readAsString();
    if (!payload.startsWith('rollback:')) return;
    final runId = payload.substring('rollback:'.length);
    if (runId.isEmpty) return;
    final run = await (database().select(
      database().importRuns,
    )..where((row) => row.id.equals(runId))).getSingleOrNull();
    if (run == null) return;
    await _cleanup(run);
    await (database().update(
      database().importRuns,
    )..where((row) => row.id.equals(runId))).write(
      ImportRunsCompanion(
        state: const Value('rolled_back'),
        completedAt: Value(_now().toUtc()),
      ),
    );
    await backups.discardCheckpoint(File('${live.path}.pre-restore'));
    final root = await rollbackDirectory();
    await backups.discardCheckpoint(File(p.join(root.path, '$runId.lootr')));
    _emit();
  }

  Future<List<MigrationRunProjection>> _loadRuns() async {
    final rows = await (database().select(
      database().importRuns,
    )..orderBy([(run) => OrderingTerm.desc(run.startedAt)])).get();
    return Future.wait(
      rows.map(_projection).whereType<Future<MigrationRunProjection>>(),
    );
  }

  Future<MigrationRunProjection?> _loadRun(String runId) async {
    final row = await (database().select(
      database().importRuns,
    )..where((run) => run.id.equals(runId))).getSingleOrNull();
    return row == null ? null : _projection(row);
  }

  Future<MigrationRunProjection?> _projection(ImportRunData run) async {
    final report = _reportJson(run);
    final policy = _policy(run);
    final dispositions =
        report['record_dispositions'] as Map<String, dynamic>? ?? const {};
    final discrepancyRows = await (database().select(
      database().importDiscrepancies,
    )..where((row) => row.importRunId.equals(run.id))).get();
    final groups = <String, List<ImportDiscrepancyData>>{};
    for (final row in discrepancyRows) {
      groups.putIfAbsent(row.issueCode, () => []).add(row);
    }
    final reviewGroups = [
      for (final entry in groups.entries)
        MigrationReviewGroup(
          id: entry.key,
          title: _issueTitle(entry.key),
          description: _issueDescription(entry.key),
          count: entry.value.length,
          level: entry.value.any((row) => row.severity == 'blocking')
              ? MigrationIssueLevel.blocking
              : entry.value.any((row) => row.severity == 'review')
              ? MigrationIssueLevel.needsReview
              : MigrationIssueLevel.info,
          resolved: entry.value.every((row) => row.isResolved),
          items: [
            for (var index = 0; index < entry.value.length; index++)
              MigrationReviewItem(
                safeReference: entry.value[index].sourceLocatorHash == null
                    ? 'Run policy'
                    : 'Source record ${entry.value[index].sourceLocatorHash!.substring(0, 8)}',
                issueCode: entry.value[index].messageCode,
                proposedResolution: _proposedResolution(
                  entry.value[index].issueCode,
                ),
              ),
          ],
        ),
    ];
    final partitionJson =
        report['safe_partitions'] as List<dynamic>? ?? const [];
    final partitions = [
      for (final entry in partitionJson.cast<Map<String, dynamic>>())
        MigrationCurrencyPartition(
          id: entry['id']! as String,
          accountLabel: entry['account_label']! as String,
          currencyLabel: entry['currency']! as String,
          precision: entry['precision']! as int,
          status: entry['needs_review'] == true
              ? MigrationPartitionStatus.needsReview
              : MigrationPartitionStatus.reconciled,
          explanation: entry['needs_review'] == true
              ? 'This partition contains source relationships awaiting review.'
              : 'Ledger reconciles at source precision.',
          accountType: policy.accountTypes[entry['id']! as String] ?? 'bank',
          accountTypeConfirmed: policy.accountTypes.containsKey(
            entry['id']! as String,
          ),
        ),
    ];
    final dates = report['date_bounds'] as Map<String, dynamic>? ?? const {};
    final transactionDates =
        dates['transactions.date_created'] as Map<String, dynamic>?;
    final rollback = await (database().select(
      database().rollbackCheckpoints,
    )..where((row) => row.importRunId.equals(run.id))).getSingleOrNull();
    DateTime? latestImportedMonth;
    var importedAccountIds = const <String>[];
    if (run.state == 'complete') {
      final importedRows = await database()
          .customSelect(
            '''
            SELECT p.target_table, p.target_id
            FROM import_provenance p
            WHERE p.import_run_id = ?
              AND p.target_table IN ('accounts', 'transactions')
        ''',
            variables: [Variable.withString(run.id)],
            readsFrom: {database().importProvenance},
          )
          .get();
      importedAccountIds = importedRows
          .where((row) => row.read<String>('target_table') == 'accounts')
          .map((row) => row.read<String>('target_id'))
          .toSet()
          .toList(growable: false);
      final importedTransactionIds = importedRows
          .where((row) => row.read<String>('target_table') == 'transactions')
          .map((row) => row.read<String>('target_id'))
          .toSet();
      if (importedTransactionIds.isNotEmpty) {
        final latestTransaction =
            await (database().select(database().transactions)
                  ..where(
                    (row) =>
                        row.id.isIn(importedTransactionIds) &
                        row.deletedAt.isNull(),
                  )
                  ..orderBy([(row) => OrderingTerm.desc(row.occurredAt)])
                  ..limit(1))
                .getSingleOrNull();
        latestImportedMonth = latestTransaction?.occurredAt;
      }
    }
    final preservedRows = await database()
        .customSelect(
          '''
          SELECT source_table, COUNT(*) AS count
          FROM import_source_records
          WHERE import_run_id = ?
          GROUP BY source_table
          ORDER BY source_table
          ''',
          variables: [Variable.withString(run.id)],
          readsFrom: {database().importSourceRecords},
        )
        .get();
    return MigrationRunProjection(
      id: run.id,
      phase: _phase(run.state),
      sourceLabel: 'Selected Cashew backup',
      timezoneId: policy.timezoneId,
      timezoneLabel: policy.timezoneLabel,
      titlePolicy: policy.titlePolicy,
      startedAt: run.startedAt,
      updatedAt: run.completedAt ?? run.startedAt,
      progress: _progress(run.state),
      progressLabel: _progressLabel(run.state),
      schemaVersion: run.sourceSchemaVersion == 0
          ? null
          : run.sourceSchemaVersion,
      accountCount:
          (report['table_counts'] as Map<String, dynamic>?)?['wallets']
              as int? ??
          0,
      dateRangeLabel: transactionDates == null
          ? 'Available after analysis'
          : '${transactionDates['minimum_utc']} – ${transactionDates['maximum_utc']}',
      currencyLabels: partitions
          .map((row) => row.currencyLabel)
          .toSet()
          .toList(),
      dispositions: MigrationDispositionCounts(
        exact: dispositions['exactImport'] as int? ?? 0,
        transformed: dispositions['transformedImport'] as int? ?? 0,
        preserved: dispositions['preservedOnly'] as int? ?? 0,
        review: dispositions['reviewRequired'] as int? ?? 0,
        blocking: dispositions['invalidBlocking'] as int? ?? 0,
      ),
      reviewGroups: reviewGroups,
      partitions: partitions,
      cancelRequested: run.state == 'cancel_requested',
      canRollback: rollback?.state == 'ready',
      latestImportedMonth: latestImportedMonth,
      importedAccountIds: importedAccountIds,
      preservedGroups: [
        for (final row in preservedRows)
          MigrationPreservedGroup(
            sourceKind: row.read<String>('source_table'),
            count: row.read<int>('count'),
          ),
      ],
    );
  }

  Map<String, Object?> _safeAnalysisJson(CashewAnalysis analysis) {
    final reviewTokens = analysis.issues
        .where(
          (issue) =>
              issue.severity == CashewIssueSeverity.review ||
              issue.severity == CashewIssueSeverity.blocking,
        )
        .map((issue) => issue.sourceToken)
        .whereType<String>()
        .toSet();
    var ordinal = 0;
    final partitions = <Map<String, Object?>>[];
    for (final record in analysis.records.where(
      (record) => record.sourceTable == 'wallets',
    )) {
      ordinal++;
      final walletId = record.privatePayload['wallet_pk'];
      final needsReview = analysis.records.any(
        (candidate) =>
            reviewTokens.contains(candidate.sourceToken) &&
            candidate.privatePayload['wallet_fk'] == walletId,
      );
      partitions.add({
        'id': 'account-partition-$ordinal',
        'account_label': 'Imported account $ordinal',
        'currency': (record.privatePayload['currency'] as String?) ?? 'Unknown',
        'precision': record.privatePayload['decimals'] as int,
        'needs_review': needsReview,
      });
    }
    return {...analysis.report.toRedactedJson(), 'safe_partitions': partitions};
  }

  Map<String, dynamic> _reportJson(ImportRunData run) {
    if (run.countsJson == null) return {};
    return jsonDecode(run.countsJson!) as Map<String, dynamic>;
  }

  _RunPolicy _policy(ImportRunData run) {
    final json = run.policyJson == null
        ? const <String, dynamic>{}
        : jsonDecode(run.policyJson!) as Map<String, dynamic>;
    final titleName = json['title_policy'] as String?;
    return _RunPolicy(
      timezoneId: json['timezone_id'] as String? ?? 'device',
      timezoneLabel: json['timezone_label'] as String? ?? 'Device timezone',
      titlePolicy: MigrationTitlePolicy.values.firstWhere(
        (value) => value.name == titleName,
        orElse: () => MigrationTitlePolicy.preserveAndSuggest,
      ),
      accountTypes: (json['account_types'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, value.toString())),
    );
  }

  Future<ImportRunData> _requireRun(String runId) async {
    _ensureActive();
    final run = await (database().select(
      database().importRuns,
    )..where((row) => row.id.equals(runId))).getSingleOrNull();
    if (run == null) throw const PersistentMigrationFailure('run_missing');
    return run;
  }

  Future<void> _setState(String runId, String state) async {
    await (database().update(database().importRuns)
          ..where((run) => run.id.equals(runId)))
        .write(ImportRunsCompanion(state: Value(state)));
    _emit();
  }

  MigrationRunPhase _phase(String state) => switch (state) {
    'selected' || 'staged' || 'validated' => MigrationRunPhase.selected,
    'validating' => MigrationRunPhase.analyzing,
    'needs_review' => MigrationRunPhase.needsReview,
    'ready' => MigrationRunPhase.ready,
    'applying' => MigrationRunPhase.applying,
    'verifying' => MigrationRunPhase.verifying,
    'interrupted' => MigrationRunPhase.interrupted,
    'failed' => MigrationRunPhase.failed,
    'complete' => MigrationRunPhase.complete,
    'cancel_requested' || 'cancelled' => MigrationRunPhase.cancelled,
    'rolled_back' => MigrationRunPhase.rolledBack,
    _ => MigrationRunPhase.needsReview,
  };

  double _progress(String state) => switch (state) {
    'selected' || 'staged' => 0,
    'validating' => 0.4,
    'needs_review' => 1,
    'ready' => 1,
    'applying' => 0.45,
    'verifying' => 0.8,
    'complete' || 'cancelled' || 'rolled_back' => 1,
    _ => 0,
  };

  String _progressLabel(String state) => switch (state) {
    'selected' || 'staged' => 'Ready to analyze',
    'validating' => 'Checking the backup',
    'needs_review' => 'Analysis complete',
    'ready' => 'Ready to import',
    'applying' => 'Publishing imported records',
    'verifying' => 'Verifying every account and currency',
    'complete' => 'Import complete',
    'cancel_requested' || 'cancelled' => 'Import cancelled before publication',
    'rolled_back' => 'Pre-import state restored',
    'interrupted' => 'Safe recovery is available',
    'failed' => 'Needs review before continuing',
    _ => 'Needs review',
  };

  String _issueTitle(String code) {
    if (code == 'policy.timezone_confirmation') {
      return 'Confirm source timezone';
    }
    if (code == 'policy.title_confirmation') {
      return 'Confirm title and payee policy';
    }
    if (code.startsWith('policy.account_type_confirmation')) {
      return 'Confirm imported account types';
    }
    if (code.startsWith('transfer.')) return 'Transfer exceptions';
    if (code.startsWith('budget.')) return 'Budget references';
    if (code.startsWith('objective.')) return 'Goal and debt references';
    if (code.startsWith('source.') || code.startsWith('schema.')) {
      return 'Blocking source check';
    }
    if (code.startsWith('delete_log.')) return 'Preserved deletion evidence';
    return 'Needs review';
  }

  String _issueDescription(String code) {
    if (code == 'policy.timezone_confirmation') {
      return 'Compare the detected date range with a known Cashew record, then confirm the selected timezone.';
    }
    if (code == 'policy.title_confirmation') {
      return 'Confirm how exact source titles are preserved and whether payees are suggested or created.';
    }
    if (code.startsWith('policy.account_type_confirmation')) {
      return 'Review each imported account type before any financial rows are published.';
    }
    if (code.startsWith('transfer.')) {
      return 'These transfer relationships remain reviewable and are not counted as spending.';
    }
    if (code.startsWith('budget.')) {
      return 'Deleted account references remain preserved with their source evidence.';
    }
    if (code.startsWith('delete_log.')) {
      return 'Version-ambiguous deletion metadata is preserved and never replayed.';
    }
    return 'Source data remains preserved while this discrepancy is reviewed.';
  }

  String _proposedResolution(String code) {
    if (code == 'policy.timezone_confirmation') {
      return 'Use the selected timezone for offset-free source timestamps.';
    }
    if (code == 'policy.title_confirmation') {
      return 'Apply the selected reversible title/payee behavior.';
    }
    if (code.startsWith('policy.account_type_confirmation')) {
      return 'Publish each account with the confirmed Lootr account type.';
    }
    if (code.startsWith('transfer.')) {
      return 'Preserve the relationship and exclude it from spending.';
    }
    if (code.startsWith('budget.')) {
      return 'Keep the imported budget visible and read-only where needed.';
    }
    if (code.startsWith('objective.')) {
      return 'Preserve the exact event and missing-reference evidence.';
    }
    if (code.startsWith('delete_log.')) {
      return 'Keep as provenance without replaying the tombstone.';
    }
    if (code.startsWith('source.') || code.startsWith('schema.')) {
      return 'Publication remains blocked; select a healthy supported export.';
    }
    return 'Keep the source row recoverable with its conservative disposition.';
  }

  String _severity(CashewIssueSeverity value) => switch (value) {
    CashewIssueSeverity.info => 'info',
    CashewIssueSeverity.warning => 'warning',
    CashewIssueSeverity.review => 'review',
    CashewIssueSeverity.blocking => 'blocking',
  };

  String _disposition(CashewDisposition value) => switch (value) {
    CashewDisposition.exactImport => 'exact_import',
    CashewDisposition.transformedImport => 'transformed_import',
    CashewDisposition.preservedOnly => 'preserved_only',
    CashewDisposition.reviewRequired => 'review_required',
    CashewDisposition.ignoredSafe => 'ignored_safe',
    CashewDisposition.invalidBlocking => 'invalid_blocking',
  };

  String _sourceEntityId(CanonicalCashewRecord record) {
    const keys = {
      'app_settings': ['settings_pk'],
      'associated_titles': ['associated_title_pk'],
      'budgets': ['budget_pk'],
      'categories': ['category_pk'],
      'category_budget_limits': ['category_limit_pk'],
      'delete_logs': ['delete_log_pk'],
      'objectives': ['objective_pk'],
      'scanner_templates': ['scanner_template_pk'],
      'tags': ['tag_pk'],
      'transaction_to_tag_links': ['transaction_pk', 'tag_pk'],
      'transactions': ['transaction_pk'],
      'wallets': ['wallet_pk'],
    };
    return (keys[record.sourceTable] ?? const <String>[])
        .map((key) => record.privatePayload[key].toString())
        .join('\u0000');
  }

  String _canonicalPrivateJson(Object? value) {
    Object? convert(Object? item) {
      if (item is CashewDecimal) return item.toPlainString();
      if (item is CashewAmount) {
        return {
          'raw_decimal': item.rawDecimal.toPlainString(),
          'wallet_precision': item.walletPrecision,
          'at_wallet_precision': item.atWalletPrecision.toPlainString(),
        };
      }
      if (item is DateTime) return item.toUtc().toIso8601String();
      if (item is Map) {
        final entries = item.entries.toList()
          ..sort(
            (left, right) =>
                left.key.toString().compareTo(right.key.toString()),
          );
        return {
          for (final entry in entries)
            entry.key.toString(): convert(entry.value),
        };
      }
      if (item is Iterable) return item.map(convert).toList();
      return item;
    }

    return jsonEncode(convert(value));
  }

  String _hashLocator(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }

  String _runId(String fingerprint) =>
      'cashew-${fingerprint.substring(0, 20)}-${_now().microsecondsSinceEpoch}';

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void _ensureActive() {
    if (_disposed) {
      throw const PersistentMigrationFailure('coordinator_disposed');
    }
  }
}

class _RunPolicy {
  const _RunPolicy({
    required this.timezoneId,
    required this.timezoneLabel,
    required this.titlePolicy,
    required this.accountTypes,
  });

  final String timezoneId;
  final String timezoneLabel;
  final MigrationTitlePolicy titlePolicy;
  final Map<String, String> accountTypes;
}

class _PreparedRollbackCheckpoint {
  const _PreparedRollbackCheckpoint({
    required this.backup,
    required this.expectedTotalChanges,
  });

  final BackupResult backup;
  final int expectedTotalChanges;
}

class PersistentMigrationFailure implements Exception {
  const PersistentMigrationFailure(this.code);

  final String code;

  @override
  String toString() => 'PersistentMigrationFailure($code)';
}

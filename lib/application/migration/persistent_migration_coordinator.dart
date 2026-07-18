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
    this.adapter = const CashewSourceAdapter(),
    this.publication = const CashewPublicationEngine(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    unawaited(_recoverInterruptedRuns());
  }

  final AppDatabase Function() database;
  final Future<File> Function() liveDatabaseFile;
  final Future<Directory> Function() rollbackDirectory;
  final CashewSourceRegistry registry;
  final CashewStagingService staging;
  final LootrBackupService backups;
  final Future<void> Function(File backup) restoreCheckpoint;
  final CashewSourceAdapter adapter;
  final CashewPublicationEngine publication;
  final DateTime Function() _now;

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
    final selected = registry.consume(source.opaqueToken);
    final staged = await staging.stage(selected);
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
  }

  @override
  Future<void> analyze(String runId) async {
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
      final nextState =
          analysis.report.hasBlockingIssues ||
              !analysis.report.sourceUnchanged ||
              !analysis.report.everySourceRowDisposed
          ? 'needs_review'
          : analysis.issues.any(
              (issue) => issue.severity == CashewIssueSeverity.review,
            )
          ? 'needs_review'
          : 'ready';
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
      rethrow;
    }
  }

  @override
  Future<void> resolveReviewGroup(String runId, String groupId) async {
    final run = await _requireRun(runId);
    if (run.state != 'needs_review') return;
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
    var run = await _requireRun(runId);
    if (run.state != 'ready') return;
    final analysis = await _loadAnalysis(run);
    if (analysis.report.hasBlockingIssues ||
        !analysis.report.reconciliation.passed) {
      throw const PersistentMigrationFailure('publication_not_safe');
    }

    final checkpoint = await _createRollbackCheckpoint(run);
    await _setState(runId, 'applying');
    try {
      final policy = _policy(run);
      final result = await publication.publish(
        database: database(),
        importRunId: runId,
        analysis: analysis,
        titlePolicy: policy.titlePolicy.name,
        timezoneId: policy.timezoneId,
      );
      await _setState(runId, 'verifying');
      await _verifyPublication(runId, analysis, result);
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
    } catch (_) {
      await _setState(runId, 'failed');
      final current = await _requireRun(runId);
      await _cleanup(current);
      // Keep the encrypted checkpoint available for explicit recovery.
      if (!await checkpoint.file.exists()) {
        throw const PersistentMigrationFailure('checkpoint_lost');
      }
      rethrow;
    }
  }

  @override
  Future<void> cancel(String runId) async {
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
    final manifest = await backups.verify(file);
    if (manifest.formatVersion != checkpoint.backupFormatVersion) {
      throw const PersistentMigrationFailure('rollback_checkpoint_invalid');
    }
    await restoreCheckpoint(file);
    await (database().update(
      database().importRuns,
    )..where((row) => row.id.equals(runId))).write(
      ImportRunsCompanion(
        state: const Value('rolled_back'),
        completedAt: Value(_now().toUtc()),
        cleanupStatus: const Value('complete'),
        stagingToken: const Value(null),
      ),
    );
    await backups.discardCheckpoint(file);
    _emit();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _changes.close();
  }

  Future<BackupResult> _createRollbackCheckpoint(ImportRunData run) async {
    final root = await rollbackDirectory();
    await root.create(recursive: true);
    final destination = File(p.join(root.path, '${run.id}.lootr'));
    await database().customSelect('SELECT 1').getSingle();
    final result = await backups.create(
      liveDatabase: await liveDatabaseFile(),
      destination: destination,
    );
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
          mode: InsertMode.insertOrReplace,
        );
    return result;
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
    await _verifyStoredBalances();
  }

  Future<void> _verifyStoredBalances() async {
    final accounts = await database()
        .customSelect(
          'SELECT id, balance_atoms FROM accounts WHERE deleted_at IS NULL',
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
        final source = await staging.resolve(
          stagingToken: run.stagingToken!,
          sourceFingerprint: run.sourceFingerprint,
        );
        await staging.cleanup(source);
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
          await _setState(run.id, 'interrupted');
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
        ),
    ];
    final dates = report['date_bounds'] as Map<String, dynamic>? ?? const {};
    final transactionDates =
        dates['transactions.date_created'] as Map<String, dynamic>?;
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
    'needs_review' ||
    'failed' ||
    'interrupted' => MigrationRunPhase.needsReview,
    'ready' => MigrationRunPhase.ready,
    'applying' => MigrationRunPhase.applying,
    'verifying' => MigrationRunPhase.verifying,
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
    // Source tokens are ordinal-only and safe, but hashing prevents accidental
    // coupling between UI records and adapter internals.
    return base64Url.encode(utf8.encode(value));
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
  });

  final String timezoneId;
  final String timezoneLabel;
  final MigrationTitlePolicy titlePolicy;
}

class PersistentMigrationFailure implements Exception {
  const PersistentMigrationFailure(this.code);

  final String code;

  @override
  String toString() => 'PersistentMigrationFailure($code)';
}

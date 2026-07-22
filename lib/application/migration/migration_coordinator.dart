import 'dart:async';

import 'migration_models.dart';

abstract interface class MigrationSourcePicker {
  Future<MigrationPickerResult> chooseCashewFile();
}

abstract interface class DataPortabilityCoordinator {
  Future<DataPortabilityResult> createBackup();
  Future<DataPortabilityResult> restoreBackup();
  Future<DataPortabilityResult> exportTransactionsCsv();
}

abstract interface class MigrationCoordinator {
  Stream<List<MigrationRunProjection>> watchRuns();
  Stream<MigrationRunProjection?> watchRun(String runId);

  Future<MigrationRunProjection> createRun({
    required MigrationSourceSelection source,
    required MigrationTimezoneOption timezone,
    required MigrationTitlePolicy titlePolicy,
  });

  Future<void> analyze(String runId);
  Future<void> resolveReviewGroup(String runId, String groupId);
  Future<void> reconcile(String runId);
  Future<void> apply(String runId);
  Future<void> cancel(String runId);
  Future<void> rollback(String runId);
  Future<void> dispose();
}

/// Production-safe default used until the encrypted persistent engine is
/// injected at app bootstrap. It exposes no synthetic runs and cannot publish
/// or mutate data.
class SafeUnavailableMigrationCoordinator implements MigrationCoordinator {
  const SafeUnavailableMigrationCoordinator();

  static StateError _unavailable() =>
      StateError('The migration engine is unavailable.');

  @override
  Stream<List<MigrationRunProjection>> watchRuns() =>
      Stream.value(const <MigrationRunProjection>[]);

  @override
  Stream<MigrationRunProjection?> watchRun(String runId) => Stream.value(null);

  @override
  Future<MigrationRunProjection> createRun({
    required MigrationSourceSelection source,
    required MigrationTimezoneOption timezone,
    required MigrationTitlePolicy titlePolicy,
  }) {
    return Future.error(_unavailable());
  }

  @override
  Future<void> analyze(String runId) => Future.error(_unavailable());

  @override
  Future<void> apply(String runId) => Future.error(_unavailable());

  @override
  Future<void> cancel(String runId) => Future.error(_unavailable());

  @override
  Future<void> reconcile(String runId) => Future.error(_unavailable());

  @override
  Future<void> resolveReviewGroup(String runId, String groupId) =>
      Future.error(_unavailable());

  @override
  Future<void> rollback(String runId) => Future.error(_unavailable());

  @override
  Future<void> dispose() async {}
}

/// Safe until a platform picker is connected: it never guesses a path or asks
/// for broad storage permission.
class SafeUnavailableMigrationSourcePicker implements MigrationSourcePicker {
  const SafeUnavailableMigrationSourcePicker();

  @override
  Future<MigrationPickerResult> chooseCashewFile() async {
    return const MigrationPickerResult.unavailable(
      'File selection is not available on this device yet. '
      'Your data has not been accessed.',
    );
  }
}

/// Safe until encrypted backup persistence is connected: no success is
/// reported unless bytes were actually written by a real implementation.
class SafeUnavailableDataPortabilityCoordinator
    implements DataPortabilityCoordinator {
  const SafeUnavailableDataPortabilityCoordinator();

  static const _message =
      'This action is not available on this device yet. No data was changed.';

  @override
  Future<DataPortabilityResult> createBackup() async {
    return const DataPortabilityResult(succeeded: false, message: _message);
  }

  @override
  Future<DataPortabilityResult> exportTransactionsCsv() async {
    return const DataPortabilityResult(succeeded: false, message: _message);
  }

  @override
  Future<DataPortabilityResult> restoreBackup() async {
    return const DataPortabilityResult(succeeded: false, message: _message);
  }
}

/// A complete deterministic coordinator used by the UI until the persistent
/// import engine is injected. It retains only redacted projections and never
/// opens the source token.
class InMemoryMigrationCoordinator implements MigrationCoordinator {
  InMemoryMigrationCoordinator({
    DateTime Function()? now,
    this.stepDelay = const Duration(milliseconds: 80),
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Duration stepDelay;
  final Map<String, MigrationRunProjection> _runs = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _nextRun = 1;
  bool _disposed = false;

  @override
  Stream<List<MigrationRunProjection>> watchRuns() async* {
    yield _orderedRuns();
    yield* _changes.stream.map((_) => _orderedRuns());
  }

  @override
  Stream<MigrationRunProjection?> watchRun(String runId) async* {
    yield _runs[runId];
    yield* _changes.stream.map((_) => _runs[runId]).distinct();
  }

  @override
  Future<MigrationRunProjection> createRun({
    required MigrationSourceSelection source,
    required MigrationTimezoneOption timezone,
    required MigrationTitlePolicy titlePolicy,
  }) async {
    _ensureActive();
    final timestamp = _now();
    final run = MigrationRunProjection(
      id: 'migration-run-${_nextRun++}',
      phase: MigrationRunPhase.selected,
      sourceLabel: source.safeLabel,
      timezoneId: timezone.id,
      timezoneLabel: timezone.label,
      titlePolicy: titlePolicy,
      startedAt: timestamp,
      updatedAt: timestamp,
      progress: 0,
      progressLabel: 'Ready to analyze',
      schemaVersion: null,
      accountCount: 0,
      dateRangeLabel: 'Available after analysis',
      currencyLabels: const [],
      dispositions: const MigrationDispositionCounts(
        exact: 0,
        transformed: 0,
        preserved: 0,
        review: 0,
        blocking: 0,
      ),
      reviewGroups: const [],
      partitions: const [],
    );
    _runs[run.id] = run;
    _emit();
    return run;
  }

  @override
  Future<void> analyze(String runId) async {
    final run = _requireRun(runId);
    if (run.phase != MigrationRunPhase.selected) return;

    _replace(
      run.copyWith(
        phase: MigrationRunPhase.analyzing,
        progress: 0.12,
        progressLabel: 'Checking the backup',
      ),
    );
    await _step();
    if (_wasCancelled(runId)) return;
    _replace(
      _requireRun(runId).copyWith(
        progress: 0.46,
        progressLabel: 'Reviewing accounts and currencies',
      ),
    );
    await _step();
    if (_wasCancelled(runId)) return;
    _replace(
      _requireRun(
        runId,
      ).copyWith(progress: 0.78, progressLabel: 'Reconciling relationships'),
    );
    await _step();
    if (_wasCancelled(runId)) return;

    _replace(
      _requireRun(runId).copyWith(
        phase: MigrationRunPhase.needsReview,
        progress: 1,
        progressLabel: 'Analysis complete',
        schemaVersion: 48,
        accountCount: 4,
        dateRangeLabel: 'Multiple historical periods detected',
        currencyLabels: const ['Currency A', 'Currency B', 'Currency C'],
        dispositions: const MigrationDispositionCounts(
          exact: 56,
          transformed: 12,
          preserved: 3,
          review: 2,
          blocking: 0,
        ),
        reviewGroups: const [
          MigrationReviewGroup(
            id: 'transfer-exceptions',
            title: 'Transfer exceptions',
            description: 'A small group needs confirmation before publication.',
            count: 1,
            level: MigrationIssueLevel.needsReview,
          ),
          MigrationReviewGroup(
            id: 'deleted-account-references',
            title: 'Missing account references',
            description:
                'The source is valid. These records will remain preserved '
                'with their deletion evidence.',
            count: 1,
            level: MigrationIssueLevel.needsReview,
          ),
          MigrationReviewGroup(
            id: 'preserved-automation',
            title: 'Preserved for later',
            description:
                'Unsupported automation metadata will remain recoverable.',
            count: 3,
            level: MigrationIssueLevel.info,
            resolved: true,
          ),
        ],
        partitions: const [
          MigrationCurrencyPartition(
            id: 'partition-a',
            accountLabel: 'Imported account 1',
            currencyLabel: 'Currency A',
            precision: 2,
            status: MigrationPartitionStatus.reconciled,
            explanation: 'Ledger reconciles at source precision.',
          ),
          MigrationCurrencyPartition(
            id: 'partition-b',
            accountLabel: 'Imported account 2',
            currencyLabel: 'Currency B',
            precision: 4,
            status: MigrationPartitionStatus.reconciled,
            explanation: 'Ledger reconciles at source precision.',
          ),
          MigrationCurrencyPartition(
            id: 'partition-c',
            accountLabel: 'Imported account 3',
            currencyLabel: 'Currency C',
            precision: 12,
            status: MigrationPartitionStatus.needsReview,
            explanation: 'A preserved relationship needs confirmation.',
          ),
        ],
      ),
    );
  }

  @override
  Future<void> resolveReviewGroup(String runId, String groupId) async {
    final run = _requireRun(runId);
    if (run.phase != MigrationRunPhase.needsReview) return;
    final groups = [
      for (final group in run.reviewGroups)
        if (group.id == groupId) group.copyWith(resolved: true) else group,
    ];
    _replace(run.copyWith(reviewGroups: groups));
  }

  @override
  Future<void> reconcile(String runId) async {
    final run = _requireRun(runId);
    if (run.phase != MigrationRunPhase.needsReview ||
        run.unresolvedReviewCount > 0) {
      return;
    }
    _replace(
      run.copyWith(
        phase: MigrationRunPhase.reconciling,
        progress: 0.25,
        progressLabel: 'Checking every account and currency',
      ),
    );
    await _step();
    if (_wasCancelled(runId)) return;
    _replace(
      _requireRun(runId).copyWith(
        phase: MigrationRunPhase.ready,
        progress: 1,
        progressLabel: 'Ready to import',
        partitions: [
          for (final partition in _requireRun(runId).partitions)
            MigrationCurrencyPartition(
              id: partition.id,
              accountLabel: partition.accountLabel,
              currencyLabel: partition.currencyLabel,
              precision: partition.precision,
              status: MigrationPartitionStatus.reconciled,
              explanation: 'Ledger reconciles at source precision.',
            ),
        ],
      ),
    );
  }

  @override
  Future<void> apply(String runId) async {
    final run = _requireRun(runId);
    if (run.phase != MigrationRunPhase.ready || run.hasBlockingIssues) return;
    _replace(
      run.copyWith(
        phase: MigrationRunPhase.applying,
        progress: 0.3,
        progressLabel: 'Creating a recovery checkpoint',
      ),
    );
    await _step();
    _replace(
      _requireRun(runId).copyWith(
        phase: MigrationRunPhase.verifying,
        progress: 0.72,
        progressLabel: 'Verifying the imported ledger',
      ),
    );
    await _step();
    _replace(
      _requireRun(runId).copyWith(
        phase: MigrationRunPhase.complete,
        progress: 1,
        progressLabel: 'Import complete',
      ),
    );
  }

  @override
  Future<void> cancel(String runId) async {
    final run = _requireRun(runId);
    if (!run.canCancel) return;
    _replace(
      run.copyWith(
        phase: MigrationRunPhase.cancelled,
        progressLabel: 'Import cancelled before publication',
        cancelRequested: true,
      ),
    );
  }

  @override
  Future<void> rollback(String runId) async {
    final run = _requireRun(runId);
    if (run.phase != MigrationRunPhase.complete) return;
    _replace(
      run.copyWith(
        phase: MigrationRunPhase.rolledBack,
        progressLabel: 'Pre-import state restored',
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _changes.close();
  }

  List<MigrationRunProjection> _orderedRuns() {
    final result = _runs.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  MigrationRunProjection _requireRun(String runId) {
    _ensureActive();
    final run = _runs[runId];
    if (run == null) {
      throw StateError('Migration run is unavailable.');
    }
    return run;
  }

  void _replace(MigrationRunProjection run) {
    _runs[run.id] = run.copyWith(updatedAt: _now());
    _emit();
  }

  bool _wasCancelled(String runId) =>
      _runs[runId]?.phase == MigrationRunPhase.cancelled;

  Future<void> _step() {
    if (stepDelay == Duration.zero) return Future<void>.value();
    return Future<void>.delayed(stepDelay);
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void _ensureActive() {
    if (_disposed) throw StateError('Migration coordinator is unavailable.');
  }
}

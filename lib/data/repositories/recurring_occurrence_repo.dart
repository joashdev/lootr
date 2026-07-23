import 'package:drift/drift.dart' hide isNull;

import '../database/app_database.dart';

class RecurringOccurrenceRepo {
  RecurringOccurrenceRepo(this._db);

  final AppDatabase _db;

  Stream<List<RecurringOccurrenceData>> watchAll() {
    return (_db.select(
      _db.recurringOccurrences,
    )..orderBy([(row) => OrderingTerm.asc(row.dueAt)])).watch();
  }

  Stream<RecurringOccurrenceData?> watchById(String id) {
    return (_db.select(_db.recurringOccurrences)
          ..where((row) => row.id.equals(id))
          ..limit(1))
        .watchSingleOrNull();
  }

  Stream<List<RecurringOccurrenceData>> watchForTemplate(String templateId) {
    return (_db.select(_db.recurringOccurrences)
          ..where((row) => row.recurringTemplateId.equals(templateId))
          ..orderBy([(row) => OrderingTerm.asc(row.dueAt)]))
        .watch();
  }

  Future<List<RecurringOccurrenceData>> listByStatus(String status) {
    return (_db.select(_db.recurringOccurrences)
          ..where((row) => row.status.equals(status))
          ..orderBy([(row) => OrderingTerm.asc(row.dueAt)]))
        .get();
  }

  Future<List<RecurringOccurrenceData>> listDueAtOrBefore(DateTime instant) {
    return (_db.select(_db.recurringOccurrences)
          ..where(
            (row) =>
                (row.status.equals('due') | row.status.equals('unpaid')) &
                row.dueAt.isSmallerOrEqualValue(instant),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.dueAt)]))
        .get();
  }

  Future<String> create(RecurringOccurrencesCompanion occurrence) async {
    if (!occurrence.id.present) {
      throw ArgumentError('id is required for create');
    }
    await _db.into(_db.recurringOccurrences).insert(occurrence);
    return occurrence.id.value;
  }

  Future<void> updateOccurrence({
    required String id,
    required DateTime dueAt,
    required String amountAtoms,
    required int amountScale,
    required String currencyCode,
  }) async {
    await _db.transaction(() async {
      final current =
          await (_db.select(_db.recurringOccurrences)
                ..where((row) => row.id.equals(id))
                ..limit(1))
              .getSingleOrNull();
      if (current == null) throw StateError('Occurrence not found');
      if (current.status == 'paid' ||
          current.status == 'skipped' ||
          current.status == 'dismissed') {
        throw StateError('Resolved occurrences cannot be edited');
      }
      await (_db.update(
        _db.recurringOccurrences,
      )..where((row) => row.id.equals(id))).write(
        RecurringOccurrencesCompanion(
          dueAt: Value(dueAt),
          amountAtoms: Value(amountAtoms),
          amountScale: Value(amountScale),
          currencyCode: Value(currencyCode),
        ),
      );
      final earliest =
          await (_db.select(_db.recurringOccurrences)
                ..where(
                  (row) =>
                      row.recurringTemplateId.equals(
                        current.recurringTemplateId,
                      ) &
                      (row.status.equals('due') | row.status.equals('unpaid')),
                )
                ..orderBy([(row) => OrderingTerm.asc(row.dueAt)])
                ..limit(1))
              .getSingleOrNull();
      await (_db.update(
        _db.recurringTemplates,
      )..where((row) => row.id.equals(current.recurringTemplateId))).write(
        RecurringTemplatesCompanion(
          nextOccurrenceAt: Value(earliest?.dueAt),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value('pending_sync'),
        ),
      );
    });
  }

  Future<void> markUnpaid(String id) => _transition(id, 'unpaid');

  Future<void> markPaid(
    String id, {
    required String transactionId,
    required DateTime resolvedAt,
  }) {
    return _transition(
      id,
      'paid',
      transactionId: transactionId,
      resolvedAt: resolvedAt,
    );
  }

  Future<void> markSkipped(String id, {required DateTime resolvedAt}) {
    return _transition(id, 'skipped', resolvedAt: resolvedAt);
  }

  Future<void> markDismissed(String id, {required DateTime resolvedAt}) {
    return _transition(id, 'dismissed', resolvedAt: resolvedAt);
  }

  Future<void> _transition(
    String id,
    String next, {
    String? transactionId,
    DateTime? resolvedAt,
  }) async {
    await _db.transaction(() async {
      final current =
          await (_db.select(_db.recurringOccurrences)
                ..where((row) => row.id.equals(id))
                ..limit(1))
              .getSingleOrNull();
      if (current == null) throw StateError('Occurrence not found');
      if (!_allowedTransitions[current.status]!.contains(next)) {
        throw StateError('Occurrence transition is not allowed');
      }
      final isResolved =
          next == 'paid' || next == 'skipped' || next == 'dismissed';
      if (isResolved && resolvedAt == null) {
        throw ArgumentError('resolvedAt is required for a resolved occurrence');
      }
      if (next == 'paid' && transactionId == null) {
        throw ArgumentError('transactionId is required for a paid occurrence');
      }
      await (_db.update(
        _db.recurringOccurrences,
      )..where((row) => row.id.equals(id))).write(
        RecurringOccurrencesCompanion(
          status: Value(next),
          transactionId: transactionId == null
              ? const Value.absent()
              : Value(transactionId),
          resolvedAt: resolvedAt == null
              ? const Value.absent()
              : Value(resolvedAt),
        ),
      );
    });
  }

  static const Map<String, Set<String>> _allowedTransitions = {
    'due': {'unpaid', 'paid', 'skipped', 'dismissed'},
    'unpaid': {'paid', 'skipped', 'dismissed'},
    'paid': {},
    'skipped': {},
    'dismissed': {},
  };
}

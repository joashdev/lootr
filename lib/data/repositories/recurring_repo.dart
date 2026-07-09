import 'package:drift/drift.dart' hide isNull;

import '../database/app_database.dart';

class RecurringRepo {
  final AppDatabase _db;

  RecurringRepo(this._db);

  Stream<List<RecurringTemplateData>> watchAll() {
    return (_db.select(
      _db.recurringTemplates,
    )..where((r) => r.deletedAt.isNull())).watch();
  }

  Stream<RecurringTemplateData?> watchById(String id) {
    return (_db.select(_db.recurringTemplates)
          ..where((r) => r.id.equals(id))
          ..limit(1))
        .watch()
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  Stream<List<RecurringTemplateData>> watchDue({DateTime? before}) {
    final q = _db.select(_db.recurringTemplates)
      ..where((r) => r.deletedAt.isNull() & r.autoCreateDisabled.equals(false));

    if (before != null) {
      q.where((r) => r.nextOccurrenceAt.isSmallerOrEqualValue(before));
    } else {
      q.where((r) => r.nextOccurrenceAt.isNotNull());
    }

    return q.watch();
  }

  Future<String> create(RecurringTemplatesCompanion r) async {
    if (!r.id.present) throw ArgumentError('id is required for create');
    await _db.into(_db.recurringTemplates).insert(r);
    return r.id.value;
  }

  Future<void> update(RecurringTemplatesCompanion r) async {
    if (!r.id.present) throw ArgumentError('id is required for update');
    final id = r.id.value;
    await (_db.update(
      _db.recurringTemplates,
    )..where((row) => row.id.equals(id))).write(r);
    await (_db.update(
      _db.recurringTemplates,
    )..where((row) => row.id.equals(id))).write(
      RecurringTemplatesCompanion(
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> advanceNextOccurrence(String id) async {
    await _db.transaction(() async {
      final template =
          await (_db.select(_db.recurringTemplates)
                ..where((t) => t.id.equals(id))
                ..limit(1))
              .getSingle();

      if (template.nextOccurrenceAt == null) return;

      final next = _computeNext(
        template.nextOccurrenceAt!,
        template.recurrenceRule,
      );
      if (next == null) return;

      await (_db.update(
        _db.recurringTemplates,
      )..where((t) => t.id.equals(id))).write(
        RecurringTemplatesCompanion(
          nextOccurrenceAt: Value(next),
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> softDelete(String id) async {
    await (_db.update(
      _db.recurringTemplates,
    )..where((row) => row.id.equals(id))).write(
      RecurringTemplatesCompanion(
        deletedAt: Value(DateTime.now()),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  DateTime? _computeNext(DateTime current, String rule) {
    switch (rule) {
      case 'daily':
        return current.add(const Duration(days: 1));
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'biweekly':
        return current.add(const Duration(days: 14));
      case 'monthly':
        final y = current.month == 12 ? current.year + 1 : current.year;
        final m = current.month == 12 ? 1 : current.month + 1;
        final d = current.day > 28 ? 28 : current.day;
        return DateTime(y, m, d);
      case 'yearly':
        return DateTime(
          current.year + 1,
          current.month,
          current.day > 28 ? 28 : current.day,
        );
      default:
        return null;
    }
  }
}

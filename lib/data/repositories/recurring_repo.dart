import 'package:drift/drift.dart' hide isNull;

import '../../core/recurring/recurrence_date.dart';
import '../../domain/value_objects/exact_money.dart';
import '../database/app_database.dart';
import 'exact_money_codec.dart';

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
    return _db.transaction(() async {
      await _db.into(_db.recurringTemplates).insert(r);
      await _normalizeExactAmount(
        r.id.value,
        preferLegacyProjection: r.amount.present && !r.amountAtoms.present,
      );
      return r.id.value;
    });
  }

  Future<void> update(RecurringTemplatesCompanion r) async {
    if (!r.id.present) throw ArgumentError('id is required for update');
    final id = r.id.value;
    await (_db.update(
      _db.recurringTemplates,
    )..where((row) => row.id.equals(id))).write(r);
    await _normalizeExactAmount(
      id,
      preferLegacyProjection: r.amount.present && !r.amountAtoms.present,
    );
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

      final next = nextRecurrenceDate(
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

  Future<void> _normalizeExactAmount(
    String id, {
    required bool preferLegacyProjection,
  }) async {
    final row =
        await (_db.select(_db.recurringTemplates)
              ..where((template) => template.id.equals(id))
              ..limit(1))
            .getSingle();
    final account =
        await (_db.select(_db.accounts)
              ..where((candidate) => candidate.id.equals(row.accountId))
              ..limit(1))
            .getSingle();
    final amount =
        !preferLegacyProjection &&
            row.amountAtoms != null &&
            row.amountScale != null &&
            row.currencyCode != null
        ? ExactMoney(
            coefficient: BigInt.parse(row.amountAtoms!),
            scale: row.amountScale!,
            currencyCode: row.currencyCode!,
          )
        : ExactMoneyCodec.fromLegacyDouble(
            row.amount,
            account.currencyCode,
            account.currencyPrecision ?? ExactMoneyCodec.legacyScale,
          );
    ExactMoneyCodec.requirePositive(amount, 'amount');
    final normalized = ExactMoneyCodec.atAccountScale(amount, account);
    await (_db.update(
      _db.recurringTemplates,
    )..where((template) => template.id.equals(id))).write(
      RecurringTemplatesCompanion(
        amount: Value(ExactMoneyCodec.legacyProjection(normalized)),
        amountAtoms: Value(normalized.coefficient.toString()),
        amountScale: Value(normalized.scale),
        currencyCode: Value(normalized.currencyCode),
      ),
    );
  }
}

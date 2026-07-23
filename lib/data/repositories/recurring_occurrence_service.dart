import 'package:drift/drift.dart';

import '../../domain/value_objects/exact_money.dart';
import '../database/app_database.dart';
import 'recurring_occurrence_repo.dart';
import 'transaction_repo.dart';

/// Coordinates ledger and occurrence changes in one database transaction.
///
/// A reminder never calls this service by itself. The user must explicitly
/// confirm Pay or Skip from the occurrence UI.
class RecurringOccurrenceService {
  RecurringOccurrenceService(
    this._db,
    this._transactionRepo,
    this._occurrenceRepo,
  );

  final AppDatabase _db;
  final TransactionRepo _transactionRepo;
  final RecurringOccurrenceRepo _occurrenceRepo;

  Future<void> ensureNextOccurrence(String templateId) {
    return _db.transaction(() async {
      final template =
          await (_db.select(_db.recurringTemplates)
                ..where((row) => row.id.equals(templateId))
                ..limit(1))
              .getSingle();
      final anchor = template.nextOccurrenceAt;
      if (anchor == null) return;
      final existing =
          await (_db.select(_db.recurringOccurrences)
                ..where(
                  (row) =>
                      row.recurringTemplateId.equals(templateId) &
                      (row.status.equals('due') | row.status.equals('unpaid')),
                )
                ..limit(1))
              .getSingleOrNull();
      if (existing != null) return;
      await _insertOccurrence(template, anchor);
      await _setTemplateNext(template.id, anchor);
    });
  }

  Future<String> pay(String occurrenceId, {DateTime? resolvedAt}) {
    return _db.transaction(() async {
      final occurrence = await _requireActionable(occurrenceId);
      final template =
          await (_db.select(_db.recurringTemplates)
                ..where((row) => row.id.equals(occurrence.recurringTemplateId))
                ..limit(1))
              .getSingle();
      final amount = ExactMoney(
        coefficient: BigInt.parse(occurrence.amountAtoms),
        scale: occurrence.amountScale,
        currencyCode: occurrence.currencyCode,
      );
      final now = resolvedAt ?? DateTime.now();
      final transactionId = 'txn-occ-${now.microsecondsSinceEpoch}';

      await _transactionRepo.create(
        TransactionsCompanion.insert(
          id: transactionId,
          accountId: template.accountId,
          categoryId: Value(template.categoryId),
          payeeId: Value(template.payeeId),
          recurringTemplateId: Value(template.id),
          amount: amount.toDouble(),
          amountAtoms: Value(amount.coefficient.toString()),
          amountScale: Value(amount.scale),
          currencyCode: Value(amount.currencyCode),
          title: const Value('Recurring payment'),
          transactionDirection: template.transactionDirection ?? 'expense',
          transactionMode: 'recurring',
          occurredAt: occurrence.dueAt,
        ),
      );
      await _occurrenceRepo.markPaid(
        occurrence.id,
        transactionId: transactionId,
        resolvedAt: now,
      );
      await _refreshNextOccurrence(template, occurrence.dueAt);
      return transactionId;
    });
  }

  Future<void> skip(String occurrenceId, {DateTime? resolvedAt}) {
    return _db.transaction(() async {
      final occurrence = await _requireActionable(occurrenceId);
      final template =
          await (_db.select(_db.recurringTemplates)
                ..where((row) => row.id.equals(occurrence.recurringTemplateId))
                ..limit(1))
              .getSingle();
      await _occurrenceRepo.markSkipped(
        occurrence.id,
        resolvedAt: resolvedAt ?? DateTime.now(),
      );
      await _refreshNextOccurrence(template, occurrence.dueAt);
    });
  }

  Future<RecurringOccurrenceData> _requireActionable(String id) async {
    final occurrence =
        await (_db.select(_db.recurringOccurrences)
              ..where((row) => row.id.equals(id))
              ..limit(1))
            .getSingleOrNull();
    if (occurrence == null) throw StateError('Occurrence not found');
    if (occurrence.status != 'due' && occurrence.status != 'unpaid') {
      throw StateError('Occurrence is already resolved');
    }
    return occurrence;
  }

  Future<void> _refreshNextOccurrence(
    RecurringTemplateData template,
    DateTime resolvedDueAt,
  ) async {
    final unresolved =
        await (_db.select(_db.recurringOccurrences)
              ..where(
                (row) =>
                    row.recurringTemplateId.equals(template.id) &
                    (row.status.equals('due') | row.status.equals('unpaid')),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.dueAt)])
              ..limit(1))
            .getSingleOrNull();
    if (unresolved != null) {
      await _setTemplateNext(template.id, unresolved.dueAt);
      return;
    }

    final nextDue = _nextDue(resolvedDueAt, template.recurrenceRule);
    if (nextDue == null) {
      await _setTemplateNext(template.id, null);
      return;
    }
    await _insertOccurrence(template, nextDue);
    await _setTemplateNext(template.id, nextDue);
  }

  Future<void> _insertOccurrence(
    RecurringTemplateData template,
    DateTime nextDue,
  ) async {
    final amountAtoms =
        template.amountAtoms ??
        BigInt.from(
          (template.amount * _pow10(template.amountScale ?? 2)).round(),
        ).toString();
    final amountScale = template.amountScale ?? 2;
    final currencyCode = template.currencyCode ?? 'PHP';
    final occurrenceId = 'occ-${template.id}-${nextDue.microsecondsSinceEpoch}';
    await _db
        .into(_db.recurringOccurrences)
        .insert(
          RecurringOccurrencesCompanion.insert(
            id: occurrenceId,
            recurringTemplateId: template.id,
            status: 'due',
            originalDueAt: nextDue,
            dueAt: nextDue,
            amountAtoms: amountAtoms,
            amountScale: amountScale,
            currencyCode: currencyCode,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> _setTemplateNext(String templateId, DateTime? next) {
    return (_db.update(
      _db.recurringTemplates,
    )..where((row) => row.id.equals(templateId))).write(
      RecurringTemplatesCompanion(
        nextOccurrenceAt: Value(next),
        updatedAt: Value(DateTime.now()),
        syncStatus: const Value('pending_sync'),
      ),
    );
  }

  DateTime? _nextDue(DateTime current, String rule) {
    return switch (rule) {
      'daily' => current.add(const Duration(days: 1)),
      'weekly' => current.add(const Duration(days: 7)),
      'biweekly' => current.add(const Duration(days: 14)),
      'monthly' => DateTime(
        current.month == 12 ? current.year + 1 : current.year,
        current.month == 12 ? 1 : current.month + 1,
        current.day > 28 ? 28 : current.day,
        current.hour,
        current.minute,
      ),
      'quarterly' => DateTime(
        current.year + ((current.month + 2) ~/ 12),
        ((current.month + 2) % 12) + 1,
        current.day > 28 ? 28 : current.day,
        current.hour,
        current.minute,
      ),
      'yearly' => DateTime(
        current.year + 1,
        current.month,
        current.day > 28 ? 28 : current.day,
        current.hour,
        current.minute,
      ),
      _ => null,
    };
  }

  int _pow10(int scale) {
    var result = 1;
    for (var index = 0; index < scale; index++) {
      result *= 10;
    }
    return result;
  }
}

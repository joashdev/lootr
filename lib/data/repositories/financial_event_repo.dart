import 'package:drift/drift.dart';

import '../../domain/value_objects/exact_money.dart';
import '../database/app_database.dart';

class ExactEventSummary {
  const ExactEventSummary(this.netByCurrency);

  final Map<String, ExactMoney> netByCurrency;
}

/// Append-only goal contribution events.
class GoalContributionEventRepo {
  GoalContributionEventRepo(this._db);

  final AppDatabase _db;

  Future<String> append(GoalContributionEventsCompanion event) async {
    if (!event.id.present) throw ArgumentError('id is required');
    await _db.into(_db.goalContributionEvents).insert(event);
    return event.id.value;
  }

  Stream<List<GoalContributionEventData>> watchForGoal(String goalId) {
    return (_db.select(_db.goalContributionEvents)
          ..where((row) => row.goalId.equals(goalId))
          ..orderBy([(row) => OrderingTerm.asc(row.occurredAt)]))
        .watch();
  }

  Future<ExactEventSummary> summarize(String goalId) async {
    final rows = await (_db.select(
      _db.goalContributionEvents,
    )..where((row) => row.goalId.equals(goalId))).get();
    return ExactEventSummary(
      _aggregate(
        rows.map(
          (row) => (
            eventType: row.eventType,
            amountAtoms: row.amountAtoms,
            amountScale: row.amountScale,
            currencyCode: row.currencyCode,
          ),
        ),
        positiveType: 'contribution',
        negativeType: 'withdrawal',
      ),
    );
  }
}

/// Append-only debt and loan payment events.
class DebtPaymentEventRepo {
  DebtPaymentEventRepo(this._db);

  final AppDatabase _db;

  Future<String> append(DebtPaymentEventsCompanion event) async {
    if (!event.id.present) throw ArgumentError('id is required');
    await _db.into(_db.debtPaymentEvents).insert(event);
    return event.id.value;
  }

  Stream<List<DebtPaymentEventData>> watchForDebt(String debtRecordId) {
    return (_db.select(_db.debtPaymentEvents)
          ..where((row) => row.debtRecordId.equals(debtRecordId))
          ..orderBy([(row) => OrderingTerm.asc(row.occurredAt)]))
        .watch();
  }

  Future<ExactEventSummary> summarize(String debtRecordId) async {
    final rows = await (_db.select(
      _db.debtPaymentEvents,
    )..where((row) => row.debtRecordId.equals(debtRecordId))).get();
    return ExactEventSummary(
      _aggregate(
        rows.map(
          (row) => (
            eventType: row.eventType,
            amountAtoms: row.amountAtoms,
            amountScale: row.amountScale,
            currencyCode: row.currencyCode,
          ),
        ),
        positiveType: 'payment',
        negativeType: 'refund',
      ),
    );
  }
}

Map<String, ExactMoney> _aggregate(
  Iterable<
    ({
      String eventType,
      String amountAtoms,
      int amountScale,
      String currencyCode,
    })
  >
  events, {
  required String positiveType,
  required String negativeType,
}) {
  final totals = <String, ExactMoney>{};
  for (final event in events) {
    var amount = ExactMoney(
      coefficient: BigInt.parse(event.amountAtoms),
      scale: event.amountScale,
      currencyCode: event.currencyCode,
    );
    if (event.eventType == positiveType) {
      amount = amount.abs();
    } else if (event.eventType == negativeType) {
      amount = -amount.abs();
    }
    totals.update(
      event.currencyCode,
      (current) => current + amount,
      ifAbsent: () => amount,
    );
  }
  return Map.unmodifiable(totals);
}

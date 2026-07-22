import 'package:drift/drift.dart' hide isNull;

import '../../domain/value_objects/exact_money.dart';
import '../database/app_database.dart';
import 'exact_money_codec.dart';
import 'transaction_repo.dart';

class GoalRepo {
  final AppDatabase _db;

  GoalRepo(this._db);

  Stream<List<GoalData>> watchAll() {
    return (_db.select(_db.goals)..where((g) => g.deletedAt.isNull())).watch();
  }

  Stream<GoalData?> watchById(String id) {
    return (_db.select(_db.goals)
          ..where((g) => g.id.equals(id))
          ..limit(1))
        .watch()
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  Future<String> create(GoalsCompanion g) async {
    if (!g.id.present) throw ArgumentError('id is required for create');
    await _db.into(_db.goals).insert(g);
    return g.id.value;
  }

  Future<void> update(GoalsCompanion g) async {
    if (!g.id.present) throw ArgumentError('id is required for update');
    final id = g.id.value;
    await (_db.update(_db.goals)..where((row) => row.id.equals(id))).write(g);
    await (_db.update(_db.goals)..where((row) => row.id.equals(id))).write(
      GoalsCompanion(
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> addContribution(String id, double amount) async {
    final goal =
        await (_db.select(_db.goals)
              ..where((row) => row.id.equals(id))
              ..limit(1))
            .getSingleOrNull();
    if (goal == null) throw StateError('Goal not found: $id');
    final scale = goal.amountScale ?? 2;
    final currency = goal.currencyCode ?? 'PHP';
    await addContributionExact(
      id,
      ExactMoney.parse(
        amount.toString(),
        currency,
      ).rescale(scale, rounding: MoneyRoundingMode.halfEven),
    );
  }

  Future<void> addContributionExact(
    String id,
    ExactMoney amount, {
    TransactionsCompanion? transaction,
  }) async {
    await _db.transaction(() async {
      final goal =
          await (_db.select(_db.goals)
                ..where((g) => g.id.equals(id))
                ..limit(1))
              .getSingleOrNull();
      if (goal == null) throw StateError('Goal not found: $id');
      final scale = goal.amountScale ?? 2;
      final currency = goal.currencyCode ?? 'PHP';
      if (amount.currencyCode != currency) {
        throw ArgumentError('Contribution currency does not match the goal');
      }
      final contribution = amount.rescale(scale).abs();
      final current = goal.currentAmountAtoms == null
          ? ExactMoney.parse(
              goal.currentAmount.toString(),
              currency,
            ).rescale(scale, rounding: MoneyRoundingMode.halfEven)
          : ExactMoney(
              coefficient: BigInt.parse(goal.currentAmountAtoms!),
              scale: scale,
              currencyCode: currency,
            );
      final updated = current + contribution;
      final now = DateTime.now();
      final transactionId = transaction == null
          ? null
          : await TransactionRepo(_db).create(transaction);

      await _db
          .into(_db.goalContributionEvents)
          .insert(
            GoalContributionEventsCompanion.insert(
              id: 'goal-event-${now.microsecondsSinceEpoch}',
              goalId: id,
              transactionId: Value(transactionId),
              amountAtoms: contribution.coefficient.toString(),
              amountScale: contribution.scale,
              currencyCode: contribution.currencyCode,
              occurredAt: now,
            ),
          );

      await (_db.update(_db.goals)..where((g) => g.id.equals(id))).write(
        GoalsCompanion(
          currentAmount: Value(ExactMoneyCodec.legacyProjection(updated)),
          currentAmountAtoms: Value(updated.coefficient.toString()),
          amountScale: Value(scale),
          currencyCode: Value(currency),
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(now),
        ),
      );
    });
  }
}

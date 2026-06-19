import 'package:drift/drift.dart' hide isNull;

import '../database/app_database.dart';

class BudgetRepo {
  final AppDatabase _db;

  BudgetRepo(this._db);

  Stream<List<BudgetData>> watchAll({int? month, int? year}) {
    final q = _db.select(_db.budgets)
      ..where((b) => b.deletedAt.isNull());

    if (month != null) q.where((b) => b.month.equals(month));
    if (year != null) q.where((b) => b.year.equals(year));

    return q.watch();
  }

  Stream<BudgetData?> watchById(String id) {
    return (_db.select(_db.budgets)
          ..where((b) => b.id.equals(id))
          ..limit(1))
        .watch()
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  Stream<double> watchSpentForBudget(String budgetId) {
    return (_db.select(_db.budgets)
          ..where((b) => b.id.equals(budgetId))
          ..limit(1))
        .watch()
        .asyncExpand((budgets) {
      if (budgets.isEmpty) return Stream.value(0.0);
      final budget = budgets.first;

      final startOfMonth = DateTime(budget.year, budget.month);
      final endOfMonth = budget.month == 12
          ? DateTime(budget.year + 1, 1)
          : DateTime(budget.year, budget.month + 1);

      return (_db.select(_db.transactions)
            ..where((t) =>
                t.categoryId.equals(budget.categoryId) &
                t.occurredAt.isBiggerOrEqualValue(startOfMonth) &
                t.occurredAt.isSmallerThanValue(endOfMonth) &
                t.deletedAt.isNull() &
                t.transactionDirection.equals('expense')))
          .watch()
          .map((txns) => txns.fold<double>(0, (sum, t) => sum + t.amount));
    });
  }

  Future<String> create(BudgetsCompanion b) async {
    if (!b.id.present) throw ArgumentError('id is required for create');
    await _db.into(_db.budgets).insert(b);
    return b.id.value;
  }

  Future<void> update(BudgetsCompanion b) async {
    if (!b.id.present) throw ArgumentError('id is required for update');
    final id = b.id.value;
    await (_db.update(_db.budgets)..where((row) => row.id.equals(id)))
        .write(b);
    await (_db.update(_db.budgets)..where((row) => row.id.equals(id)))
        .write(BudgetsCompanion(
      syncStatus: const Value('pending_sync'),
    ));
  }

  Future<void> softDelete(String id) async {
    final now = DateTime.now();
    await (_db.update(_db.budgets)..where((b) => b.id.equals(id)))
        .write(BudgetsCompanion(
      deletedAt: Value(now),
      syncStatus: const Value('pending_sync'),
    ));
  }
}

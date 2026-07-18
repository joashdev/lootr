import 'package:drift/drift.dart' hide isNull;
import 'package:rxdart/rxdart.dart';

import '../../domain/value_objects/exact_money.dart';
import '../database/app_database.dart';
import 'exact_money_codec.dart';

class BudgetRepo {
  final AppDatabase _db;

  BudgetRepo(this._db);

  Stream<List<BudgetData>> watchAll({int? month, int? year}) {
    final q = _db.select(_db.budgets)..where((b) => b.deletedAt.isNull());

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
    return watchExactSpentForBudget(
      budgetId,
    ).map(ExactMoneyCodec.legacyProjection);
  }

  Stream<ExactMoney> watchExactSpentForBudget(String budgetId) {
    return (_db.select(_db.budgets)
          ..where((b) => b.id.equals(budgetId))
          ..limit(1))
        .watch()
        .asyncExpand((budgets) {
          if (budgets.isEmpty) {
            return Stream.value(
              ExactMoney(
                coefficient: BigInt.zero,
                scale: ExactMoneyCodec.legacyScale,
                currencyCode: 'PHP',
              ),
            );
          }
          final budget = budgets.first;

          final startOfMonth = DateTime(budget.year, budget.month);
          final endOfMonth = budget.month == 12
              ? DateTime(budget.year + 1, 1)
              : DateTime(budget.year, budget.month + 1);

          final transactions =
              (_db.select(_db.transactions)..where(
                    (t) =>
                        t.categoryId.equals(budget.categoryId) &
                        t.occurredAt.isBiggerOrEqualValue(startOfMonth) &
                        t.occurredAt.isSmallerThanValue(endOfMonth) &
                        t.deletedAt.isNull() &
                        t.transactionDirection.equals('expense'),
                  ))
                  .watch();
          final accounts = (_db.select(
            _db.accounts,
          )..where((account) => account.deletedAt.isNull())).watch();
          return Rx.combineLatest2<
            List<TransactionData>,
            List<AccountData>,
            ExactMoney
          >(transactions, accounts, (txns, accountRows) {
            final accountById = {
              for (final account in accountRows) account.id: account,
            };
            final resolved = <({TransactionData row, ExactMoney amount})>[];
            for (final transaction in txns) {
              final account = accountById[transaction.accountId];
              if (account == null) continue;
              resolved.add((
                row: transaction,
                amount: ExactMoneyCodec.transactionAmount(transaction, account),
              ));
            }
            final currencies = resolved
                .map((entry) => entry.amount.currencyCode)
                .toSet();
            if (budget.currencyCode == null && currencies.length > 1) {
              throw StateError(
                'Budget spans currencies without an explicit currency',
              );
            }
            final currency =
                budget.currencyCode ??
                (currencies.isEmpty ? 'PHP' : currencies.single);
            var total = ExactMoney(
              coefficient: BigInt.zero,
              scale: budget.amountScale ?? ExactMoneyCodec.legacyScale,
              currencyCode: currency,
            );
            for (final entry in resolved) {
              if (entry.amount.currencyCode == currency) {
                total += entry.amount;
              }
            }
            return total;
          });
        });
  }

  Future<String> create(BudgetsCompanion b) async {
    if (!b.id.present) throw ArgumentError('id is required for create');
    return _db.transaction(() async {
      await _db.into(_db.budgets).insert(b);
      await _normalizeExactAmount(
        b.id.value,
        preferLegacyProjection: b.amount.present && !b.amountAtoms.present,
      );
      return b.id.value;
    });
  }

  Future<void> update(BudgetsCompanion b) async {
    if (!b.id.present) throw ArgumentError('id is required for update');
    final id = b.id.value;
    await (_db.update(_db.budgets)..where((row) => row.id.equals(id))).write(b);
    await _normalizeExactAmount(
      id,
      preferLegacyProjection: b.amount.present && !b.amountAtoms.present,
    );
    await (_db.update(_db.budgets)..where((row) => row.id.equals(id))).write(
      BudgetsCompanion(
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> softDelete(String id) async {
    final now = DateTime.now();
    await (_db.update(_db.budgets)..where((b) => b.id.equals(id))).write(
      BudgetsCompanion(
        deletedAt: Value(now),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> _normalizeExactAmount(
    String id, {
    required bool preferLegacyProjection,
  }) async {
    final row =
        await (_db.select(_db.budgets)
              ..where((budget) => budget.id.equals(id))
              ..limit(1))
            .getSingle();
    final exact =
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
            row.currencyCode ?? 'PHP',
            row.amountScale ?? ExactMoneyCodec.legacyScale,
          );
    ExactMoneyCodec.requirePositive(exact, 'amount');
    await (_db.update(
      _db.budgets,
    )..where((budget) => budget.id.equals(id))).write(
      BudgetsCompanion(
        amount: Value(ExactMoneyCodec.legacyProjection(exact)),
        amountAtoms: Value(exact.coefficient.toString()),
        amountScale: Value(exact.scale),
        currencyCode: Value(exact.currencyCode),
      ),
    );
  }
}

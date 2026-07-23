import 'package:drift/drift.dart' hide isNull;
import 'package:rxdart/rxdart.dart';

import '../database/app_database.dart';
import '../../domain/value_objects/exact_money.dart';
import 'exact_money_codec.dart';

class TransactionRepoFilters {
  final String? accountId;
  final String? categoryId;
  final String? payeeId;
  final String? direction;
  final String? mode;
  final String? payeeIdFilter;
  final String? currencyCode;
  final String? minAmountCoefficient;
  final int? minAmountScale;
  final String? maxAmountCoefficient;
  final int? maxAmountScale;
  final DateTime? from;
  final DateTime? to;

  const TransactionRepoFilters({
    this.accountId,
    this.categoryId,
    this.payeeId,
    this.direction,
    this.mode,
    this.payeeIdFilter,
    this.currencyCode,
    this.minAmountCoefficient,
    this.minAmountScale,
    this.maxAmountCoefficient,
    this.maxAmountScale,
    this.from,
    this.to,
  }) : assert(
         (minAmountCoefficient == null) == (minAmountScale == null),
         'minAmountCoefficient and minAmountScale must be set together',
       ),
       assert(
         (maxAmountCoefficient == null) == (maxAmountScale == null),
         'maxAmountCoefficient and maxAmountScale must be set together',
       ),
       assert(
         currencyCode != null ||
             (minAmountCoefficient == null && maxAmountCoefficient == null),
         'Exact amount bounds require an explicit currencyCode',
       );
}

enum TransactionBulkOperation { recategorize, moveAccount, delete }

class TransactionBulkRequest {
  const TransactionBulkRequest({
    required this.transactionIds,
    required this.operation,
    this.targetId,
  });

  final Set<String> transactionIds;
  final TransactionBulkOperation operation;
  final String? targetId;
}

class TransactionBulkIssue {
  const TransactionBulkIssue(this.transactionId, this.message);

  final String transactionId;
  final String message;
}

class TransactionBulkPlan {
  const TransactionBulkPlan({
    required this.request,
    required this.transactionIds,
    required this.issues,
  });

  final TransactionBulkRequest request;
  final List<String> transactionIds;
  final List<TransactionBulkIssue> issues;

  bool get canApply => transactionIds.isNotEmpty && issues.isEmpty;
}

class TransactionBulkUndo {
  const TransactionBulkUndo({
    required this.transactionIds,
    required this.rollback,
  });

  final List<String> transactionIds;
  final Future<void> Function() rollback;
}

class TransactionBulkPreflightException implements Exception {
  const TransactionBulkPreflightException(this.issues);

  final List<TransactionBulkIssue> issues;

  @override
  String toString() => issues.map((issue) => issue.message).toSet().join('\n');
}

class _TransactionBulkSnapshot {
  const _TransactionBulkSnapshot({
    required this.id,
    required this.accountId,
    required this.categoryId,
    required this.deletedAt,
  });

  final String id;
  final String accountId;
  final String? categoryId;
  final DateTime? deletedAt;
}

class TransactionRepo {
  final AppDatabase _db;

  TransactionRepo(this._db);

  Stream<List<TransactionData>> watchFiltered(TransactionRepoFilters filters) {
    final q = _db.select(_db.transactions)..where((t) => t.deletedAt.isNull());

    if (filters.accountId != null) {
      q.where((t) => t.accountId.equals(filters.accountId!));
    }
    if (filters.categoryId != null) {
      q.where((t) => t.categoryId.equals(filters.categoryId!));
    }
    if (filters.payeeId != null) {
      q.where((t) => t.payeeId.equals(filters.payeeId!));
    }
    if (filters.direction != null) {
      q.where((t) => t.transactionDirection.equals(filters.direction!));
    }
    if (filters.mode != null) {
      q.where((t) => t.transactionMode.equals(filters.mode!));
    }
    if (filters.payeeIdFilter != null) {
      q.where((t) => t.payeeId.equals(filters.payeeIdFilter!));
    }
    if (filters.from != null) {
      q.where((t) => t.occurredAt.isBiggerOrEqualValue(filters.from!));
    }
    if (filters.to != null) {
      q.where((t) => t.occurredAt.isSmallerOrEqualValue(filters.to!));
    }

    final rows = q.watch();
    if (filters.currencyCode == null &&
        filters.minAmountCoefficient == null &&
        filters.maxAmountCoefficient == null) {
      return rows;
    }

    final accounts = _db.select(_db.accounts).watch();
    return Rx.combineLatest2<
      List<TransactionData>,
      List<AccountData>,
      List<TransactionData>
    >(rows, accounts, (transactions, accountRows) {
      final accountsById = {
        for (final account in accountRows) account.id: account,
      };
      final minimum = filters.minAmountCoefficient == null
          ? null
          : ExactMoney(
              coefficient: BigInt.parse(filters.minAmountCoefficient!),
              scale: filters.minAmountScale!,
              currencyCode: filters.currencyCode!,
            );
      final maximum = filters.maxAmountCoefficient == null
          ? null
          : ExactMoney(
              coefficient: BigInt.parse(filters.maxAmountCoefficient!),
              scale: filters.maxAmountScale!,
              currencyCode: filters.currencyCode!,
            );

      return transactions.where((transaction) {
        final account = accountsById[transaction.accountId];
        if (account == null) return false;
        final amount = ExactMoneyCodec.transactionAmount(transaction, account);
        if (filters.currencyCode != null &&
            amount.currencyCode != filters.currencyCode) {
          return false;
        }
        if (minimum != null && amount.compareTo(minimum) < 0) return false;
        if (maximum != null && amount.compareTo(maximum) > 0) return false;
        return true;
      }).toList();
    });
  }

  Stream<TransactionData?> watchById(String id) {
    return (_db.select(_db.transactions)
          ..where((t) => t.id.equals(id))
          ..limit(1))
        .watch()
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  Stream<List<TransactionData>> watchByAccount(String accountId) {
    return (_db.select(_db.transactions)
          ..where((t) => t.accountId.equals(accountId) & t.deletedAt.isNull()))
        .watch();
  }

  Future<String> create(TransactionsCompanion tx) async {
    if (!tx.id.present) throw ArgumentError('id is required for create');
    final txId = tx.id.value;

    await _db.transaction(() async {
      await _db.into(_db.transactions).insert(tx);

      final row =
          await (_db.select(_db.transactions)
                ..where((t) => t.id.equals(txId))
                ..limit(1))
              .getSingle();

      final account =
          await (_db.select(_db.accounts)
                ..where((a) => a.id.equals(row.accountId))
                ..limit(1))
              .getSingle();
      final amount = ExactMoneyCodec.transactionAmount(row, account);
      ExactMoneyCodec.requirePositive(amount, 'amount');
      await _normalizeExactColumns(row.id, amount);
      await _applyAccountImpact(
        account,
        _signedImpact(amount, row.transactionDirection),
      );

      if (row.recurringTemplateId != null) {
        await _advanceNextOccurrence(row.recurringTemplateId!);
      }
    });

    return txId;
  }

  Future<void> update(TransactionsCompanion tx) async {
    if (!tx.id.present) throw ArgumentError('id is required for update');
    final id = tx.id.value;

    await _db.transaction(() async {
      final old =
          await (_db.select(_db.transactions)
                ..where((t) => t.id.equals(id))
                ..limit(1))
              .getSingle();

      final oldAccount =
          await (_db.select(_db.accounts)
                ..where((a) => a.id.equals(old.accountId))
                ..limit(1))
              .getSingle();
      final oldAmount = ExactMoneyCodec.transactionAmount(old, oldAccount);
      await _applyAccountImpact(
        oldAccount,
        -_signedImpact(oldAmount, old.transactionDirection),
      );

      await (_db.update(
        _db.transactions,
      )..where((t) => t.id.equals(id))).write(tx);

      await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final updated =
          await (_db.select(_db.transactions)
                ..where((t) => t.id.equals(id))
                ..limit(1))
              .getSingle();

      final newAccount =
          await (_db.select(_db.accounts)
                ..where((a) => a.id.equals(updated.accountId))
                ..limit(1))
              .getSingle();
      final preferLegacyProjection =
          tx.amount.present &&
          !tx.amountAtoms.present &&
          !tx.amountScale.present &&
          !tx.currencyCode.present;
      final newAmount = ExactMoneyCodec.transactionAmount(
        updated,
        newAccount,
        preferLegacyProjection: preferLegacyProjection,
      );
      ExactMoneyCodec.requirePositive(newAmount, 'amount');
      await _normalizeExactColumns(updated.id, newAmount);
      await _applyAccountImpact(
        newAccount,
        _signedImpact(newAmount, updated.transactionDirection),
      );
    });
  }

  Future<void> softDelete(String id) async {
    await _db.transaction(() async {
      final rows =
          await (_db.select(_db.transactions)
                ..where((t) => t.id.equals(id) & t.deletedAt.isNull())
                ..limit(1))
              .get();
      if (rows.isEmpty) return;
      final txn = rows.first;

      final account =
          await (_db.select(_db.accounts)
                ..where((a) => a.id.equals(txn.accountId))
                ..limit(1))
              .getSingle();
      final amount = ExactMoneyCodec.transactionAmount(txn, account);
      await _applyAccountImpact(
        account,
        -_signedImpact(amount, txn.transactionDirection),
      );

      final now = DateTime.now();
      await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          deletedAt: Value(now),
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(now),
        ),
      );
    });
  }

  /// Reverses [softDelete]: clears the tombstone on the original row and
  /// re-applies the balance impact. Used by undo so the transaction keeps
  /// its id (sync-friendly — the same row flips back to pending_sync).
  Future<void> restore(String id) async {
    await _db.transaction(() async {
      final rows =
          await (_db.select(_db.transactions)
                ..where((t) => t.id.equals(id) & t.deletedAt.isNotNull())
                ..limit(1))
              .get();
      if (rows.isEmpty) return;
      final txn = rows.first;

      final account =
          await (_db.select(_db.accounts)
                ..where((a) => a.id.equals(txn.accountId))
                ..limit(1))
              .getSingle();
      final amount = ExactMoneyCodec.transactionAmount(txn, account);
      await _applyAccountImpact(
        account,
        _signedImpact(amount, txn.transactionDirection),
      );

      await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          deletedAt: const Value(null),
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<TransactionBulkPlan> preflightBulk(
    TransactionBulkRequest request,
  ) async {
    final ids = request.transactionIds.toSet().toList()..sort();
    final issues = <TransactionBulkIssue>[];
    if (ids.isEmpty) {
      issues.add(const TransactionBulkIssue('', 'Select at least one item.'));
      return TransactionBulkPlan(
        request: request,
        transactionIds: ids,
        issues: issues,
      );
    }

    final rows = await (_db.select(
      _db.transactions,
    )..where((row) => row.id.isIn(ids) & row.deletedAt.isNull())).get();
    final rowsById = {for (final row in rows) row.id: row};
    for (final id in ids) {
      if (!rowsById.containsKey(id)) {
        issues.add(
          TransactionBulkIssue(
            id,
            '“$id” is unavailable or is not a ledger transaction.',
          ),
        );
      }
    }

    switch (request.operation) {
      case TransactionBulkOperation.recategorize:
        final targetId = request.targetId;
        if (targetId == null) {
          issues.add(
            const TransactionBulkIssue('', 'Choose a target category.'),
          );
          break;
        }
        final category =
            await (_db.select(_db.categories)
                  ..where(
                    (row) => row.id.equals(targetId) & row.deletedAt.isNull(),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (category == null || category.isArchived == true) {
          issues.add(
            const TransactionBulkIssue(
              '',
              'The target category is unavailable.',
            ),
          );
          break;
        }
        for (final row in rows) {
          final requiredGroup = row.transactionDirection == 'income'
              ? 'income'
              : 'expense';
          if (category.categoryGroup != requiredGroup) {
            issues.add(
              TransactionBulkIssue(
                row.id,
                '“${row.id}” needs a $requiredGroup category.',
              ),
            );
          }
        }
      case TransactionBulkOperation.moveAccount:
        final targetId = request.targetId;
        if (targetId == null) {
          issues.add(
            const TransactionBulkIssue('', 'Choose a target account.'),
          );
          break;
        }
        final target =
            await (_db.select(_db.accounts)
                  ..where(
                    (row) => row.id.equals(targetId) & row.deletedAt.isNull(),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (target == null || target.isArchived) {
          issues.add(
            const TransactionBulkIssue(
              '',
              'The target account is unavailable.',
            ),
          );
          break;
        }
        final sourceIds = rows.map((row) => row.accountId).toSet().toList();
        final sources = sourceIds.isEmpty
            ? const <AccountData>[]
            : await (_db.select(
                _db.accounts,
              )..where((row) => row.id.isIn(sourceIds))).get();
        final sourcesById = {for (final source in sources) source.id: source};
        for (final row in rows) {
          final source = sourcesById[row.accountId];
          if (source == null) {
            issues.add(
              TransactionBulkIssue(row.id, 'Its current account is missing.'),
            );
            continue;
          }
          if (source.currencyCode != target.currencyCode) {
            issues.add(
              TransactionBulkIssue(
                row.id,
                'It uses ${source.currencyCode}; ${target.name} uses '
                '${target.currencyCode}.',
              ),
            );
            continue;
          }
          try {
            ExactMoneyCodec.atAccountScale(
              ExactMoneyCodec.transactionAmount(row, source),
              target,
            );
          } on StateError {
            issues.add(
              TransactionBulkIssue(
                row.id,
                'Its amount cannot be represented by ${target.name}.',
              ),
            );
          }
        }
      case TransactionBulkOperation.delete:
        break;
    }

    return TransactionBulkPlan(
      request: request,
      transactionIds: ids,
      issues: issues,
    );
  }

  Future<TransactionBulkUndo> applyBulk(TransactionBulkPlan plan) async {
    final verified = await preflightBulk(plan.request);
    if (!verified.canApply) {
      throw TransactionBulkPreflightException(verified.issues);
    }

    final snapshots = <_TransactionBulkSnapshot>[];
    await _db.transaction(() async {
      for (final id in verified.transactionIds) {
        final row =
            await (_db.select(_db.transactions)
                  ..where(
                    (item) => item.id.equals(id) & item.deletedAt.isNull(),
                  )
                  ..limit(1))
                .getSingle();
        snapshots.add(
          _TransactionBulkSnapshot(
            id: row.id,
            accountId: row.accountId,
            categoryId: row.categoryId,
            deletedAt: row.deletedAt,
          ),
        );
        await _applyBulkRow(row, verified.request);
      }
    });

    return TransactionBulkUndo(
      transactionIds: verified.transactionIds,
      rollback: () => _rollbackBulk(snapshots, verified.request),
    );
  }

  Future<void> _applyBulkRow(
    TransactionData row,
    TransactionBulkRequest request,
  ) async {
    final now = DateTime.now();
    switch (request.operation) {
      case TransactionBulkOperation.recategorize:
        await (_db.update(
          _db.transactions,
        )..where((item) => item.id.equals(row.id))).write(
          TransactionsCompanion(
            categoryId: Value(request.targetId),
            syncStatus: const Value('pending_sync'),
            updatedAt: Value(now),
          ),
        );
      case TransactionBulkOperation.moveAccount:
        final oldAccount =
            await (_db.select(_db.accounts)
                  ..where((item) => item.id.equals(row.accountId))
                  ..limit(1))
                .getSingle();
        final newAccount =
            await (_db.select(_db.accounts)
                  ..where((item) => item.id.equals(request.targetId!))
                  ..limit(1))
                .getSingle();
        final amount = ExactMoneyCodec.transactionAmount(row, oldAccount);
        await _applyAccountImpact(
          oldAccount,
          -_signedImpact(amount, row.transactionDirection),
        );
        final refreshedNewAccount =
            await (_db.select(_db.accounts)
                  ..where((item) => item.id.equals(newAccount.id))
                  ..limit(1))
                .getSingle();
        await _applyAccountImpact(
          refreshedNewAccount,
          _signedImpact(amount, row.transactionDirection),
        );
        await (_db.update(
          _db.transactions,
        )..where((item) => item.id.equals(row.id))).write(
          TransactionsCompanion(
            accountId: Value(newAccount.id),
            syncStatus: const Value('pending_sync'),
            updatedAt: Value(now),
          ),
        );
      case TransactionBulkOperation.delete:
        final account =
            await (_db.select(_db.accounts)
                  ..where((item) => item.id.equals(row.accountId))
                  ..limit(1))
                .getSingle();
        final amount = ExactMoneyCodec.transactionAmount(row, account);
        await _applyAccountImpact(
          account,
          -_signedImpact(amount, row.transactionDirection),
        );
        await (_db.update(
          _db.transactions,
        )..where((item) => item.id.equals(row.id))).write(
          TransactionsCompanion(
            deletedAt: Value(now),
            syncStatus: const Value('pending_sync'),
            updatedAt: Value(now),
          ),
        );
    }
  }

  Future<void> _rollbackBulk(
    List<_TransactionBulkSnapshot> snapshots,
    TransactionBulkRequest request,
  ) async {
    await _db.transaction(() async {
      for (final snapshot in snapshots) {
        final current =
            await (_db.select(_db.transactions)
                  ..where((row) => row.id.equals(snapshot.id))
                  ..limit(1))
                .getSingle();
        final now = DateTime.now();
        switch (request.operation) {
          case TransactionBulkOperation.recategorize:
            await (_db.update(
              _db.transactions,
            )..where((row) => row.id.equals(snapshot.id))).write(
              TransactionsCompanion(
                categoryId: Value(snapshot.categoryId),
                syncStatus: const Value('pending_sync'),
                updatedAt: Value(now),
              ),
            );
          case TransactionBulkOperation.moveAccount:
            final currentAccount =
                await (_db.select(_db.accounts)
                      ..where((row) => row.id.equals(current.accountId))
                      ..limit(1))
                    .getSingle();
            final originalAccount =
                await (_db.select(_db.accounts)
                      ..where((row) => row.id.equals(snapshot.accountId))
                      ..limit(1))
                    .getSingle();
            final amount = ExactMoneyCodec.transactionAmount(
              current,
              currentAccount,
            );
            await _applyAccountImpact(
              currentAccount,
              -_signedImpact(amount, current.transactionDirection),
            );
            final refreshedOriginal =
                await (_db.select(_db.accounts)
                      ..where((row) => row.id.equals(originalAccount.id))
                      ..limit(1))
                    .getSingle();
            await _applyAccountImpact(
              refreshedOriginal,
              _signedImpact(amount, current.transactionDirection),
            );
            await (_db.update(
              _db.transactions,
            )..where((row) => row.id.equals(snapshot.id))).write(
              TransactionsCompanion(
                accountId: Value(snapshot.accountId),
                syncStatus: const Value('pending_sync'),
                updatedAt: Value(now),
              ),
            );
          case TransactionBulkOperation.delete:
            final account =
                await (_db.select(_db.accounts)
                      ..where((row) => row.id.equals(snapshot.accountId))
                      ..limit(1))
                    .getSingle();
            final amount = ExactMoneyCodec.transactionAmount(current, account);
            await _applyAccountImpact(
              account,
              _signedImpact(amount, current.transactionDirection),
            );
            await (_db.update(
              _db.transactions,
            )..where((row) => row.id.equals(snapshot.id))).write(
              TransactionsCompanion(
                deletedAt: Value(snapshot.deletedAt),
                syncStatus: const Value('pending_sync'),
                updatedAt: Value(now),
              ),
            );
        }
      }
    });
  }

  Future<void> _advanceNextOccurrence(String templateId) async {
    final template =
        await (_db.select(_db.recurringTemplates)
              ..where((t) => t.id.equals(templateId))
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
    )..where((t) => t.id.equals(templateId))).write(
      RecurringTemplatesCompanion(
        nextOccurrenceAt: Value(next),
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

  ExactMoney _signedImpact(ExactMoney amount, String direction) {
    return switch (direction) {
      'income' => amount,
      'expense' => -amount,
      _ => throw ArgumentError.value(direction, 'direction', 'is invalid'),
    };
  }

  Future<void> _normalizeExactColumns(String transactionId, ExactMoney amount) {
    return (_db.update(
      _db.transactions,
    )..where((row) => row.id.equals(transactionId))).write(
      TransactionsCompanion(
        amount: Value(ExactMoneyCodec.legacyProjection(amount)),
        amountAtoms: Value(amount.coefficient.toString()),
        amountScale: Value(amount.scale),
        currencyCode: Value(amount.currencyCode),
      ),
    );
  }

  Future<void> _applyAccountImpact(
    AccountData account,
    ExactMoney impact,
  ) async {
    final current = ExactMoneyCodec.accountBalance(account);
    final normalizedImpact = ExactMoneyCodec.atAccountScale(impact, account);
    final updated = current + normalizedImpact;
    await (_db.update(
      _db.accounts,
    )..where((row) => row.id.equals(account.id))).write(
      AccountsCompanion(
        balance: Value(ExactMoneyCodec.legacyProjection(updated)),
        balanceAtoms: Value(updated.coefficient.toString()),
        currencyPrecision: Value(updated.scale),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

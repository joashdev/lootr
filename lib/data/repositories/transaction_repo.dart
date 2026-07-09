import 'package:drift/drift.dart' hide isNull;

import '../database/app_database.dart';

class TransactionRepoFilters {
  final String? accountId;
  final String? categoryId;
  final String? payeeId;
  final String? direction;
  final String? mode;
  final String? payeeIdFilter;
  final DateTime? from;
  final DateTime? to;

  const TransactionRepoFilters({
    this.accountId,
    this.categoryId,
    this.payeeId,
    this.direction,
    this.mode,
    this.payeeIdFilter,
    this.from,
    this.to,
  });
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

    return q.watch();
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

      final balanceChange = row.transactionDirection == 'income'
          ? row.amount
          : -row.amount;

      final account =
          await (_db.select(_db.accounts)
                ..where((a) => a.id.equals(row.accountId))
                ..limit(1))
              .getSingle();

      await (_db.update(
        _db.accounts,
      )..where((a) => a.id.equals(row.accountId))).write(
        AccountsCompanion(
          balance: Value(account.balance + balanceChange),
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(DateTime.now()),
        ),
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

      final oldImpact = old.transactionDirection == 'income'
          ? old.amount
          : -old.amount;

      final oldAccount =
          await (_db.select(_db.accounts)
                ..where((a) => a.id.equals(old.accountId))
                ..limit(1))
              .getSingle();

      await (_db.update(
        _db.accounts,
      )..where((a) => a.id.equals(old.accountId))).write(
        AccountsCompanion(
          balance: Value(oldAccount.balance - oldImpact),
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(DateTime.now()),
        ),
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

      final newImpact = updated.transactionDirection == 'income'
          ? updated.amount
          : -updated.amount;

      final newAccount =
          await (_db.select(_db.accounts)
                ..where((a) => a.id.equals(updated.accountId))
                ..limit(1))
              .getSingle();

      await (_db.update(
        _db.accounts,
      )..where((a) => a.id.equals(updated.accountId))).write(
        AccountsCompanion(
          balance: Value(newAccount.balance + newImpact),
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(DateTime.now()),
        ),
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

      final impact = txn.transactionDirection == 'income'
          ? txn.amount
          : -txn.amount;

      final account =
          await (_db.select(_db.accounts)
                ..where((a) => a.id.equals(txn.accountId))
                ..limit(1))
              .getSingle();

      await (_db.update(
        _db.accounts,
      )..where((a) => a.id.equals(txn.accountId))).write(
        AccountsCompanion(
          balance: Value(account.balance - impact),
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(DateTime.now()),
        ),
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

      final impact = txn.transactionDirection == 'income'
          ? txn.amount
          : -txn.amount;

      final account =
          await (_db.select(_db.accounts)
                ..where((a) => a.id.equals(txn.accountId))
                ..limit(1))
              .getSingle();

      await (_db.update(
        _db.accounts,
      )..where((a) => a.id.equals(txn.accountId))).write(
        AccountsCompanion(
          balance: Value(account.balance + impact),
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(DateTime.now()),
        ),
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
}

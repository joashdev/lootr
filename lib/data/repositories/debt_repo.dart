import 'package:drift/drift.dart' hide isNull;

import '../../domain/value_objects/exact_money.dart';
import '../database/app_database.dart';
import 'exact_money_codec.dart';
import 'transaction_repo.dart';

class DebtRepo {
  final AppDatabase _db;

  DebtRepo(this._db);

  Stream<List<DebtRecordData>> watchAll() {
    return (_db.select(
      _db.debtRecords,
    )..where((d) => d.deletedAt.isNull())).watch();
  }

  Stream<DebtRecordData?> watchById(String id) {
    return (_db.select(_db.debtRecords)
          ..where((d) => d.id.equals(id))
          ..limit(1))
        .watch()
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  Future<String> create(DebtRecordsCompanion d) async {
    if (!d.id.present) throw ArgumentError('id is required for create');
    await _db.into(_db.debtRecords).insert(d);
    return d.id.value;
  }

  Future<void> update(DebtRecordsCompanion d) async {
    if (!d.id.present) throw ArgumentError('id is required for update');
    final id = d.id.value;
    await (_db.update(
      _db.debtRecords,
    )..where((row) => row.id.equals(id))).write(d);
    await (_db.update(
      _db.debtRecords,
    )..where((row) => row.id.equals(id))).write(
      DebtRecordsCompanion(
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> settle(String id) async {
    final debt =
        await (_db.select(_db.debtRecords)
              ..where((row) => row.id.equals(id))
              ..limit(1))
            .getSingleOrNull();
    if (debt == null) throw StateError('Debt not found: $id');
    final remaining = debt.remainingBalanceAtoms == null
        ? ExactMoney.parse(
            debt.remainingBalance.toString(),
            debt.currencyCode ?? 'PHP',
          ).rescale(debt.amountScale ?? 2, rounding: MoneyRoundingMode.halfEven)
        : ExactMoney(
            coefficient: BigInt.parse(debt.remainingBalanceAtoms!),
            scale: debt.amountScale ?? 2,
            currencyCode: debt.currencyCode ?? 'PHP',
          );
    await recordPaymentExact(id, remaining);
  }

  Future<void> recordPayment(
    String id,
    double amount, {
    String? transactionId,
  }) async {
    final debt =
        await (_db.select(_db.debtRecords)
              ..where((row) => row.id.equals(id))
              ..limit(1))
            .getSingleOrNull();
    if (debt == null) throw StateError('Debt not found: $id');
    final scale = debt.amountScale ?? 2;
    final currency = debt.currencyCode ?? 'PHP';
    await recordPaymentExact(
      id,
      ExactMoney.parse(
        amount.toString(),
        currency,
      ).rescale(scale, rounding: MoneyRoundingMode.halfEven),
      transactionId: transactionId,
    );
  }

  Future<void> recordPaymentExact(
    String id,
    ExactMoney amount, {
    String? transactionId,
    TransactionsCompanion? transaction,
  }) async {
    await _db.transaction(() async {
      final debt =
          await (_db.select(_db.debtRecords)
                ..where((row) => row.id.equals(id))
                ..limit(1))
              .getSingleOrNull();
      if (debt == null) throw StateError('Debt not found: $id');
      final scale = debt.amountScale ?? 2;
      final currency = debt.currencyCode ?? 'PHP';
      if (amount.currencyCode != currency) {
        throw ArgumentError('Payment currency does not match the debt');
      }
      final requested = amount.rescale(scale).abs();
      final remaining = debt.remainingBalanceAtoms == null
          ? ExactMoney.parse(
              debt.remainingBalance.toString(),
              currency,
            ).rescale(scale, rounding: MoneyRoundingMode.halfEven)
          : ExactMoney(
              coefficient: BigInt.parse(debt.remainingBalanceAtoms!),
              scale: scale,
              currencyCode: currency,
            );
      final payment = requested.compareTo(remaining) > 0
          ? remaining
          : requested;
      final updated = remaining - payment;
      final now = DateTime.now();
      final linkedTransactionId = transaction == null
          ? transactionId
          : await TransactionRepo(_db).create(transaction);
      await _db
          .into(_db.debtPaymentEvents)
          .insert(
            DebtPaymentEventsCompanion.insert(
              id: 'debt-event-${now.microsecondsSinceEpoch}',
              debtRecordId: id,
              transactionId: Value(linkedTransactionId),
              amountAtoms: payment.coefficient.toString(),
              amountScale: payment.scale,
              currencyCode: payment.currencyCode,
              occurredAt: now,
            ),
          );
      await (_db.update(
        _db.debtRecords,
      )..where((row) => row.id.equals(id))).write(
        DebtRecordsCompanion(
          remainingBalance: Value(ExactMoneyCodec.legacyProjection(updated)),
          remainingBalanceAtoms: Value(updated.coefficient.toString()),
          amountScale: Value(scale),
          currencyCode: Value(currency),
          status: Value(updated.isZero ? 'settled' : 'partially_paid'),
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(now),
        ),
      );
    });
  }

  Future<void> softDelete(String id) async {
    await (_db.update(
      _db.debtRecords,
    )..where((row) => row.id.equals(id))).write(
      DebtRecordsCompanion(
        deletedAt: Value(DateTime.now()),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

import 'package:drift/drift.dart' hide isNull;

import '../../domain/value_objects/exact_money.dart';
import '../database/app_database.dart';
import 'exact_money_codec.dart';

class TransferRepo {
  TransferRepo(this._db);

  final AppDatabase _db;

  Stream<List<TransferData>> watchAll() {
    final query = _db.select(_db.transfers)
      ..where((row) => row.deletedAt.isNull())
      ..orderBy([
        (row) =>
            OrderingTerm(expression: row.occurredAt, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  Stream<List<TransferData>> watchByAccount(String accountId) {
    final query = _db.select(_db.transfers)
      ..where(
        (row) =>
            (row.sourceAccountId.equals(accountId) |
                row.destinationAccountId.equals(accountId)) &
            row.deletedAt.isNull(),
      )
      ..orderBy([
        (row) =>
            OrderingTerm(expression: row.occurredAt, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  Stream<TransferData?> watchById(String id) {
    return (_db.select(_db.transfers)
          ..where((row) => row.id.equals(id))
          ..limit(1))
        .watch()
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  Future<String> create(TransfersCompanion companion) async {
    if (!companion.id.present) {
      throw ArgumentError('id is required for create');
    }
    return _db.transaction(() async {
      await _db.into(_db.transfers).insert(companion);
      final row = await _transfer(companion.id.value);
      final accounts = await _accountsFor(row);
      final amounts = _resolveAmounts(row, accounts);
      _validate(row, amounts);

      await _normalizeExactColumns(row.id, amounts);
      await _applyAccountImpact(
        accounts.source,
        -(amounts.source + amounts.fee),
      );
      await _applyAccountImpact(accounts.destination, amounts.destination);
      await _upsertFeeTransaction(row, amounts.fee);
      return row.id;
    });
  }

  Future<void> update(TransfersCompanion companion) async {
    if (!companion.id.present) {
      throw ArgumentError('id is required for update');
    }
    await _db.transaction(() async {
      final old = await _transfer(companion.id.value);
      final oldAccounts = await _accountsFor(old);
      final oldAmounts = _resolveAmounts(old, oldAccounts);

      await _applyAccountImpact(
        oldAccounts.source,
        oldAmounts.source + oldAmounts.fee,
      );
      await _applyAccountImpact(
        oldAccounts.destination,
        -oldAmounts.destination,
      );

      await (_db.update(
        _db.transfers,
      )..where((row) => row.id.equals(old.id))).write(companion);
      await (_db.update(
        _db.transfers,
      )..where((row) => row.id.equals(old.id))).write(
        TransfersCompanion(
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final updated = await _transfer(old.id);
      final updatedAccounts = await _accountsFor(updated);
      final updatedAmounts = _resolveAmounts(
        updated,
        updatedAccounts,
        preferLegacySource:
            companion.amount.present &&
            !companion.sourceAmountAtoms.present &&
            !companion.sourceAmountScale.present &&
            !companion.sourceCurrencyCode.present,
        preferLegacyDestination:
            companion.amount.present &&
            !companion.destinationAmountAtoms.present &&
            !companion.destinationAmountScale.present &&
            !companion.destinationCurrencyCode.present,
        preferLegacyFee:
            companion.feeAmount.present &&
            !companion.feeAmountAtoms.present &&
            !companion.feeAmountScale.present &&
            !companion.feeCurrencyCode.present,
      );
      _validate(updated, updatedAmounts);

      await _normalizeExactColumns(updated.id, updatedAmounts);
      await _applyAccountImpact(
        updatedAccounts.source,
        -(updatedAmounts.source + updatedAmounts.fee),
      );
      await _applyAccountImpact(
        updatedAccounts.destination,
        updatedAmounts.destination,
      );
      await _upsertFeeTransaction(updated, updatedAmounts.fee);
    });
  }

  Future<void> softDelete(String id) async {
    await _db.transaction(() async {
      final rows =
          await (_db.select(_db.transfers)
                ..where((row) => row.id.equals(id) & row.deletedAt.isNull())
                ..limit(1))
              .get();
      if (rows.isEmpty) return;
      final transfer = rows.first;
      final accounts = await _accountsFor(transfer);
      final amounts = _resolveAmounts(transfer, accounts);

      await _applyAccountImpact(accounts.source, amounts.source + amounts.fee);
      await _applyAccountImpact(accounts.destination, -amounts.destination);

      final now = DateTime.now();
      await (_db.update(
        _db.transfers,
      )..where((row) => row.id.equals(id))).write(
        TransfersCompanion(
          deletedAt: Value(now),
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(now),
        ),
      );
      if (!amounts.fee.isZero) {
        await _setFeeDeleted(id, now);
      }
    });
  }

  Future<void> restore(String id) async {
    await _db.transaction(() async {
      final rows =
          await (_db.select(_db.transfers)
                ..where((row) => row.id.equals(id) & row.deletedAt.isNotNull())
                ..limit(1))
              .get();
      if (rows.isEmpty) return;
      final transfer = rows.first;
      final accounts = await _accountsFor(transfer);
      final amounts = _resolveAmounts(transfer, accounts);

      await _applyAccountImpact(
        accounts.source,
        -(amounts.source + amounts.fee),
      );
      await _applyAccountImpact(accounts.destination, amounts.destination);

      final now = DateTime.now();
      await (_db.update(
        _db.transfers,
      )..where((row) => row.id.equals(id))).write(
        TransfersCompanion(
          deletedAt: const Value(null),
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(now),
        ),
      );
      if (!amounts.fee.isZero) {
        await (_db.update(
          _db.transactions,
        )..where((row) => row.id.equals(_feeId(id)))).write(
          TransactionsCompanion(
            deletedAt: const Value(null),
            syncStatus: const Value('pending_sync'),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  Future<TransferData> _transfer(String id) {
    return (_db.select(_db.transfers)
          ..where((row) => row.id.equals(id))
          ..limit(1))
        .getSingle();
  }

  Future<({AccountData source, AccountData destination})> _accountsFor(
    TransferData transfer,
  ) async {
    if (transfer.sourceAccountId == transfer.destinationAccountId) {
      throw ArgumentError('Transfer accounts must be different');
    }
    final source =
        await (_db.select(_db.accounts)
              ..where((row) => row.id.equals(transfer.sourceAccountId))
              ..limit(1))
            .getSingle();
    final destination =
        await (_db.select(_db.accounts)
              ..where((row) => row.id.equals(transfer.destinationAccountId))
              ..limit(1))
            .getSingle();
    return (source: source, destination: destination);
  }

  _TransferAmounts _resolveAmounts(
    TransferData transfer,
    ({AccountData source, AccountData destination}) accounts, {
    bool preferLegacySource = false,
    bool preferLegacyDestination = false,
    bool preferLegacyFee = false,
  }) {
    final isCrossCurrency =
        accounts.source.currencyCode != accounts.destination.currencyCode;
    if (isCrossCurrency &&
        (transfer.destinationAmountAtoms == null ||
            transfer.destinationAmountScale == null ||
            transfer.destinationCurrencyCode == null)) {
      throw StateError(
        'Cross-currency transfers require an explicit destination amount',
      );
    }
    return _TransferAmounts(
      source: ExactMoneyCodec.transferSourceAmount(
        transfer,
        accounts.source,
        preferLegacyProjection: preferLegacySource,
      ),
      destination: ExactMoneyCodec.transferDestinationAmount(
        transfer,
        accounts.destination,
        preferLegacyProjection: !isCrossCurrency && preferLegacyDestination,
      ),
      fee: ExactMoneyCodec.transferFee(
        transfer,
        accounts.source,
        preferLegacyProjection: preferLegacyFee,
      ),
    );
  }

  void _validate(TransferData transfer, _TransferAmounts amounts) {
    ExactMoneyCodec.requirePositive(amounts.source, 'sourceAmount');
    ExactMoneyCodec.requirePositive(amounts.destination, 'destinationAmount');
    if (amounts.fee.isNegative) {
      throw ArgumentError.value(
        amounts.fee.toDecimalString(),
        'feeAmount',
        'must not be negative',
      );
    }
    if (amounts.source.currencyCode == amounts.destination.currencyCode &&
        amounts.source.compareTo(amounts.destination) != 0) {
      throw ArgumentError(
        'Same-currency transfer legs must have equal exact values',
      );
    }
    if (transfer.sourceAccountId == transfer.destinationAccountId) {
      throw ArgumentError('Transfer accounts must be different');
    }
  }

  Future<void> _normalizeExactColumns(String id, _TransferAmounts amounts) {
    return (_db.update(_db.transfers)..where((row) => row.id.equals(id))).write(
      TransfersCompanion(
        amount: Value(ExactMoneyCodec.legacyProjection(amounts.source)),
        sourceAmountAtoms: Value(amounts.source.coefficient.toString()),
        sourceAmountScale: Value(amounts.source.scale),
        sourceCurrencyCode: Value(amounts.source.currencyCode),
        destinationAmountAtoms: Value(
          amounts.destination.coefficient.toString(),
        ),
        destinationAmountScale: Value(amounts.destination.scale),
        destinationCurrencyCode: Value(amounts.destination.currencyCode),
        feeAmount: Value(ExactMoneyCodec.legacyProjection(amounts.fee)),
        feeAmountAtoms: Value(amounts.fee.coefficient.toString()),
        feeAmountScale: Value(amounts.fee.scale),
        feeCurrencyCode: Value(amounts.fee.currencyCode),
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

  Future<void> _upsertFeeTransaction(
    TransferData transfer,
    ExactMoney fee,
  ) async {
    final id = _feeId(transfer.id);
    if (fee.isZero) {
      await _setFeeDeleted(transfer.id, DateTime.now());
      return;
    }
    final companion = TransactionsCompanion.insert(
      id: id,
      accountId: transfer.sourceAccountId,
      amount: ExactMoneyCodec.legacyProjection(fee),
      amountAtoms: Value(fee.coefficient.toString()),
      amountScale: Value(fee.scale),
      currencyCode: Value(fee.currencyCode),
      transactionDirection: 'expense',
      transactionMode: 'one_time',
      transactionSubtype: const Value('transfer_fee'),
      note: const Value('Transfer fee'),
      occurredAt: transfer.occurredAt,
      syncStatus: const Value('pending_sync'),
    );
    final existing = await (_db.select(
      _db.transactions,
    )..where((row) => row.id.equals(id))).get();
    if (existing.isEmpty) {
      await _db.into(_db.transactions).insert(companion);
      return;
    }
    await (_db.update(
      _db.transactions,
    )..where((row) => row.id.equals(id))).write(
      TransactionsCompanion(
        accountId: Value(transfer.sourceAccountId),
        amount: Value(ExactMoneyCodec.legacyProjection(fee)),
        amountAtoms: Value(fee.coefficient.toString()),
        amountScale: Value(fee.scale),
        currencyCode: Value(fee.currencyCode),
        transactionDirection: const Value('expense'),
        transactionMode: const Value('one_time'),
        transactionSubtype: const Value('transfer_fee'),
        note: const Value('Transfer fee'),
        occurredAt: Value(transfer.occurredAt),
        deletedAt: const Value(null),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _setFeeDeleted(String transferId, DateTime deletedAt) {
    return (_db.update(
      _db.transactions,
    )..where((row) => row.id.equals(_feeId(transferId)))).write(
      TransactionsCompanion(
        deletedAt: Value(deletedAt),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(deletedAt),
      ),
    );
  }

  String _feeId(String transferId) => 'txn-fee-$transferId';
}

class _TransferAmounts {
  const _TransferAmounts({
    required this.source,
    required this.destination,
    required this.fee,
  });

  final ExactMoney source;
  final ExactMoney destination;
  final ExactMoney fee;
}

import 'package:drift/drift.dart' hide isNull;

import '../database/app_database.dart';
import '../../domain/value_objects/exact_money.dart';
import 'exact_money_codec.dart';

class AccountRepo {
  final AppDatabase _db;

  AccountRepo(this._db);

  Stream<List<AccountData>> watchAll({bool includeArchived = false}) {
    final q = _db.select(_db.accounts)..where((a) => a.deletedAt.isNull());

    if (!includeArchived) {
      q.where((a) => a.isArchived.equals(false));
    }

    return q.watch();
  }

  Stream<AccountData?> watchById(String id) {
    return (_db.select(_db.accounts)
          ..where((a) => a.id.equals(id))
          ..limit(1))
        .watch()
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  Future<String> create(AccountsCompanion a) async {
    if (!a.id.present) throw ArgumentError('id is required for create');
    return _db.transaction(() async {
      await _db.into(_db.accounts).insert(a);
      await _promoteExactBalance(
        a.id.value,
        preferLegacyProjection: !a.balanceAtoms.present && a.balance.present,
      );
      return a.id.value;
    });
  }

  Future<void> update(AccountsCompanion a) async {
    if (!a.id.present) throw ArgumentError('id is required for update');
    final id = a.id.value;
    await _db.transaction(() async {
      final old =
          await (_db.select(_db.accounts)
                ..where((row) => row.id.equals(id))
                ..limit(1))
              .getSingle();
      final oldExact = ExactMoneyCodec.accountBalance(old);
      final currency = a.currencyCode.present
          ? a.currencyCode.value
          : old.currencyCode;
      final scale = a.currencyPrecision.present
          ? a.currencyPrecision.value ?? ExactMoneyCodec.legacyScale
          : old.currencyPrecision ?? ExactMoneyCodec.legacyScale;
      if (currency != old.currencyCode &&
          !a.balance.present &&
          !a.balanceAtoms.present) {
        throw StateError(
          'Changing account currency requires an explicit converted balance',
        );
      }
      final exact = a.balanceAtoms.present && a.balanceAtoms.value != null
          ? ExactMoney(
              coefficient: BigInt.parse(a.balanceAtoms.value!),
              scale: scale,
              currencyCode: currency,
            )
          : a.balance.present
          ? ExactMoneyCodec.fromLegacyDouble(a.balance.value, currency, scale)
          : oldExact.rescale(scale);

      await (_db.update(
        _db.accounts,
      )..where((row) => row.id.equals(id))).write(a);
      await (_db.update(_db.accounts)..where((row) => row.id.equals(id))).write(
        AccountsCompanion(
          balance: Value(ExactMoneyCodec.legacyProjection(exact)),
          balanceAtoms: Value(exact.coefficient.toString()),
          currencyPrecision: Value(exact.scale),
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> archive(String id) async {
    await (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        isArchived: const Value(true),
        syncStatus: const Value('pending_sync'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<double> getBalance(String id) async {
    final balance = await getExactBalance(id);
    return ExactMoneyCodec.legacyProjection(balance);
  }

  Future<ExactMoney> getExactBalance(String id) async {
    final account =
        await (_db.select(_db.accounts)
              ..where((a) => a.id.equals(id))
              ..limit(1))
            .getSingle();
    return ExactMoneyCodec.accountBalance(account);
  }

  Future<void> recalcBalance(String id) async {
    await _db.transaction(() async {
      final txns = await (_db.select(
        _db.transactions,
      )..where((t) => t.accountId.equals(id) & t.deletedAt.isNull())).get();

      final transfers =
          await (_db.select(_db.transfers)..where(
                (t) =>
                    t.deletedAt.isNull() &
                    (t.sourceAccountId.equals(id) |
                        t.destinationAccountId.equals(id)),
              ))
              .get();

      final account =
          await (_db.select(_db.accounts)
                ..where((a) => a.id.equals(id))
                ..limit(1))
              .getSingle();
      final scale = account.currencyPrecision ?? ExactMoneyCodec.legacyScale;
      var balance = ExactMoney(
        coefficient: BigInt.zero,
        scale: scale,
        currencyCode: account.currencyCode,
      );
      for (final t in txns) {
        final amount = ExactMoneyCodec.transactionAmount(t, account);
        final impact = ExactMoneyCodec.atAccountScale(amount, account);
        balance = t.transactionDirection == 'income'
            ? balance + impact
            : balance - impact;
      }
      for (final x in transfers) {
        if (x.sourceAccountId == id) {
          balance -= ExactMoneyCodec.atAccountScale(
            ExactMoneyCodec.transferSourceAmount(x, account),
            account,
          );
        }
        if (x.destinationAccountId == id) {
          balance += ExactMoneyCodec.atAccountScale(
            ExactMoneyCodec.transferDestinationAmount(x, account),
            account,
          );
        }
      }

      await (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
        AccountsCompanion(
          balance: Value(ExactMoneyCodec.legacyProjection(balance)),
          balanceAtoms: Value(balance.coefficient.toString()),
          currencyPrecision: Value(balance.scale),
          syncStatus: const Value('pending_sync'),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> _promoteExactBalance(
    String id, {
    required bool preferLegacyProjection,
  }) async {
    final account =
        await (_db.select(_db.accounts)
              ..where((row) => row.id.equals(id))
              ..limit(1))
            .getSingle();
    final scale = account.currencyPrecision ?? ExactMoneyCodec.legacyScale;
    final exact = preferLegacyProjection || account.balanceAtoms == null
        ? ExactMoneyCodec.fromLegacyDouble(
            account.balance,
            account.currencyCode,
            scale,
          )
        : ExactMoneyCodec.accountBalance(account);
    await (_db.update(_db.accounts)..where((row) => row.id.equals(id))).write(
      AccountsCompanion(
        balance: Value(ExactMoneyCodec.legacyProjection(exact)),
        balanceAtoms: Value(exact.coefficient.toString()),
        currencyPrecision: Value(exact.scale),
      ),
    );
  }
}

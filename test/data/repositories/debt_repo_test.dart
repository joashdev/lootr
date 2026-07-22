import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/debt_repo.dart';
import 'package:lootr/domain/entities/mappers.dart';
import 'package:lootr/domain/value_objects/exact_money.dart';
import 'package:lootr/domain/value_objects/field_types.dart';

void main() {
  late AppDatabase db;
  late DebtRepo repo;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = DebtRepo(db);

    await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
  });

  tearDown(() async {
    await db.close();
  });

  group('DebtRepo', () {
    test('create inserts and returns id', () async {
      final id = await repo.create(
        DebtRecordsCompanion.insert(
          id: 'debt-1',
          ownerUserId: 'usr-1',
          counterpartyName: 'John',
          debtDirection: 'lent',
          amount: 500.0,
          remainingBalance: 500.0,
          status: 'active',
        ),
      );
      expect(id, 'debt-1');
    });

    test('watchAll returns non-deleted debt records', () async {
      await repo.create(
        DebtRecordsCompanion.insert(
          id: 'debt-1',
          ownerUserId: 'usr-1',
          counterpartyName: 'John',
          debtDirection: 'lent',
          amount: 500.0,
          remainingBalance: 500.0,
          status: 'active',
        ),
      );
      await repo.create(
        DebtRecordsCompanion.insert(
          id: 'debt-2',
          ownerUserId: 'usr-1',
          counterpartyName: 'Jane',
          debtDirection: 'borrowed',
          amount: 200.0,
          remainingBalance: 200.0,
          status: 'active',
        ),
      );

      final debts = await repo.watchAll().first;
      expect(debts.length, 2);
    });

    test('watchById returns debt or null', () async {
      await repo.create(
        DebtRecordsCompanion.insert(
          id: 'debt-1',
          ownerUserId: 'usr-1',
          counterpartyName: 'John',
          debtDirection: 'lent',
          amount: 500.0,
          remainingBalance: 500.0,
          status: 'active',
        ),
      );

      final found = await repo.watchById('debt-1').first;
      expect(found, isNotNull);
      expect(found!.counterpartyName, 'John');

      final missing = await repo.watchById('nope').first;
      expect(missing, isNull);
    });

    test('watchById preserves exact amount currency and scale', () async {
      await repo.create(
        DebtRecordsCompanion.insert(
          id: 'debt-exact',
          ownerUserId: 'usr-1',
          counterpartyName: 'Counterparty',
          debtDirection: 'borrowed',
          amount: 1,
          remainingBalance: 0.000000000001,
          amountAtoms: const Value('1000000000000'),
          remainingBalanceAtoms: const Value('1'),
          amountScale: const Value(12),
          currencyCode: const Value('BTC'),
          status: 'active',
        ),
      );

      final debt = (await repo.watchById('debt-exact').first)!.toEntity();
      expect(debt.exactAmount.toDecimalString(), '1.000000000000');
      expect(debt.exactRemainingBalance.toDecimalString(), '0.000000000001');
      expect(debt.currencyCode, 'BTC');
    });

    test('settle records the full remaining balance as an event', () async {
      await repo.create(
        DebtRecordsCompanion.insert(
          id: 'debt-1',
          ownerUserId: 'usr-1',
          counterpartyName: 'John',
          debtDirection: 'lent',
          amount: 500.0,
          remainingBalance: 500.0,
          status: 'active',
        ),
      );

      await repo.settle('debt-1');

      final debt = await (db.select(db.debtRecords)..limit(1)).getSingle();
      final event = await db.select(db.debtPaymentEvents).getSingle();
      expect(debt.status, 'settled');
      expect(debt.remainingBalance, 0.0);
      expect(event.debtRecordId, 'debt-1');
      expect(event.amountAtoms, '50000');
      expect(event.amountScale, 2);
    });

    test('recordPayment appends an exact immutable payment event', () async {
      await repo.create(
        DebtRecordsCompanion.insert(
          id: 'debt-payment',
          ownerUserId: 'usr-1',
          counterpartyName: 'Synthetic counterparty',
          debtDirection: 'borrowed',
          amount: 1,
          remainingBalance: 1,
          amountAtoms: const Value('10000'),
          remainingBalanceAtoms: const Value('10000'),
          amountScale: const Value(4),
          currencyCode: const Value('XAA'),
          status: 'active',
        ),
      );

      await repo.recordPayment('debt-payment', 0.125);

      final debt = await (db.select(
        db.debtRecords,
      )..where((row) => row.id.equals('debt-payment'))).getSingle();
      final event = await db.select(db.debtPaymentEvents).getSingle();
      expect(debt.remainingBalanceAtoms, '8750');
      expect(event.amountAtoms, '1250');
      expect(event.amountScale, 4);
      expect(event.currencyCode, 'XAA');
    });

    test('exact payment and linked transaction commit atomically', () async {
      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'account-1',
          ownerUserId: 'usr-1',
          name: 'Synthetic account',
          accountType: 'bank',
          currencyCode: const Value('XAA'),
          currencyPrecision: const Value(4),
          balanceAtoms: const Value('10000'),
          balance: const Value(1),
        ),
      );
      await repo.create(
        DebtRecordsCompanion.insert(
          id: 'debt-linked',
          ownerUserId: 'usr-1',
          counterpartyName: 'Synthetic counterparty',
          debtDirection: 'borrowed',
          amount: 1,
          remainingBalance: 1,
          amountAtoms: const Value('10000'),
          remainingBalanceAtoms: const Value('10000'),
          amountScale: const Value(4),
          currencyCode: const Value('XAA'),
          status: 'active',
        ),
      );
      final amount = ExactMoney.parse('0.1250', 'XAA');
      await repo.recordPaymentExact(
        'debt-linked',
        amount,
        transaction: TransactionsCompanion.insert(
          id: 'debt-transaction',
          accountId: 'account-1',
          amount: amount.toDouble(),
          amountAtoms: Value(amount.coefficient.toString()),
          amountScale: Value(amount.scale),
          currencyCode: Value(amount.currencyCode),
          transactionDirection: TransactionDirection.expense,
          transactionMode: TransactionMode.debt,
          occurredAt: DateTime.utc(2026),
        ),
      );

      final event = await db.select(db.debtPaymentEvents).getSingle();
      expect(event.transactionId, 'debt-transaction');
      expect(event.amountAtoms, '1250');
      expect(await db.select(db.transactions).get(), hasLength(1));
    });
  });
}

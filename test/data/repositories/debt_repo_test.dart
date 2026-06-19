import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/debt_repo.dart';

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
      final id = await repo.create(DebtRecordsCompanion.insert(
        id: 'debt-1',
        ownerUserId: 'usr-1',
        counterpartyName: 'John',
        debtDirection: 'lent',
        amount: 500.0,
        remainingBalance: 500.0,
        status: 'active',
      ));
      expect(id, 'debt-1');
    });

    test('watchAll returns non-deleted debt records', () async {
      await repo.create(DebtRecordsCompanion.insert(
        id: 'debt-1',
        ownerUserId: 'usr-1',
        counterpartyName: 'John',
        debtDirection: 'lent',
        amount: 500.0,
        remainingBalance: 500.0,
        status: 'active',
      ));
      await repo.create(DebtRecordsCompanion.insert(
        id: 'debt-2',
        ownerUserId: 'usr-1',
        counterpartyName: 'Jane',
        debtDirection: 'borrowed',
        amount: 200.0,
        remainingBalance: 200.0,
        status: 'active',
      ));

      final debts = await repo.watchAll().first;
      expect(debts.length, 2);
    });

    test('watchById returns debt or null', () async {
      await repo.create(DebtRecordsCompanion.insert(
        id: 'debt-1',
        ownerUserId: 'usr-1',
        counterpartyName: 'John',
        debtDirection: 'lent',
        amount: 500.0,
        remainingBalance: 500.0,
        status: 'active',
      ));

      final found = await repo.watchById('debt-1').first;
      expect(found, isNotNull);
      expect(found!.counterpartyName, 'John');

      final missing = await repo.watchById('nope').first;
      expect(missing, isNull);
    });

    test('settle sets status to settled and balance to 0', () async {
      await repo.create(DebtRecordsCompanion.insert(
        id: 'debt-1',
        ownerUserId: 'usr-1',
        counterpartyName: 'John',
        debtDirection: 'lent',
        amount: 500.0,
        remainingBalance: 500.0,
        status: 'active',
      ));

      await repo.settle('debt-1');

      final debt = await (db.select(db.debtRecords)..limit(1)).getSingle();
      expect(debt.status, 'settled');
      expect(debt.remainingBalance, 0.0);
    });
  });
}

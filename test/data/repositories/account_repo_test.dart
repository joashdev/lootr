import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/account_repo.dart';

void main() {
  late AppDatabase db;
  late AccountRepo repo;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = AccountRepo(db);

    await db.users.insertOne(
      UsersCompanion.insert(id: 'usr-1'),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('AccountRepo', () {
    test('create inserts and returns id', () async {
      final id = await repo.create(AccountsCompanion.insert(
        id: 'acc-1',
        ownerUserId: 'usr-1',
        name: 'Cash',
        accountType: 'cash',
      ));

      expect(id, 'acc-1');

      final account = await (db.select(db.accounts)..limit(1)).getSingle();
      expect(account.name, 'Cash');
      expect(account.balance, 0.0);
    });

    test('watchAll returns non-archived by default', () async {
      await repo.create(AccountsCompanion.insert(
        id: 'acc-1',
        ownerUserId: 'usr-1',
        name: 'Active',
        accountType: 'cash',
      ));
      await repo.create(AccountsCompanion.insert(
        id: 'acc-2',
        ownerUserId: 'usr-1',
        name: 'Archived',
        accountType: 'bank',
      ));
      await repo.archive('acc-2');

      final accounts = await repo.watchAll().first;
      expect(accounts.length, 1);
      expect(accounts.first.name, 'Active');
    });

    test('watchAll with includeArchived returns all', () async {
      await repo.create(AccountsCompanion.insert(
        id: 'acc-1',
        ownerUserId: 'usr-1',
        name: 'Active',
        accountType: 'cash',
      ));
      await repo.create(AccountsCompanion.insert(
        id: 'acc-2',
        ownerUserId: 'usr-1',
        name: 'Archived',
        accountType: 'bank',
      ));
      await repo.archive('acc-2');

      final accounts = await repo.watchAll(includeArchived: true).first;
      expect(accounts.length, 2);
    });

    test('watchById returns account or null', () async {
      await repo.create(AccountsCompanion.insert(
        id: 'acc-1',
        ownerUserId: 'usr-1',
        name: 'Cash',
        accountType: 'cash',
      ));

      final found = await repo.watchById('acc-1').first;
      expect(found, isNotNull);
      expect(found!.name, 'Cash');

      final missing = await repo.watchById('nope').first;
      expect(missing, isNull);
    });

    test('archive sets isArchived to true', () async {
      await repo.create(AccountsCompanion.insert(
        id: 'acc-1',
        ownerUserId: 'usr-1',
        name: 'Cash',
        accountType: 'cash',
      ));

      await repo.archive('acc-1');

      final account = await (db.select(db.accounts)..limit(1)).getSingle();
      expect(account.isArchived, true);
    });

    test('getBalance returns current balance', () async {
      await repo.create(AccountsCompanion.insert(
        id: 'acc-1',
        ownerUserId: 'usr-1',
        name: 'Cash',
        accountType: 'cash',
        balance: const Value(250.0),
      ));

      final balance = await repo.getBalance('acc-1');
      expect(balance, 250.0);
    });

    test('recalcBalance sums all non-deleted transactions', () async {
      await repo.create(AccountsCompanion.insert(
        id: 'acc-1',
        ownerUserId: 'usr-1',
        name: 'Cash',
        accountType: 'cash',
      ));

      await db.categories.insertOne(
        CategoriesCompanion.insert(
          id: 'cat-1',
          name: 'Food',
          categoryGroup: 'expense',
        ),
      );

      await db.transactions.insertOne(
        TransactionsCompanion.insert(
          id: 'txn-1',
          accountId: 'acc-1',
          amount: 100.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 19),
        ),
      );
      await db.transactions.insertOne(
        TransactionsCompanion.insert(
          id: 'txn-2',
          accountId: 'acc-1',
          amount: 300.0,
          transactionDirection: 'income',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 19),
        ),
      );

      await db.transactions.insertOne(
        TransactionsCompanion.insert(
          id: 'txn-3',
          accountId: 'acc-1',
          amount: 50.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 19),
        ),
      );

      await (db.update(db.transactions)
            ..where((t) => t.id.equals('txn-3')))
          .write(TransactionsCompanion(
        deletedAt: Value(DateTime.now()),
      ));

      await repo.recalcBalance('acc-1');

      final balance = await repo.getBalance('acc-1');
      expect(balance, 200.0);
    });

    test('recalcBalance includes transfers', () async {
      await repo.create(AccountsCompanion.insert(
        id: 'acc-src',
        ownerUserId: 'usr-1',
        name: 'Source',
        accountType: 'bank',
        balance: const Value(0),
      ));
      await repo.create(AccountsCompanion.insert(
        id: 'acc-dst',
        ownerUserId: 'usr-1',
        name: 'Dest',
        accountType: 'cash',
        balance: const Value(0),
      ));

      await db.transfers.insertOne(
        TransfersCompanion.insert(
          id: 'xfer-1',
          sourceAccountId: 'acc-src',
          destinationAccountId: 'acc-dst',
          amount: 300.0,
          occurredAt: DateTime(2026, 6, 19),
        ),
      );
      await db.transfers.insertOne(
        TransfersCompanion.insert(
          id: 'xfer-2',
          sourceAccountId: 'acc-dst',
          destinationAccountId: 'acc-src',
          amount: 100.0,
          occurredAt: DateTime(2026, 6, 19),
        ),
      );

      await repo.recalcBalance('acc-src');
      expect(await repo.getBalance('acc-src'), -200.0);

      await repo.recalcBalance('acc-dst');
      expect(await repo.getBalance('acc-dst'), 200.0);
    });
  });
}

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/transaction_repo.dart';

void main() {
  late AppDatabase db;
  late TransactionRepo repo;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = TransactionRepo(db);

    await db.users.insertOne(
      UsersCompanion.insert(id: 'usr-1'),
    );
    await db.accounts.insertOne(
      AccountsCompanion.insert(
        id: 'acc-1',
        ownerUserId: 'usr-1',
        name: 'Cash',
        accountType: 'cash',
        balance: const Value(500.0),
      ),
    );
    await db.categories.insertOne(
      CategoriesCompanion.insert(
        id: 'cat-1',
        name: 'Food',
        categoryGroup: 'expense',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('TransactionRepo', () {
    test('create inserts row and atomically updates account balance (expense)',
        () async {
      final txId = await repo.create(TransactionsCompanion.insert(
        id: 'txn-1',
        accountId: 'acc-1',
        amount: 100.0,
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        occurredAt: DateTime(2026, 6, 19),
      ));

      expect(txId, 'txn-1');

      final txn = await (db.select(db.transactions)
            ..where((t) => t.id.equals('txn-1'))
            ..limit(1))
          .getSingle();
      expect(txn.amount, 100.0);
      expect(txn.transactionDirection, 'expense');

      final account = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-1'))
            ..limit(1))
          .getSingle();
      expect(account.balance, 400.0);
      expect(account.syncStatus, 'pending_sync');
    });

    test('create atomically updates account balance (income)', () async {
      await repo.create(TransactionsCompanion.insert(
        id: 'txn-inc',
        accountId: 'acc-1',
        amount: 200.0,
        transactionDirection: 'income',
        transactionMode: 'one_time',
        occurredAt: DateTime(2026, 6, 19),
      ));

      final account = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-1'))
            ..limit(1))
          .getSingle();
      expect(account.balance, 700.0);
    });

    test('softDelete reverts balance and sets deleted_at', () async {
      await repo.create(TransactionsCompanion.insert(
        id: 'txn-del',
        accountId: 'acc-1',
        amount: 100.0,
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        occurredAt: DateTime(2026, 6, 19),
      ));

      var account = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-1'))
            ..limit(1))
          .getSingle();
      expect(account.balance, 400.0);

      await repo.softDelete('txn-del');

      account = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-1'))
            ..limit(1))
          .getSingle();
      expect(account.balance, 500.0);
      expect(account.syncStatus, 'pending_sync');

      final txn = await (db.select(db.transactions)
            ..where((t) => t.id.equals('txn-del'))
            ..limit(1))
          .getSingle();
      expect(txn.deletedAt, isNotNull);
      expect(txn.syncStatus, 'pending_sync');
    });

    test('watchFiltered returns non-deleted transactions', () async {
      await repo.create(TransactionsCompanion.insert(
        id: 'txn-a',
        accountId: 'acc-1',
        amount: 50.0,
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        occurredAt: DateTime(2026, 6, 19),
      ));

      await repo.softDelete('txn-a');

      await repo.create(TransactionsCompanion.insert(
        id: 'txn-b',
        accountId: 'acc-1',
        amount: 30.0,
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        occurredAt: DateTime(2026, 6, 19),
      ));

      final txns = await repo
          .watchFiltered(const TransactionFilters())
          .first;

      expect(txns.length, 1);
      expect(txns.first.id, 'txn-b');
    });

    test('watchFiltered filters by accountId', () async {
      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-2',
          ownerUserId: 'usr-1',
          name: 'Bank',
          accountType: 'bank',
        ),
      );

      await repo.create(TransactionsCompanion.insert(
        id: 'txn-1',
        accountId: 'acc-1',
        amount: 50.0,
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        occurredAt: DateTime(2026, 6, 19),
      ));

      await repo.create(TransactionsCompanion.insert(
        id: 'txn-2',
        accountId: 'acc-2',
        amount: 100.0,
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        occurredAt: DateTime(2026, 6, 19),
      ));

      final txns = await repo
          .watchFiltered(
              const TransactionFilters(accountId: 'acc-1'))
          .first;

      expect(txns.length, 1);
      expect(txns.first.accountId, 'acc-1');
    });

    test('watchById emits when row changes', () async {
      await repo.create(TransactionsCompanion.insert(
        id: 'txn-watch',
        accountId: 'acc-1',
        amount: 50.0,
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        occurredAt: DateTime(2026, 6, 19),
      ));

      final stream = repo.watchById('txn-watch');
      final first = await stream.first;
      expect(first, isNotNull);
      expect(first!.amount, 50.0);

      await (db.update(db.transactions)
            ..where((t) => t.id.equals('txn-watch')))
          .write(TransactionsCompanion(amount: const Value(75.0)));

      final second = await stream.first;
      expect(second!.amount, 75.0);
    });

    test('watchByAccount returns only transactions for that account',
        () async {
      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-by',
          ownerUserId: 'usr-1',
          name: 'Other',
          accountType: 'bank',
        ),
      );

      await repo.create(TransactionsCompanion.insert(
        id: 'txn-acc1',
        accountId: 'acc-1',
        amount: 50.0,
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        occurredAt: DateTime(2026, 6, 19),
      ));
      await repo.create(TransactionsCompanion.insert(
        id: 'txn-acc2',
        accountId: 'acc-by',
        amount: 100.0,
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        occurredAt: DateTime(2026, 6, 19),
      ));

      final txns = await repo.watchByAccount('acc-1').first;
      expect(txns.length, 1);
      expect(txns.first.id, 'txn-acc1');
    });

    test('update reverses old balance and applies new balance', () async {
      await repo.create(TransactionsCompanion.insert(
        id: 'txn-upd',
        accountId: 'acc-1',
        amount: 100.0,
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        occurredAt: DateTime(2026, 6, 19),
      ));

      var account = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-1'))
            ..limit(1))
          .getSingle();
      expect(account.balance, 400.0);

      await repo.update(TransactionsCompanion(
        id: const Value('txn-upd'),
        amount: const Value(50.0),
      ));

      account = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-1'))
            ..limit(1))
          .getSingle();
      expect(account.balance, 450.0);
    });

    test('update with id absent throws ArgumentError', () async {
      expect(
        () => repo.update(TransactionsCompanion(amount: const Value(50.0))),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('update sets sync_status to pending_sync on transaction', () async {
      await repo.create(TransactionsCompanion.insert(
        id: 'txn-sync',
        accountId: 'acc-1',
        amount: 100.0,
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        occurredAt: DateTime(2026, 6, 19),
      ));

      await repo.update(TransactionsCompanion(
        id: const Value('txn-sync'),
        note: const Value('updated note'),
      ));

      final txn = await (db.select(db.transactions)
            ..where((t) => t.id.equals('txn-sync'))
            ..limit(1))
          .getSingle();
      expect(txn.syncStatus, 'pending_sync');
    });

    test('softDelete is idempotent', () async {
      await repo.create(TransactionsCompanion.insert(
        id: 'txn-idem',
        accountId: 'acc-1',
        amount: 100.0,
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        occurredAt: DateTime(2026, 6, 19),
      ));

      await repo.softDelete('txn-idem');
      await repo.softDelete('txn-idem');

      final account = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-1'))
            ..limit(1))
          .getSingle();
      expect(account.balance, 500.0);
    });
  });
}

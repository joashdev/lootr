import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/transfer_repo.dart';

void main() {
  late AppDatabase db;
  late TransferRepo repo;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = TransferRepo(db);

    await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
    await db.accounts.insertOne(
      AccountsCompanion.insert(
        id: 'acc-src',
        ownerUserId: 'usr-1',
        name: 'Source',
        accountType: 'bank',
        balance: const Value(1000.0),
      ),
    );
    await db.accounts.insertOne(
      AccountsCompanion.insert(
        id: 'acc-dst',
        ownerUserId: 'usr-1',
        name: 'Dest',
        accountType: 'cash',
        balance: const Value(500.0),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('TransferRepo', () {
    test('create atomically debits source and credits destination', () async {
      final id = await repo.create(TransfersCompanion.insert(
        id: 'xfer-1',
        sourceAccountId: 'acc-src',
        destinationAccountId: 'acc-dst',
        amount: 200.0,
        occurredAt: DateTime(2026, 6, 19),
      ));

      expect(id, 'xfer-1');

      final src = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-src'))
            ..limit(1))
          .getSingle();
      expect(src.balance, 800.0);
      expect(src.syncStatus, 'pending_sync');

      final dst = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-dst'))
            ..limit(1))
          .getSingle();
      expect(dst.balance, 700.0);
      expect(dst.syncStatus, 'pending_sync');
    });

    test('softDelete reverses both balance impacts', () async {
      await repo.create(TransfersCompanion.insert(
        id: 'xfer-1',
        sourceAccountId: 'acc-src',
        destinationAccountId: 'acc-dst',
        amount: 200.0,
        occurredAt: DateTime(2026, 6, 19),
      ));

      await repo.softDelete('xfer-1');

      final src = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-src'))
            ..limit(1))
          .getSingle();
      expect(src.balance, 1000.0);

      final dst = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-dst'))
            ..limit(1))
          .getSingle();
      expect(dst.balance, 500.0);

      final xfer = await (db.select(db.transfers)
            ..where((t) => t.id.equals('xfer-1'))
            ..limit(1))
          .getSingle();
      expect(xfer.deletedAt, isNotNull);
    });

    test('softDelete is idempotent', () async {
      await repo.create(TransfersCompanion.insert(
        id: 'xfer-idem',
        sourceAccountId: 'acc-src',
        destinationAccountId: 'acc-dst',
        amount: 200.0,
        occurredAt: DateTime(2026, 6, 19),
      ));

      await repo.softDelete('xfer-idem');
      await repo.softDelete('xfer-idem');

      final src = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-src'))
            ..limit(1))
          .getSingle();
      expect(src.balance, 1000.0);

      final dst = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-dst'))
            ..limit(1))
          .getSingle();
      expect(dst.balance, 500.0);
    });

    test('watchAll returns non-deleted transfers', () async {
      await repo.create(TransfersCompanion.insert(
        id: 'xfer-1',
        sourceAccountId: 'acc-src',
        destinationAccountId: 'acc-dst',
        amount: 100.0,
        occurredAt: DateTime(2026, 6, 19),
      ));
      await repo.create(TransfersCompanion.insert(
        id: 'xfer-2',
        sourceAccountId: 'acc-src',
        destinationAccountId: 'acc-dst',
        amount: 50.0,
        occurredAt: DateTime(2026, 6, 19),
      ));
      await repo.softDelete('xfer-2');

      final transfers = await repo.watchAll().first;
      expect(transfers.length, 1);
      expect(transfers.first.id, 'xfer-1');
    });

    test('watchByAccount returns transfers involving account', () async {
      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-other',
          ownerUserId: 'usr-1',
          name: 'Other',
          accountType: 'cash',
        ),
      );

      await repo.create(TransfersCompanion.insert(
        id: 'xfer-1',
        sourceAccountId: 'acc-src',
        destinationAccountId: 'acc-dst',
        amount: 100.0,
        occurredAt: DateTime(2026, 6, 19),
      ));
      await repo.create(TransfersCompanion.insert(
        id: 'xfer-2',
        sourceAccountId: 'acc-dst',
        destinationAccountId: 'acc-other',
        amount: 50.0,
        occurredAt: DateTime(2026, 6, 19),
      ));

      final srcXfers = await repo.watchByAccount('acc-src').first;
      expect(srcXfers.length, 1);
      expect(srcXfers.first.id, 'xfer-1');

      final dstXfers = await repo.watchByAccount('acc-dst').first;
      expect(dstXfers.length, 2);
    });

    test('watchById returns a transfer by id', () async {
      await repo.create(TransfersCompanion.insert(
        id: 'xfer-lookup',
        sourceAccountId: 'acc-src',
        destinationAccountId: 'acc-dst',
        amount: 125.0,
        occurredAt: DateTime(2026, 6, 19),
      ));

      final transfer = await repo.watchById('xfer-lookup').first;
      expect(transfer?.id, 'xfer-lookup');
      expect(transfer?.amount, 125.0);
    });

    test('update rebalances accounts and updates fee transaction', () async {
      await repo.create(TransfersCompanion.insert(
        id: 'xfer-update',
        sourceAccountId: 'acc-src',
        destinationAccountId: 'acc-dst',
        amount: 100.0,
        feeAmount: const Value(5.0),
        occurredAt: DateTime(2026, 6, 19),
      ));

      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-other',
          ownerUserId: 'usr-1',
          name: 'Other',
          accountType: 'cash',
          balance: const Value(300.0),
        ),
      );

      await repo.update(TransfersCompanion(
        id: const Value('xfer-update'),
        sourceAccountId: const Value('acc-dst'),
        destinationAccountId: const Value('acc-other'),
        amount: const Value(40.0),
        feeAmount: const Value(2.0),
        note: const Value('Updated'),
        occurredAt: Value(DateTime(2026, 6, 20)),
      ));

      final src = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-src'))
            ..limit(1))
          .getSingle();
      final dst = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-dst'))
            ..limit(1))
          .getSingle();
      final other = await (db.select(db.accounts)
            ..where((a) => a.id.equals('acc-other'))
            ..limit(1))
          .getSingle();

      expect(src.balance, 1000.0);
      expect(dst.balance, 458.0);
      expect(other.balance, 340.0);

      final feeTxn = await (db.select(db.transactions)
            ..where((t) => t.id.equals('txn-fee-xfer-update'))
            ..limit(1))
          .getSingle();
      expect(feeTxn.accountId, 'acc-dst');
      expect(feeTxn.amount, 2.0);
      expect(feeTxn.deletedAt, isNull);
    });
  });
}

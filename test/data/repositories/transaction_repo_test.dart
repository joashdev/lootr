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

    await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
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
    test(
      'create inserts row and atomically updates account balance (expense)',
      () async {
        final txId = await repo.create(
          TransactionsCompanion.insert(
            id: 'txn-1',
            accountId: 'acc-1',
            amount: 100.0,
            transactionDirection: 'expense',
            transactionMode: 'one_time',
            occurredAt: DateTime(2026, 6, 19),
          ),
        );

        expect(txId, 'txn-1');

        final txn =
            await (db.select(db.transactions)
                  ..where((t) => t.id.equals('txn-1'))
                  ..limit(1))
                .getSingle();
        expect(txn.amount, 100.0);
        expect(txn.transactionDirection, 'expense');

        final account =
            await (db.select(db.accounts)
                  ..where((a) => a.id.equals('acc-1'))
                  ..limit(1))
                .getSingle();
        expect(account.balance, 400.0);
        expect(account.syncStatus, 'pending_sync');
      },
    );

    test('create atomically updates account balance (income)', () async {
      await repo.create(
        TransactionsCompanion.insert(
          id: 'txn-inc',
          accountId: 'acc-1',
          amount: 200.0,
          transactionDirection: 'income',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 19),
        ),
      );

      final account =
          await (db.select(db.accounts)
                ..where((a) => a.id.equals('acc-1'))
                ..limit(1))
              .getSingle();
      expect(account.balance, 700.0);
    });

    test(
      'free-typed payee rolls back when the transaction write fails',
      () async {
        await expectLater(
          repo.createWithPayeeName(
            TransactionsCompanion.insert(
              id: 'txn-invalid',
              accountId: 'missing-account',
              amount: 100,
              transactionDirection: 'expense',
              transactionMode: 'one_time',
              occurredAt: DateTime(2026, 6, 19),
            ),
            'Corner Market',
          ),
          throwsA(anything),
        );

        expect(await db.select(db.transactions).get(), isEmpty);
        expect(await db.select(db.payees).get(), isEmpty);
      },
    );

    test('free-typed payee and transaction are saved together', () async {
      await repo.createWithPayeeName(
        TransactionsCompanion.insert(
          id: 'txn-with-payee',
          accountId: 'acc-1',
          amount: 100,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 19),
        ),
        'Corner Market',
      );

      final payee = await db.select(db.payees).getSingle();
      final transaction = await db.select(db.transactions).getSingle();
      expect(payee.normalizedName, 'corner market');
      expect(payee.displayName, 'Corner Market');
      expect(transaction.payeeId, payee.id);
    });

    test('softDelete reverts balance and sets deleted_at', () async {
      await repo.create(
        TransactionsCompanion.insert(
          id: 'txn-del',
          accountId: 'acc-1',
          amount: 100.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 19),
        ),
      );

      var account =
          await (db.select(db.accounts)
                ..where((a) => a.id.equals('acc-1'))
                ..limit(1))
              .getSingle();
      expect(account.balance, 400.0);

      await repo.softDelete('txn-del');

      account =
          await (db.select(db.accounts)
                ..where((a) => a.id.equals('acc-1'))
                ..limit(1))
              .getSingle();
      expect(account.balance, 500.0);
      expect(account.syncStatus, 'pending_sync');

      final txn =
          await (db.select(db.transactions)
                ..where((t) => t.id.equals('txn-del'))
                ..limit(1))
              .getSingle();
      expect(txn.deletedAt, isNotNull);
      expect(txn.syncStatus, 'pending_sync');
    });

    test(
      'restore clears deleted_at, re-applies balance, keeps same id',
      () async {
        await repo.create(
          TransactionsCompanion.insert(
            id: 'txn-restore',
            accountId: 'acc-1',
            amount: 100.0,
            transactionDirection: 'expense',
            transactionMode: 'one_time',
            occurredAt: DateTime(2026, 6, 19),
          ),
        );
        await repo.softDelete('txn-restore');

        await repo.restore('txn-restore');

        final txn =
            await (db.select(db.transactions)
                  ..where((t) => t.id.equals('txn-restore'))
                  ..limit(1))
                .getSingle();
        expect(txn.deletedAt, isNull);
        expect(txn.syncStatus, 'pending_sync');

        final account =
            await (db.select(db.accounts)
                  ..where((a) => a.id.equals('acc-1'))
                  ..limit(1))
                .getSingle();
        expect(account.balance, 400.0); // expense re-applied after undo
        expect(account.syncStatus, 'pending_sync');

        // No duplicate row was created.
        final all = await db.select(db.transactions).get();
        expect(all.length, 1);
      },
    );

    test(
      'restore is a no-op for non-deleted or missing transactions',
      () async {
        await repo.create(
          TransactionsCompanion.insert(
            id: 'txn-live',
            accountId: 'acc-1',
            amount: 100.0,
            transactionDirection: 'expense',
            transactionMode: 'one_time',
            occurredAt: DateTime(2026, 6, 19),
          ),
        );

        await repo.restore('txn-live'); // not deleted
        await repo.restore('txn-missing'); // does not exist

        final account =
            await (db.select(db.accounts)
                  ..where((a) => a.id.equals('acc-1'))
                  ..limit(1))
                .getSingle();
        expect(account.balance, 400.0); // unchanged
      },
    );

    test(
      'delete + restore of recurring-linked txn does not advance template',
      () async {
        await db.recurringTemplates.insertOne(
          RecurringTemplatesCompanion.insert(
            id: 'rec-1',
            accountId: 'acc-1',
            amount: 100.0,
            recurrenceRule: 'monthly',
            nextOccurrenceAt: Value(DateTime(2026, 7, 1)),
          ),
        );
        await repo.create(
          TransactionsCompanion.insert(
            id: 'txn-rec',
            accountId: 'acc-1',
            amount: 100.0,
            transactionDirection: 'expense',
            transactionMode: 'recurring',
            recurringTemplateId: const Value('rec-1'),
            occurredAt: DateTime(2026, 6, 19),
          ),
        );

        final afterCreate = await (db.select(
          db.recurringTemplates,
        )..where((t) => t.id.equals('rec-1'))).getSingle();
        final advancedOnce = afterCreate.nextOccurrenceAt;

        await repo.softDelete('txn-rec');
        await repo.restore('txn-rec');

        final afterUndo = await (db.select(
          db.recurringTemplates,
        )..where((t) => t.id.equals('rec-1'))).getSingle();
        // Undo must not re-run create() side effects.
        expect(afterUndo.nextOccurrenceAt, advancedOnce);
      },
    );

    test(
      'recurring-linked transaction advances quarterly at month end',
      () async {
        await db.recurringTemplates.insertOne(
          RecurringTemplatesCompanion.insert(
            id: 'rec-quarterly',
            accountId: 'acc-1',
            amount: 100.0,
            recurrenceRule: 'quarterly',
            nextOccurrenceAt: Value(DateTime(2026, 1, 31, 9, 45)),
          ),
        );

        await repo.create(
          TransactionsCompanion.insert(
            id: 'txn-quarterly',
            accountId: 'acc-1',
            amount: 100.0,
            transactionDirection: 'expense',
            transactionMode: 'recurring',
            recurringTemplateId: const Value('rec-quarterly'),
            occurredAt: DateTime(2026, 1, 31, 9, 45),
          ),
        );

        final template = await (db.select(
          db.recurringTemplates,
        )..where((row) => row.id.equals('rec-quarterly'))).getSingle();
        expect(template.nextOccurrenceAt, DateTime(2026, 4, 30, 9, 45));
      },
    );

    test('watchFiltered returns non-deleted transactions', () async {
      await repo.create(
        TransactionsCompanion.insert(
          id: 'txn-a',
          accountId: 'acc-1',
          amount: 50.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 19),
        ),
      );

      await repo.softDelete('txn-a');

      await repo.create(
        TransactionsCompanion.insert(
          id: 'txn-b',
          accountId: 'acc-1',
          amount: 30.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 19),
        ),
      );

      final txns = await repo
          .watchFiltered(const TransactionRepoFilters())
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

      await repo.create(
        TransactionsCompanion.insert(
          id: 'txn-1',
          accountId: 'acc-1',
          amount: 50.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 19),
        ),
      );

      await repo.create(
        TransactionsCompanion.insert(
          id: 'txn-2',
          accountId: 'acc-2',
          amount: 100.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 19),
        ),
      );

      final txns = await repo
          .watchFiltered(const TransactionRepoFilters(accountId: 'acc-1'))
          .first;

      expect(txns.length, 1);
      expect(txns.first.accountId, 'acc-1');
    });

    test(
      'watchFiltered applies currency and coefficient/scale bounds exactly',
      () async {
        await db.accounts.insertOne(
          AccountsCompanion.insert(
            id: 'acc-xts',
            ownerUserId: 'usr-1',
            name: 'Precise',
            accountType: 'bank',
            currencyCode: const Value('XTS'),
            currencyPrecision: const Value(12),
            balanceAtoms: const Value('0'),
          ),
        );
        await db.transactions.insertAll([
          TransactionsCompanion.insert(
            id: 'below',
            accountId: 'acc-xts',
            amount: 1,
            amountAtoms: const Value('999999999999'),
            amountScale: const Value(12),
            currencyCode: const Value('XTS'),
            transactionDirection: 'expense',
            transactionMode: 'one_time',
            occurredAt: DateTime(2026, 6, 19),
          ),
          TransactionsCompanion.insert(
            id: 'boundary',
            accountId: 'acc-xts',
            amount: 1,
            amountAtoms: const Value('1000000000000'),
            amountScale: const Value(12),
            currencyCode: const Value('XTS'),
            transactionDirection: 'expense',
            transactionMode: 'one_time',
            occurredAt: DateTime(2026, 6, 19),
          ),
          TransactionsCompanion.insert(
            id: 'php',
            accountId: 'acc-1',
            amount: 1,
            amountAtoms: const Value('100'),
            amountScale: const Value(2),
            currencyCode: const Value('PHP'),
            transactionDirection: 'expense',
            transactionMode: 'one_time',
            occurredAt: DateTime(2026, 6, 19),
          ),
        ]);

        final txns = await repo
            .watchFiltered(
              const TransactionRepoFilters(
                currencyCode: 'XTS',
                minAmountCoefficient: '100',
                minAmountScale: 2,
                maxAmountCoefficient: '1000000000000',
                maxAmountScale: 12,
              ),
            )
            .first;

        expect(txns.map((txn) => txn.id), ['boundary']);
      },
    );

    test('watchById emits when row changes', () async {
      await repo.create(
        TransactionsCompanion.insert(
          id: 'txn-watch',
          accountId: 'acc-1',
          amount: 50.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 19),
        ),
      );

      final stream = repo.watchById('txn-watch');
      final first = await stream.first;
      expect(first, isNotNull);
      expect(first!.amount, 50.0);

      await (db.update(db.transactions)..where((t) => t.id.equals('txn-watch')))
          .write(TransactionsCompanion(amount: const Value(75.0)));

      final second = await stream.first;
      expect(second!.amount, 75.0);
    });

    test('watchByAccount returns only transactions for that account', () async {
      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-by',
          ownerUserId: 'usr-1',
          name: 'Other',
          accountType: 'bank',
        ),
      );

      await repo.create(
        TransactionsCompanion.insert(
          id: 'txn-acc1',
          accountId: 'acc-1',
          amount: 50.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 19),
        ),
      );
      await repo.create(
        TransactionsCompanion.insert(
          id: 'txn-acc2',
          accountId: 'acc-by',
          amount: 100.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 19),
        ),
      );

      final txns = await repo.watchByAccount('acc-1').first;
      expect(txns.length, 1);
      expect(txns.first.id, 'txn-acc1');
    });

    test('update reverses old balance and applies new balance', () async {
      await repo.create(
        TransactionsCompanion.insert(
          id: 'txn-upd',
          accountId: 'acc-1',
          amount: 100.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 19),
        ),
      );

      var account =
          await (db.select(db.accounts)
                ..where((a) => a.id.equals('acc-1'))
                ..limit(1))
              .getSingle();
      expect(account.balance, 400.0);

      await repo.update(
        TransactionsCompanion(
          id: const Value('txn-upd'),
          amount: const Value(50.0),
        ),
      );

      account =
          await (db.select(db.accounts)
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
      await repo.create(
        TransactionsCompanion.insert(
          id: 'txn-sync',
          accountId: 'acc-1',
          amount: 100.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 19),
        ),
      );

      await repo.update(
        TransactionsCompanion(
          id: const Value('txn-sync'),
          note: const Value('updated note'),
        ),
      );

      final txn =
          await (db.select(db.transactions)
                ..where((t) => t.id.equals('txn-sync'))
                ..limit(1))
              .getSingle();
      expect(txn.syncStatus, 'pending_sync');
    });

    test('softDelete is idempotent', () async {
      await repo.create(
        TransactionsCompanion.insert(
          id: 'txn-idem',
          accountId: 'acc-1',
          amount: 100.0,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 19),
        ),
      );

      await repo.softDelete('txn-idem');
      await repo.softDelete('txn-idem');

      final account =
          await (db.select(db.accounts)
                ..where((a) => a.id.equals('acc-1'))
                ..limit(1))
              .getSingle();
      expect(account.balance, 500.0);
    });

    test(
      'bulk recategorize applies all rows and rolls back together',
      () async {
        await db.categories.insertOne(
          CategoriesCompanion.insert(
            id: 'cat-2',
            name: 'Dining',
            categoryGroup: 'expense',
          ),
        );
        for (final id in ['txn-bulk-1', 'txn-bulk-2']) {
          await repo.create(
            TransactionsCompanion.insert(
              id: id,
              accountId: 'acc-1',
              categoryId: const Value('cat-1'),
              amount: 10,
              transactionDirection: 'expense',
              transactionMode: 'one_time',
              occurredAt: DateTime(2026, 6, 19),
            ),
          );
        }

        final plan = await repo.preflightBulk(
          const TransactionBulkRequest(
            transactionIds: {'txn-bulk-1', 'txn-bulk-2'},
            operation: TransactionBulkOperation.recategorize,
            targetId: 'cat-2',
          ),
        );
        expect(plan.canApply, isTrue);

        final undo = await repo.applyBulk(plan);
        var rows = await (db.select(
          db.transactions,
        )..where((row) => row.id.isIn(plan.transactionIds))).get();
        expect(rows.map((row) => row.categoryId).toSet(), {'cat-2'});

        await undo.rollback();
        rows = await (db.select(
          db.transactions,
        )..where((row) => row.id.isIn(plan.transactionIds))).get();
        expect(rows.map((row) => row.categoryId).toSet(), {'cat-1'});
      },
    );

    test(
      'bulk move preserves total balances and supports atomic undo',
      () async {
        await db.accounts.insertOne(
          AccountsCompanion.insert(
            id: 'acc-2',
            ownerUserId: 'usr-1',
            name: 'Bank',
            accountType: 'bank',
            balance: const Value(100),
          ),
        );
        for (final entry in const {
          'txn-move-1': 25.0,
          'txn-move-2': 35.0,
        }.entries) {
          await repo.create(
            TransactionsCompanion.insert(
              id: entry.key,
              accountId: 'acc-1',
              amount: entry.value,
              transactionDirection: 'expense',
              transactionMode: 'one_time',
              occurredAt: DateTime(2026, 6, 19),
            ),
          );
        }
        final plan = await repo.preflightBulk(
          const TransactionBulkRequest(
            transactionIds: {'txn-move-1', 'txn-move-2'},
            operation: TransactionBulkOperation.moveAccount,
            targetId: 'acc-2',
          ),
        );

        final undo = await repo.applyBulk(plan);
        var accounts = await db.select(db.accounts).get();
        expect(accounts.firstWhere((row) => row.id == 'acc-1').balance, 500);
        expect(accounts.firstWhere((row) => row.id == 'acc-2').balance, 40);

        await undo.rollback();
        accounts = await db.select(db.accounts).get();
        expect(accounts.firstWhere((row) => row.id == 'acc-1').balance, 440);
        expect(accounts.firstWhere((row) => row.id == 'acc-2').balance, 100);
      },
    );

    test(
      'bulk delete changes every row and restores every row on undo',
      () async {
        for (final id in ['txn-delete-1', 'txn-delete-2']) {
          await repo.create(
            TransactionsCompanion.insert(
              id: id,
              accountId: 'acc-1',
              amount: 20,
              transactionDirection: 'expense',
              transactionMode: 'one_time',
              occurredAt: DateTime(2026, 6, 19),
            ),
          );
        }
        final plan = await repo.preflightBulk(
          const TransactionBulkRequest(
            transactionIds: {'txn-delete-1', 'txn-delete-2'},
            operation: TransactionBulkOperation.delete,
          ),
        );

        final undo = await repo.applyBulk(plan);
        var visible = await repo
            .watchFiltered(const TransactionRepoFilters())
            .first;
        expect(
          visible.where((row) => plan.transactionIds.contains(row.id)),
          isEmpty,
        );
        expect((await db.select(db.accounts).getSingle()).balance, 500);

        await undo.rollback();
        visible = await repo
            .watchFiltered(const TransactionRepoFilters())
            .first;
        expect(
          visible.where((row) => plan.transactionIds.contains(row.id)).length,
          2,
        );
        expect((await db.select(db.accounts).getSingle()).balance, 460);
      },
    );

    test(
      'bulk preflight reports every impossible row before applying',
      () async {
        await db.accounts.insertOne(
          AccountsCompanion.insert(
            id: 'acc-eur',
            ownerUserId: 'usr-1',
            name: 'Euro',
            accountType: 'bank',
            currencyCode: const Value('EUR'),
          ),
        );
        await repo.create(
          TransactionsCompanion.insert(
            id: 'txn-preflight',
            accountId: 'acc-1',
            amount: 20,
            transactionDirection: 'expense',
            transactionMode: 'one_time',
            occurredAt: DateTime(2026, 6, 19),
          ),
        );

        final plan = await repo.preflightBulk(
          const TransactionBulkRequest(
            transactionIds: {'txn-preflight', 'transfer-not-supported'},
            operation: TransactionBulkOperation.moveAccount,
            targetId: 'acc-eur',
          ),
        );

        expect(plan.canApply, isFalse);
        expect(
          plan.issues.map((issue) => issue.transactionId),
          containsAll(['txn-preflight', 'transfer-not-supported']),
        );
        await expectLater(
          repo.applyBulk(plan),
          throwsA(isA<TransactionBulkPreflightException>()),
        );
        expect((await db.select(db.accounts).get()).first.balance, 480);
      },
    );
  });
}

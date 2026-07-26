import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/recurring_occurrence_repo.dart';
import 'package:lootr/data/repositories/recurring_occurrence_service.dart';
import 'package:lootr/data/repositories/transaction_repo.dart';
import 'package:lootr/domain/entities/transaction.dart';

void main() {
  late AppDatabase db;
  late RecurringOccurrenceService service;

  setUp(() async {
    db = AppDatabase.inMemory();
    service = RecurringOccurrenceService(
      db,
      TransactionRepo(db),
      RecurringOccurrenceRepo(db),
    );
    await db.users.insertOne(UsersCompanion.insert(id: 'user'));
    await db.accounts.insertOne(
      AccountsCompanion.insert(
        id: 'account',
        ownerUserId: 'user',
        name: 'Wallet',
        accountType: 'cash',
        balance: const Value(1000),
        balanceAtoms: const Value('100000'),
        currencyCode: const Value('USD'),
        currencyPrecision: const Value(2),
      ),
    );
    await db.recurringTemplates.insertOne(
      RecurringTemplatesCompanion.insert(
        id: 'series',
        accountId: 'account',
        amount: 25,
        amountAtoms: const Value('2500'),
        amountScale: const Value(2),
        currencyCode: const Value('USD'),
        transactionDirection: const Value('expense'),
        recurrenceRule: 'monthly',
        nextOccurrenceAt: Value(DateTime(2026, 7, 20)),
      ),
    );
    await db.recurringOccurrences.insertOne(
      RecurringOccurrencesCompanion.insert(
        id: 'occurrence',
        recurringTemplateId: 'series',
        status: 'due',
        originalDueAt: DateTime(2026, 7, 20),
        dueAt: DateTime(2026, 7, 20),
        amountAtoms: '2500',
        amountScale: 2,
        currencyCode: 'USD',
      ),
    );
  });

  tearDown(() => db.close());

  test('Pay atomically creates and links one transaction', () async {
    final transactionId = await service.pay(
      'occurrence',
      _payment(),
      resolvedAt: DateTime(2026, 7, 20, 12),
    );

    final occurrence =
        await (db.recurringOccurrences.select()
              ..where((row) => row.id.equals('occurrence')))
            .getSingle();
    final transaction = await db.transactions.select().getSingle();
    expect(occurrence.status, 'paid');
    expect(occurrence.transactionId, transactionId);
    expect(transaction.id, transactionId);
    expect(transaction.recurringTemplateId, 'series');
    expect(transaction.amountAtoms, '3000');
    expect(transaction.title, 'Edited before confirmation');
    expect(
      await db.recurringOccurrences.select().get().then(
        (rows) => rows.where((row) => row.status == 'due').length,
      ),
      1,
    );
  });

  test(
    'Skip creates no transaction and keeps a successor occurrence',
    () async {
      await service.skip('occurrence', resolvedAt: DateTime(2026, 7, 20, 12));

      final occurrences = await db.recurringOccurrences.select().get();
      expect(
        occurrences.singleWhere((row) => row.id == 'occurrence').status,
        'skipped',
      );
      expect(occurrences.where((row) => row.status == 'due'), hasLength(1));
      expect(await db.transactions.select().get(), isEmpty);
    },
  );

  test('resolved occurrence cannot create a second transaction', () async {
    await service.pay('occurrence', _payment());

    expect(() => service.pay('occurrence', _payment()), throwsStateError);
    expect(await db.transactions.select().get(), hasLength(1));
  });

  test('failed Pay leaves the occurrence and ledger unchanged', () async {
    await (db.update(db.recurringOccurrences)
          ..where((row) => row.id.equals('occurrence')))
        .write(const RecurringOccurrencesCompanion(currencyCode: Value('EUR')));

    await expectLater(
      service.pay('occurrence', _payment()),
      throwsA(isA<ArgumentError>()),
    );

    expect(
      await db.recurringOccurrences.select().getSingle().then(
        (row) => row.status,
      ),
      'due',
    );
    expect(await db.transactions.select().get(), isEmpty);
  });

  test('backfills missing occurrences for existing templates', () async {
    await db.recurringOccurrences.deleteAll();

    await service.ensureNextOccurrences();

    final occurrence = await db.recurringOccurrences.select().getSingle();
    expect(occurrence.recurringTemplateId, 'series');
    expect(occurrence.dueAt, DateTime(2026, 7, 20));
  });

  test(
    'resynchronizes template date to the earliest unresolved occurrence',
    () async {
      await (db.update(
        db.recurringTemplates,
      )..where((row) => row.id.equals('series'))).write(
        RecurringTemplatesCompanion(
          nextOccurrenceAt: Value(DateTime(2026, 8, 20)),
        ),
      );

      await service.ensureNextOccurrence('series');

      final template = await db.recurringTemplates.select().getSingle();
      expect(template.nextOccurrenceAt, DateTime(2026, 7, 20));
    },
  );
}

Transaction _payment() {
  final now = DateTime(2026, 7, 20, 12);
  return Transaction(
    id: 'confirmed-payment',
    accountId: 'account',
    recurringTemplateId: 'series',
    amount: 30,
    amountAtoms: '3000',
    amountScale: 2,
    currencyCode: 'USD',
    title: 'Edited before confirmation',
    direction: 'expense',
    mode: 'recurring',
    occurredAt: DateTime(2026, 7, 20),
    createdAt: now,
    updatedAt: now,
  );
}

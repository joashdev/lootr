import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/recurring_occurrence_repo.dart';

void main() {
  late AppDatabase db;
  late RecurringOccurrenceRepo repo;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = RecurringOccurrenceRepo(db);
    await db.users.insertOne(UsersCompanion.insert(id: 'user'));
    await db.accounts.insertOne(
      AccountsCompanion.insert(
        id: 'account',
        ownerUserId: 'user',
        name: 'Account',
        accountType: 'cash',
      ),
    );
    await db.recurringTemplates.insertOne(
      RecurringTemplatesCompanion.insert(
        id: 'series',
        accountId: 'account',
        amount: 1,
        amountAtoms: const Value('100'),
        amountScale: const Value(2),
        currencyCode: const Value('USD'),
        recurrenceRule: 'monthly',
      ),
    );
  });

  tearDown(() => db.close());

  test('queries due/unpaid lifecycle in due-time order', () async {
    await _occurrence(
      db,
      id: 'later',
      status: 'unpaid',
      dueAt: DateTime(2026, 7, 2),
    );
    await _occurrence(
      db,
      id: 'earlier',
      status: 'due',
      dueAt: DateTime(2026, 7),
    );
    await _occurrence(db, id: 'future', status: 'due', dueAt: DateTime(2027));

    final rows = await repo.listDueAtOrBefore(DateTime(2026, 7, 3));
    expect(rows.map((row) => row.id), ['earlier', 'later']);
  });

  test('resolves occurrence without mutating due time or provenance', () async {
    final original = DateTime(2026, 6, 30, 23);
    await _occurrence(
      db,
      id: 'occurrence',
      status: 'due',
      dueAt: DateTime(2026, 7),
      originalDueAt: original,
    );
    await db.transactions.insertOne(
      TransactionsCompanion.insert(
        id: 'transaction',
        accountId: 'account',
        amount: 1,
        transactionDirection: 'expense',
        transactionMode: 'recurring',
        occurredAt: DateTime(2026, 7),
      ),
    );

    final resolvedAt = DateTime(2026, 7, 1, 1);
    await repo.markPaid(
      'occurrence',
      transactionId: 'transaction',
      resolvedAt: resolvedAt,
    );
    final row = await db.recurringOccurrences.select().getSingle();

    expect(row.status, 'paid');
    expect(row.transactionId, 'transaction');
    expect(row.resolvedAt, resolvedAt);
    expect(row.originalDueAt, original);
    expect(row.sourceSeriesKey, 'source-series');
    expect(row.sourceOccurrenceKey, 'source-occurrence');
  });

  test('terminal states reject later transitions', () async {
    await _occurrence(
      db,
      id: 'occurrence',
      status: 'due',
      dueAt: DateTime(2026, 7),
    );
    await repo.markSkipped('occurrence', resolvedAt: DateTime(2026, 7, 2));

    expect(
      () => repo.markDismissed('occurrence', resolvedAt: DateTime(2026, 7, 3)),
      throwsStateError,
    );
  });
}

Future<void> _occurrence(
  AppDatabase db, {
  required String id,
  required String status,
  required DateTime dueAt,
  DateTime? originalDueAt,
}) {
  return db.recurringOccurrences.insertOne(
    RecurringOccurrencesCompanion.insert(
      id: id,
      recurringTemplateId: 'series',
      status: status,
      originalDueAt: originalDueAt ?? dueAt,
      dueAt: dueAt,
      amountAtoms: '100',
      amountScale: 2,
      currencyCode: 'USD',
      sourceSeriesKey: const Value('source-series'),
      sourceOccurrenceKey: const Value('source-occurrence'),
    ),
  );
}

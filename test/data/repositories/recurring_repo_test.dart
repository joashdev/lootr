import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/recurring_repo.dart';

void main() {
  late AppDatabase db;
  late RecurringRepo repo;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = RecurringRepo(db);

    await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
    await db.accounts.insertOne(
      AccountsCompanion.insert(
        id: 'acc-1',
        ownerUserId: 'usr-1',
        name: 'Cash',
        accountType: 'cash',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('RecurringRepo', () {
    test('create inserts and returns id', () async {
      final id = await repo.create(RecurringTemplatesCompanion.insert(
        id: 'rec-1',
        accountId: 'acc-1',
        amount: 100.0,
        recurrenceRule: 'monthly',
      ));
      expect(id, 'rec-1');
    });

    test('watchAll returns non-deleted templates', () async {
      await repo.create(RecurringTemplatesCompanion.insert(
        id: 'rec-1',
        accountId: 'acc-1',
        amount: 100.0,
        recurrenceRule: 'monthly',
      ));

      final templates = await repo.watchAll().first;
      expect(templates.length, 1);
    });

    test('watchDue returns templates with nextOccurrenceAt <= before', () async {
      final past = DateTime.now().subtract(const Duration(days: 1));
      final future = DateTime.now().add(const Duration(days: 30));

      await repo.create(RecurringTemplatesCompanion.insert(
        id: 'rec-past',
        accountId: 'acc-1',
        amount: 100.0,
        recurrenceRule: 'monthly',
        nextOccurrenceAt: Value(past),
      ));
      await repo.create(RecurringTemplatesCompanion.insert(
        id: 'rec-future',
        accountId: 'acc-1',
        amount: 200.0,
        recurrenceRule: 'weekly',
        nextOccurrenceAt: Value(future),
      ));

      final due = await repo.watchDue(before: DateTime.now()).first;
      expect(due.length, 1);
      expect(due.first.id, 'rec-past');
    });

    test('watchDue excludes autoCreateDisabled templates', () async {
      final past = DateTime.now().subtract(const Duration(days: 1));

      await repo.create(RecurringTemplatesCompanion.insert(
        id: 'rec-1',
        accountId: 'acc-1',
        amount: 100.0,
        recurrenceRule: 'monthly',
        nextOccurrenceAt: Value(past),
        autoCreateDisabled: const Value(true),
      ));

      final due = await repo.watchDue(before: DateTime.now()).first;
      expect(due.length, 0);
    });

    test('advanceNextOccurrence computes next date from rule', () async {
      final today = DateTime.now();
      await repo.create(RecurringTemplatesCompanion.insert(
        id: 'rec-1',
        accountId: 'acc-1',
        amount: 100.0,
        recurrenceRule: 'monthly',
        nextOccurrenceAt: Value(today),
      ));

      await repo.advanceNextOccurrence('rec-1');

      final template = await (db.select(db.recurringTemplates)..limit(1))
          .getSingle();
      expect(template.nextOccurrenceAt, isNotNull);
      expect(template.nextOccurrenceAt!.isAfter(today), true);
    });
  });
}

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/financial_event_repo.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.inMemory();
    await db.users.insertOne(UsersCompanion.insert(id: 'user'));
    await db.goals.insertOne(
      GoalsCompanion.insert(
        id: 'goal',
        ownerUserId: 'user',
        name: 'Goal',
        goalType: 'custom',
        targetAmount: 1,
        targetAmountAtoms: const Value('100000'),
        currentAmountAtoms: const Value('0'),
        amountScale: const Value(4),
        currencyCode: const Value('USD'),
      ),
    );
    await db.debtRecords.insertOne(
      DebtRecordsCompanion.insert(
        id: 'debt',
        ownerUserId: 'user',
        counterpartyName: 'Counterparty',
        debtDirection: 'borrowed',
        amount: 1,
        remainingBalance: 1,
        amountAtoms: const Value('100000'),
        remainingBalanceAtoms: const Value('100000'),
        amountScale: const Value(4),
        currencyCode: const Value('USD'),
        status: 'active',
      ),
    );
  });

  tearDown(() => db.close());

  test(
    'goal events are append-only and aggregate exactly by currency',
    () async {
      final repo = GoalContributionEventRepo(db);
      await repo.append(
        GoalContributionEventsCompanion.insert(
          id: 'one',
          goalId: 'goal',
          amountAtoms: '10001',
          amountScale: 4,
          currencyCode: 'USD',
          occurredAt: DateTime(2026),
        ),
      );
      await repo.append(
        GoalContributionEventsCompanion.insert(
          id: 'two',
          goalId: 'goal',
          eventType: const Value('withdrawal'),
          amountAtoms: '1',
          amountScale: 4,
          currencyCode: 'USD',
          occurredAt: DateTime(2026, 2),
        ),
      );
      await repo.append(
        GoalContributionEventsCompanion.insert(
          id: 'tiny',
          goalId: 'goal',
          amountAtoms: '1',
          amountScale: 12,
          currencyCode: 'USD',
          occurredAt: DateTime(2026, 3),
        ),
      );

      final summary = await repo.summarize('goal');
      expect(summary.netByCurrency['USD']!.toDecimalString(), '1.000000000001');
      expect(
        () => repo.append(
          GoalContributionEventsCompanion.insert(
            id: 'one',
            goalId: 'goal',
            amountAtoms: '1',
            amountScale: 4,
            currencyCode: 'USD',
            occurredAt: DateTime(2027),
          ),
        ),
        throwsA(anything),
      );
    },
  );

  test('debt payments and refunds produce an exact net payment', () async {
    final repo = DebtPaymentEventRepo(db);
    await repo.append(
      DebtPaymentEventsCompanion.insert(
        id: 'payment',
        debtRecordId: 'debt',
        amountAtoms: '10005',
        amountScale: 4,
        currencyCode: 'USD',
        occurredAt: DateTime(2026),
      ),
    );
    await repo.append(
      DebtPaymentEventsCompanion.insert(
        id: 'refund',
        debtRecordId: 'debt',
        eventType: const Value('refund'),
        amountAtoms: '5',
        amountScale: 4,
        currencyCode: 'USD',
        occurredAt: DateTime(2026, 2),
      ),
    );

    final summary = await repo.summarize('debt');
    expect(summary.netByCurrency['USD']!.toDecimalString(), '1.0000');
    expect((await repo.watchForDebt('debt').first).length, 2);
  });
}

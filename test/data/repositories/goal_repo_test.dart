import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/goal_repo.dart';
import 'package:lootr/domain/entities/mappers.dart';
import 'package:lootr/domain/value_objects/exact_money.dart';
import 'package:lootr/domain/value_objects/field_types.dart';

void main() {
  late AppDatabase db;
  late GoalRepo repo;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = GoalRepo(db);

    await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
  });

  tearDown(() async {
    await db.close();
  });

  group('GoalRepo', () {
    test('create inserts and returns id', () async {
      final id = await repo.create(
        GoalsCompanion.insert(
          id: 'goal-1',
          ownerUserId: 'usr-1',
          name: 'Vacation',
          goalType: 'travel',
          targetAmount: 50000.0,
        ),
      );
      expect(id, 'goal-1');
    });

    test('watchAll returns non-deleted goals', () async {
      await repo.create(
        GoalsCompanion.insert(
          id: 'goal-1',
          ownerUserId: 'usr-1',
          name: 'Vacation',
          goalType: 'travel',
          targetAmount: 50000.0,
        ),
      );

      final goals = await repo.watchAll().first;
      expect(goals.length, 1);
      expect(goals.first.name, 'Vacation');
    });

    test('watchAll preserves exact amount currency and scale', () async {
      await repo.create(
        GoalsCompanion.insert(
          id: 'goal-exact',
          ownerUserId: 'usr-1',
          name: 'Exact goal',
          goalType: 'custom',
          targetAmount: 1.2345,
          currentAmount: const Value(0.0001),
          targetAmountAtoms: const Value('12345'),
          currentAmountAtoms: const Value('1'),
          amountScale: const Value(4),
          currencyCode: const Value('USD'),
        ),
      );

      final goal = (await repo.watchAll().first).single.toEntity();
      expect(goal.exactTargetAmount.toDecimalString(), '1.2345');
      expect(goal.exactCurrentAmount.toDecimalString(), '0.0001');
      expect(goal.currencyCode, 'USD');
    });

    test('addContribution increases currentAmount', () async {
      await repo.create(
        GoalsCompanion.insert(
          id: 'goal-1',
          ownerUserId: 'usr-1',
          name: 'Vacation',
          goalType: 'travel',
          targetAmount: 50000.0,
        ),
      );

      await repo.addContribution('goal-1', 5000.0);
      await repo.addContribution('goal-1', 3000.0);

      final goal = await (db.select(db.goals)..limit(1)).getSingle();
      expect(goal.currentAmount, 8000.0);
      expect(goal.currentAmountAtoms, '800000');
      final events = await db.select(db.goalContributionEvents).get();
      expect(events, hasLength(2));
      expect(events.map((event) => event.amountAtoms), ['500000', '300000']);
    });

    test(
      'exact contribution and linked transaction commit atomically',
      () async {
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
          GoalsCompanion.insert(
            id: 'goal-linked',
            ownerUserId: 'usr-1',
            name: 'Synthetic goal',
            goalType: 'custom',
            targetAmount: 2,
            currentAmount: const Value(0),
            targetAmountAtoms: const Value('20000'),
            currentAmountAtoms: const Value('0'),
            amountScale: const Value(4),
            currencyCode: const Value('XAA'),
          ),
        );
        final amount = ExactMoney.parse('0.1250', 'XAA');
        await repo.addContributionExact(
          'goal-linked',
          amount,
          transaction: TransactionsCompanion.insert(
            id: 'goal-transaction',
            accountId: 'account-1',
            amount: amount.toDouble(),
            amountAtoms: Value(amount.coefficient.toString()),
            amountScale: Value(amount.scale),
            currencyCode: Value(amount.currencyCode),
            transactionDirection: TransactionDirection.expense,
            transactionMode: TransactionMode.oneTime,
            occurredAt: DateTime.utc(2026),
          ),
        );

        final event = await db.select(db.goalContributionEvents).getSingle();
        expect(event.transactionId, 'goal-transaction');
        expect(event.amountAtoms, '1250');
        expect(await db.select(db.transactions).get(), hasLength(1));
      },
    );

    test('update modifies goal fields', () async {
      await repo.create(
        GoalsCompanion.insert(
          id: 'goal-1',
          ownerUserId: 'usr-1',
          name: 'Vacation',
          goalType: 'travel',
          targetAmount: 50000.0,
        ),
      );

      await repo.update(
        GoalsCompanion(
          id: const Value('goal-1'),
          targetAmount: const Value(60000.0),
          name: const Value('World Tour'),
        ),
      );

      final goal = await (db.select(db.goals)..limit(1)).getSingle();
      expect(goal.targetAmount, 60000.0);
      expect(goal.name, 'World Tour');
    });
  });
}

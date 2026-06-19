import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/goal_repo.dart';

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
      final id = await repo.create(GoalsCompanion.insert(
        id: 'goal-1',
        ownerUserId: 'usr-1',
        name: 'Vacation',
        goalType: 'travel',
        targetAmount: 50000.0,
      ));
      expect(id, 'goal-1');
    });

    test('watchAll returns non-deleted goals', () async {
      await repo.create(GoalsCompanion.insert(
        id: 'goal-1',
        ownerUserId: 'usr-1',
        name: 'Vacation',
        goalType: 'travel',
        targetAmount: 50000.0,
      ));

      final goals = await repo.watchAll().first;
      expect(goals.length, 1);
      expect(goals.first.name, 'Vacation');
    });

    test('addContribution increases currentAmount', () async {
      await repo.create(GoalsCompanion.insert(
        id: 'goal-1',
        ownerUserId: 'usr-1',
        name: 'Vacation',
        goalType: 'travel',
        targetAmount: 50000.0,
      ));

      await repo.addContribution('goal-1', 5000.0);
      await repo.addContribution('goal-1', 3000.0);

      final goal = await (db.select(db.goals)..limit(1)).getSingle();
      expect(goal.currentAmount, 8000.0);
    });

    test('update modifies goal fields', () async {
      await repo.create(GoalsCompanion.insert(
        id: 'goal-1',
        ownerUserId: 'usr-1',
        name: 'Vacation',
        goalType: 'travel',
        targetAmount: 50000.0,
      ));

      await repo.update(GoalsCompanion(
        id: const Value('goal-1'),
        targetAmount: const Value(60000.0),
        name: const Value('World Tour'),
      ));

      final goal = await (db.select(db.goals)..limit(1)).getSingle();
      expect(goal.targetAmount, 60000.0);
      expect(goal.name, 'World Tour');
    });
  });
}

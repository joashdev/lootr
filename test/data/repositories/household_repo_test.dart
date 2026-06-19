import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/household_repo.dart';

void main() {
  late AppDatabase db;
  late HouseholdRepo repo;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = HouseholdRepo(db);

    await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
    await db.users.insertOne(UsersCompanion.insert(id: 'usr-2'));
  });

  tearDown(() async {
    await db.close();
  });

  group('HouseholdRepo', () {
    test('create inserts and returns id', () async {
      final id = await repo.create(HouseholdsCompanion.insert(
        id: 'hh-1',
        name: 'My Household',
        createdByUserId: 'usr-1',
      ));
      expect(id, 'hh-1');
    });

    test('watchAll returns non-deleted households', () async {
      await repo.create(HouseholdsCompanion.insert(
        id: 'hh-1',
        name: 'My Household',
        createdByUserId: 'usr-1',
      ));

      final households = await repo.watchAll().first;
      expect(households.length, 1);
      expect(households.first.name, 'My Household');
    });

    test('watchById returns household or null', () async {
      await repo.create(HouseholdsCompanion.insert(
        id: 'hh-1',
        name: 'My Household',
        createdByUserId: 'usr-1',
      ));

      final found = await repo.watchById('hh-1').first;
      expect(found, isNotNull);
      expect(found!.name, 'My Household');

      final missing = await repo.watchById('nope').first;
      expect(missing, isNull);
    });

    test('addMember inserts member and watchMembers returns them', () async {
      await repo.create(HouseholdsCompanion.insert(
        id: 'hh-1',
        name: 'My Household',
        createdByUserId: 'usr-1',
      ));

      await repo.addMember(HouseholdMembersCompanion.insert(
        id: 'hm-1',
        householdId: 'hh-1',
        userId: 'usr-1',
        role: 'owner',
      ));
      await repo.addMember(HouseholdMembersCompanion.insert(
        id: 'hm-2',
        householdId: 'hh-1',
        userId: 'usr-2',
        role: 'member',
      ));

      final members = await repo.watchMembers('hh-1').first;
      expect(members.length, 2);
      expect(members.map((m) => m.role), containsAll(['owner', 'member']));
    });

    test('updateMemberRole changes role', () async {
      await repo.create(HouseholdsCompanion.insert(
        id: 'hh-1',
        name: 'My Household',
        createdByUserId: 'usr-1',
      ));
      await repo.addMember(HouseholdMembersCompanion.insert(
        id: 'hm-1',
        householdId: 'hh-1',
        userId: 'usr-1',
        role: 'member',
      ));

      await repo.updateMemberRole('hm-1', 'owner');

      final members = await repo.watchMembers('hh-1').first;
      expect(members.first.role, 'owner');
    });
  });
}

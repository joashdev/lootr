import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/user_repo.dart';

void main() {
  late AppDatabase db;
  late UserRepo repo;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = UserRepo(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('UserRepo', () {
    test('create inserts and returns id', () async {
      final id = await repo.create(UsersCompanion.insert(id: 'usr-1'));
      expect(id, 'usr-1');
    });

    test('watchCurrentUser returns first user or null', () async {
      var user = await repo.watchCurrentUser().first;
      expect(user, isNull);

      await repo.create(UsersCompanion.insert(id: 'usr-1'));

      user = await repo.watchCurrentUser().first;
      expect(user, isNotNull);
      expect(user!.id, 'usr-1');
    });

    test('update modifies user fields', () async {
      await repo.create(UsersCompanion.insert(id: 'usr-1'));

      await repo.update(
        UsersCompanion(
          id: const Value('usr-1'),
          displayName: const Value('Test User'),
          currencyCode: const Value('USD'),
        ),
      );

      final user = await (db.select(db.users)..limit(1)).getSingle();
      expect(user.displayName, 'Test User');
      expect(user.currencyCode, 'USD');
    });

    test('creates a personal profile when only a sample user exists', () async {
      await repo.create(UsersCompanion.insert(id: 'demo-user-1'));

      expect(await repo.getCurrentUser(), isNull);
      await repo.saveProfile(displayName: 'Personal User', currencyCode: 'USD');

      final profile = await repo.watchCurrentUser().first;
      expect(profile?.id, UserRepo.localProfileId);
      expect(profile?.displayName, 'Personal User');
      expect(profile?.currencyCode, 'USD');
      final sample = await (db.select(
        db.users,
      )..where((row) => row.id.equals('demo-user-1'))).getSingle();
      expect(sample.displayName, isNull);
      expect(sample.currencyCode, 'PHP');
    });

    test('updateAiEnabled toggles aiEnabled flag', () async {
      await repo.create(UsersCompanion.insert(id: 'usr-1'));

      var user = await (db.select(db.users)..limit(1)).getSingle();
      expect(user.aiEnabled, false);

      await repo.updateAiEnabled(true);

      user = await (db.select(db.users)..limit(1)).getSingle();
      expect(user.aiEnabled, true);

      await repo.updateAiEnabled(false);

      user = await (db.select(db.users)..limit(1)).getSingle();
      expect(user.aiEnabled, false);
    });
  });
}

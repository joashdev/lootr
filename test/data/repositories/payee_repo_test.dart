import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/payee_repo.dart';

void main() {
  late AppDatabase db;
  late PayeeRepo repo;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = PayeeRepo(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('PayeeRepo', () {
    test('createOrGet creates new payee if not found', () async {
      final payee = await repo.createOrGet('starbucks');

      expect(payee.normalizedName, 'starbucks');
      expect(payee.id, startsWith('pay-'));
    });

    test('createOrGet returns existing payee if found', () async {
      final first = await repo.createOrGet('starbucks');
      final second = await repo.createOrGet('starbucks');

      expect(second.id, first.id);
      expect(second.normalizedName, 'starbucks');
    });

    test('findByNormalizedName returns payee or null', () async {
      await repo.createOrGet('starbucks');

      final found = await repo.findByNormalizedName('starbucks');
      expect(found, isNotNull);
      expect(found!.normalizedName, 'starbucks');

      final missing = await repo.findByNormalizedName('unknown');
      expect(missing, isNull);
    });

    test('watchAll returns all non-deleted payees', () async {
      await repo.createOrGet('merchant-a');
      await repo.createOrGet('merchant-b');

      final payees = await repo.watchAll().first;
      expect(payees.length, 2);
    });

    test('watchById returns payee or null', () async {
      final created = await repo.createOrGet('starbucks');

      final found = await repo.watchById(created.id).first;
      expect(found, isNotNull);
      expect(found!.normalizedName, 'starbucks');

      final missing = await repo.watchById('nope').first;
      expect(missing, isNull);
    });
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/data/database/app_database.dart';

import 'test_database.dart';

ProviderContainer createTestContainer({AppDatabase? db}) {
  final ownsDb = db == null;
  final testDb = db ?? createTestDb();
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(testDb)],
  );

  addTearDown(container.dispose);
  if (ownsDb) {
    addTearDown(testDb.close);
  }
  return container;
}

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/data/database/app_database.dart';

void main() {
  test('failed reopen invokes recovery before exposing a database', () async {
    final initial = AppDatabase.inMemory();
    final failed = AppDatabase(
      NativeDatabase.memory(
        setup: (_) => throw StateError('synthetic reopen failure'),
      ),
    );
    final recovered = AppDatabase.inMemory();
    final databases = <AppDatabase>[initial, failed, recovered];
    var openIndex = 0;
    var recoveryCalled = false;
    final provider = NotifierProvider<DatabaseSessionNotifier, DatabaseSession>(
      () => DatabaseSessionNotifier(
        databaseFactory: () => databases[openIndex++],
        liveFile: () async => File('/synthetic/live.sqlite'),
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(provider);

    await expectLater(
      container
          .read(provider.notifier)
          .whileDatabaseClosed<File>(
            (_) async => File('/synthetic/live.sqlite.pre-restore'),
            restoreOnReopenFailure: (_, _) async {
              recoveryCalled = true;
            },
          ),
      throwsA(anything),
    );

    expect(recoveryCalled, isTrue);
    expect(
      await container
          .read(provider)
          .database
          .customSelect('SELECT 1')
          .getSingle(),
      isNotNull,
    );
  });
}

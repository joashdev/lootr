import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/migration_providers.dart';
import 'package:lootr/application/providers/sync_providers.dart';
import 'package:lootr/data/database/app_database.dart';

void main() {
  test('databaseProvider rejects new Drift access during maintenance', () {
    final database = AppDatabase.inMemory();
    final container = ProviderContainer(
      overrides: [
        databaseSessionProvider.overrideWith(
          () => DatabaseSessionNotifier(
            databaseFactory: () => database,
            liveFile: () async => File('/synthetic/live.sqlite'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(databaseProvider), same(database));
    container.read(databaseSessionProvider.notifier).beginMaintenance();
    expect(
      () => container.read(databaseProvider),
      throwsA(
        isA<ProviderException>().having(
          (error) => error.exception,
          'exception',
          isA<DatabaseMaintenanceFailure>(),
        ),
      ),
    );
    container.read(databaseSessionProvider.notifier).endMaintenance();
    expect(container.read(databaseProvider), same(database));
  });

  test(
    'sync provider honors a database override without building a session',
    () {
      final database = AppDatabase.inMemory();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) => database),
          databaseSessionProvider.overrideWith(
            _UnexpectedDatabaseSessionNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(syncManagerProvider), isNotNull);
    },
  );

  test(
    'migration coordinator survives a database session replacement',
    () async {
      final initial = AppDatabase.inMemory();
      final reopened = AppDatabase.inMemory();
      final databases = [initial, reopened];
      var index = 0;
      final container = ProviderContainer(
        overrides: [
          databaseSessionProvider.overrideWith(
            () => DatabaseSessionNotifier(
              databaseFactory: () => databases[index++],
              liveFile: () async => File('/synthetic/live.sqlite'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final before = container.read(migrationCoordinatorProvider);

      await container
          .read(databaseSessionProvider.notifier)
          .whileDatabaseClosed<void>((_) async {});

      expect(container.read(migrationCoordinatorProvider), same(before));
    },
  );

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

class _UnexpectedDatabaseSessionNotifier extends DatabaseSessionNotifier {
  @override
  DatabaseSession build() {
    throw StateError('database session should not be built');
  }
}

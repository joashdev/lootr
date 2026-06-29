import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull;

import '../../data/database/app_database.dart';
import '../../data/seed/demo_data_loader.dart';
import 'database_provider.dart';
import 'repo_providers.dart';

enum DemoDataStatus { absent, loading, present }

class DemoDataState {
  final DemoDataStatus status;

  const DemoDataState({this.status = DemoDataStatus.absent});
}

class DemoDataNotifier extends AsyncNotifier<DemoDataState> {
  @override
  Future<DemoDataState> build() async {
    return const DemoDataState();
  }

  Future<void> seed() async {
    final repo = ref.read(categoryRepoProvider);
    await repo.seedCategories();

    final alreadySeeded = await hasDemoData();
    if (alreadySeeded) return;

    state = const AsyncData(DemoDataState(status: DemoDataStatus.loading));
    final db = ref.read(databaseProvider);

    const userId = 'demo-user-1';
    await db.into(db.users).insertOnConflictUpdate(
          UsersCompanion.insert(
            id: userId,
            email: const Value('demo@lootr.app'),
          ),
        );

    final loader = DemoDataLoader();
    await loader.load(db, userId: userId);

    final syncRepo = ref.read(syncMetadataRepoProvider);
    await syncRepo.set('demo_data_seeded', 'true');

    state = const AsyncData(DemoDataState(status: DemoDataStatus.present));
  }

  Future<void> clear() async {
    final db = ref.read(databaseProvider);

    await (db.delete(db.transactions)..where((t) => t.id.like('demo-%'))).go();
    await (db.delete(db.accounts)..where((t) => t.id.like('demo-%'))).go();
    await (db.delete(db.categories)..where((t) => t.id.like('demo-%'))).go();
    await (db.delete(db.payees)..where((t) => t.id.like('demo-%'))).go();
    await (db.delete(db.budgets)..where((t) => t.id.like('demo-%'))).go();
    await (db.delete(db.goals)..where((t) => t.id.like('demo-%'))).go();
    await (db.delete(
      db.recurringTemplates,
    )..where((t) => t.id.like('demo-%'))).go();
    await (db.delete(db.debtRecords)..where((t) => t.id.like('demo-%'))).go();
    await (db.delete(db.users)..where((t) => t.id.like('demo-%'))).go();

    final syncRepo = ref.read(syncMetadataRepoProvider);
    await syncRepo.set('demo_data_seeded', 'false');

    state = const AsyncData(DemoDataState(status: DemoDataStatus.absent));
  }

  Future<bool> hasDemoData() async {
    final syncRepo = ref.read(syncMetadataRepoProvider);
    final value = await syncRepo.get('demo_data_seeded');
    return value == 'true';
  }
}

final demoDataProvider = AsyncNotifierProvider<DemoDataNotifier, DemoDataState>(
  DemoDataNotifier.new,
);

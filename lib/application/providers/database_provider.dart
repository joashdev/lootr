import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/database/app_database.dart';

final class DatabaseSession {
  const DatabaseSession({
    required this.database,
    required this.liveFile,
    this.isUnderMaintenance = false,
  });

  final AppDatabase database;
  final Future<File> liveFile;
  final bool isUnderMaintenance;

  DatabaseSession copyWith({AppDatabase? database, bool? isUnderMaintenance}) {
    return DatabaseSession(
      database: database ?? this.database,
      liveFile: liveFile,
      isUnderMaintenance: isUnderMaintenance ?? this.isUnderMaintenance,
    );
  }
}

class DatabaseSessionNotifier extends Notifier<DatabaseSession> {
  @override
  DatabaseSession build() {
    final database = AppDatabase.defaultDatabase();
    ref.onDispose(() => state.database.close());
    return DatabaseSession(
      database: database,
      liveFile: getApplicationDocumentsDirectory().then(
        (directory) => File(p.join(directory.path, 'lootr.sqlite')),
      ),
    );
  }

  Future<T> whileDatabaseClosed<T>(
    Future<T> Function(File liveFile) operation,
  ) async {
    if (state.isUnderMaintenance) {
      throw StateError('Database maintenance is already in progress.');
    }

    final current = state;
    state = current.copyWith(isUnderMaintenance: true);
    final liveFile = await current.liveFile;
    await current.database.close();

    try {
      final result = await operation(liveFile);
      final reopened = AppDatabase.defaultDatabase();
      await reopened.customSelect('SELECT 1').getSingle();
      state = DatabaseSession(database: reopened, liveFile: current.liveFile);
      return result;
    } catch (_) {
      final reopened = AppDatabase.defaultDatabase();
      state = DatabaseSession(database: reopened, liveFile: current.liveFile);
      rethrow;
    }
  }
}

/// Owns the single live Drift connection so file-level restore can close,
/// replace, and reopen the database without leaving repository providers bound
/// to a closed connection.
final databaseSessionProvider =
    NotifierProvider<DatabaseSessionNotifier, DatabaseSession>(
      DatabaseSessionNotifier.new,
    );

/// Existing application providers remain synchronous after startup. The app
/// only reads this provider once [databaseSessionProvider] has completed.
final databaseProvider = Provider<AppDatabase>((ref) {
  return ref.watch(databaseSessionProvider).database;
});

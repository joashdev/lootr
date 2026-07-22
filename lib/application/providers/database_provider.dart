import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/database/app_database.dart';
import '../database_access_gate.dart';

final databaseAccessGateProvider = Provider<DatabaseAccessGate>((ref) {
  return DatabaseAccessGate();
});

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
  DatabaseSessionNotifier({
    AppDatabase Function()? databaseFactory,
    Future<File> Function()? liveFile,
  }) : _databaseFactory = databaseFactory ?? AppDatabase.defaultDatabase,
       _liveFile =
           liveFile ??
           (() => getApplicationDocumentsDirectory().then(
             (directory) => File(p.join(directory.path, 'lootr.sqlite')),
           ));

  final AppDatabase Function() _databaseFactory;
  final Future<File> Function() _liveFile;
  AppDatabase? _activeDatabase;

  AppDatabase get database => state.database;
  Future<File> get liveFile => state.liveFile;
  bool get isUnderMaintenance => state.isUnderMaintenance;

  void beginMaintenance() {
    if (state.isUnderMaintenance) {
      throw StateError('Database maintenance is already in progress.');
    }
    state = state.copyWith(isUnderMaintenance: true);
  }

  void endMaintenance() {
    if (state.isUnderMaintenance) {
      state = state.copyWith(isUnderMaintenance: false);
    }
  }

  @override
  DatabaseSession build() {
    final database = _databaseFactory();
    _activeDatabase = database;
    ref.onDispose(() {
      final active = _activeDatabase;
      _activeDatabase = null;
      if (active != null) unawaited(active.close());
    });
    return DatabaseSession(database: database, liveFile: _liveFile());
  }

  Future<T> whileDatabaseClosed<T>(
    Future<T> Function(File liveFile) operation, {
    Future<void> Function(T result, File liveFile)? restoreOnReopenFailure,
    bool reuseMaintenance = false,
  }) async {
    final alreadyUnderMaintenance = state.isUnderMaintenance;
    if (alreadyUnderMaintenance && !reuseMaintenance) {
      throw StateError('Database maintenance is already in progress.');
    }

    final current = state;
    if (!alreadyUnderMaintenance) {
      state = current.copyWith(isUnderMaintenance: true);
    }
    final liveFile = await current.liveFile;
    await current.database.close();

    late T result;
    try {
      result = await operation(liveFile);
    } catch (_) {
      final reopened = await _openValidated();
      _publish(
        reopened,
        current.liveFile,
        isUnderMaintenance: alreadyUnderMaintenance,
      );
      rethrow;
    }

    try {
      final reopened = await _openValidated();
      _publish(
        reopened,
        current.liveFile,
        isUnderMaintenance: alreadyUnderMaintenance,
      );
      return result;
    } catch (error, stackTrace) {
      if (restoreOnReopenFailure != null) {
        try {
          await restoreOnReopenFailure(result, liveFile);
        } catch (recoveryError, recoveryStackTrace) {
          try {
            final fallback = await _openValidated();
            _publish(
              fallback,
              current.liveFile,
              isUnderMaintenance: alreadyUnderMaintenance,
            );
          } catch (_) {
            // The recovery error below is the actionable failure.
          }
          Error.throwWithStackTrace(recoveryError, recoveryStackTrace);
        }
      }
      final recovered = await _openValidated();
      _publish(
        recovered,
        current.liveFile,
        isUnderMaintenance: alreadyUnderMaintenance,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  void _publish(
    AppDatabase database,
    Future<File> liveFile, {
    bool isUnderMaintenance = false,
  }) {
    _activeDatabase = database;
    state = DatabaseSession(
      database: database,
      liveFile: liveFile,
      isUnderMaintenance: isUnderMaintenance,
    );
  }

  Future<AppDatabase> _openValidated() async {
    final database = _databaseFactory();
    try {
      await _validateReopened(database);
      return database;
    } catch (_) {
      await database.close();
      rethrow;
    }
  }

  Future<void> _validateReopened(AppDatabase database) async {
    await database.customSelect('SELECT 1').getSingle();
    final quick = await database.customSelect('PRAGMA quick_check').get();
    if (quick.isEmpty || quick.first.data.values.first != 'ok') {
      throw StateError('Reopened database did not pass integrity checks.');
    }
    if ((await database.customSelect('PRAGMA foreign_key_check').get())
        .isNotEmpty) {
      throw StateError('Reopened database did not pass foreign-key checks.');
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
  final session = ref.watch(databaseSessionProvider);
  if (session.isUnderMaintenance) {
    throw const DatabaseMaintenanceFailure();
  }
  return session.database;
});

final class DatabaseMaintenanceFailure implements Exception {
  const DatabaseMaintenanceFailure();

  @override
  String toString() => 'Database maintenance is in progress.';
}

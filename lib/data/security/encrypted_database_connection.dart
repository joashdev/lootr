import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../database/database_versions.dart';
import 'database_key_store.dart';
import 'secure_file_lifecycle.dart';

class EncryptedDatabaseConnection {
  EncryptedDatabaseConnection({
    DatabaseKeyStore? keyStore,
    this.secureFiles = const SecureFileLifecycle(),
    Future<Directory> Function()? documentsDirectory,
  }) : _keyStore = keyStore ?? PlatformDatabaseKeyStore(),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  final DatabaseKeyStore _keyStore;
  final SecureFileLifecycle secureFiles;
  final Future<Directory> Function() _documentsDirectory;

  QueryExecutor lazy({String filename = 'lootr.sqlite'}) {
    return LazyDatabase(() async {
      final directory = await _documentsDirectory();
      await directory.create(recursive: true);
      final file = File(p.join(directory.path, filename));
      final key = await _keyStore.loadOrCreate();
      await _recoverInterruptedReplacement(file, key);
      await _encryptLegacyPlaintextIfNeeded(file, key);

      return NativeDatabase(
        file,
        setup: (database) {
          database.execute('PRAGMA key = ${_hexKeyLiteral(key)}');
          _verifyOpenedDatabase(database);
        },
      );
    });
  }

  Future<void> _recoverInterruptedReplacement(File live, List<int> key) async {
    final encrypting = File('${live.path}.encrypting');
    final plaintextCheckpoint = File('${live.path}.plaintext-checkpoint');
    final restoreCheckpoint = File('${live.path}.pre-restore');
    final restoring = File('${live.path}.restoring');
    final restoreMarker = File('${live.path}.restore-pending');
    final rejectedRestore = File('${live.path}.rejected-restore');

    if (!await live.exists()) {
      if (await restoreCheckpoint.exists()) {
        await restoreCheckpoint.rename(live.path);
        await secureFiles.bestEffortDelete(rejectedRestore);
        await secureFiles.bestEffortDelete(restoring);
        await secureFiles.bestEffortDelete(restoreMarker);
      } else if (await rejectedRestore.exists()) {
        await rejectedRestore.rename(live.path);
      } else if (await encrypting.exists()) {
        try {
          _verifyEncryptedFile(encrypting, key);
          await encrypting.rename(live.path);
          await secureFiles.bestEffortDelete(plaintextCheckpoint);
        } catch (_) {
          await secureFiles.bestEffortDelete(encrypting);
          if (await plaintextCheckpoint.exists()) {
            await plaintextCheckpoint.rename(live.path);
          } else {
            rethrow;
          }
        }
      } else if (await plaintextCheckpoint.exists()) {
        await plaintextCheckpoint.rename(live.path);
      }
    }

    if (await live.exists() && await rejectedRestore.exists()) {
      try {
        _verifyEncryptedFile(live, key);
        await secureFiles.bestEffortDelete(rejectedRestore);
      } catch (_) {
        await secureFiles.bestEffortDelete(live);
        await rejectedRestore.rename(live.path);
      }
    }

    if (await live.exists() && await restoreCheckpoint.exists()) {
      try {
        _verifyEncryptedFile(live, key);
        final markerPayload = await restoreMarker.exists()
            ? await restoreMarker.readAsString()
            : 'pending';
        // Migration rollback retains the displaced imported database until
        // the restored database records the terminal run state. Generic
        // restores can finalize immediately after validation.
        if (!markerPayload.startsWith('rollback:')) {
          await secureFiles.bestEffortDelete(restoreCheckpoint);
          await secureFiles.bestEffortDelete(restoring);
          await secureFiles.bestEffortDelete(restoreMarker);
        }
      } catch (_) {
        await secureFiles.bestEffortDelete(live);
        await restoreCheckpoint.rename(live.path);
        await secureFiles.bestEffortDelete(restoring);
        await secureFiles.bestEffortDelete(restoreMarker);
      }
    } else if (await live.exists() && await restoreMarker.exists()) {
      await secureFiles.bestEffortDelete(restoring);
      await secureFiles.bestEffortDelete(restoreMarker);
    }

    if (await live.exists() &&
        !await _hasPlaintextHeader(live) &&
        await plaintextCheckpoint.exists()) {
      try {
        _verifyEncryptedFile(live, key);
        await secureFiles.bestEffortDelete(plaintextCheckpoint);
        await secureFiles.bestEffortDelete(encrypting);
      } catch (_) {
        await secureFiles.bestEffortDelete(live);
        await plaintextCheckpoint.rename(live.path);
      }
    }
  }

  Future<void> _encryptLegacyPlaintextIfNeeded(File live, List<int> key) async {
    if (!await live.exists() || await live.length() == 0) return;
    if (!await _hasPlaintextHeader(live)) return;

    final encrypted = File('${live.path}.encrypting');
    final plaintextCheckpoint = File('${live.path}.plaintext-checkpoint');
    await secureFiles.bestEffortDelete(encrypted);

    final source = sqlite.sqlite3.open(live.path);
    try {
      final encryptedPath = _sqlLiteral(encrypted.path);
      source.execute(
        'ATTACH DATABASE $encryptedPath AS encrypted '
        'KEY ${_hexKeyLiteral(key)}',
      );
      source.select("SELECT sqlcipher_export('encrypted')");
      final version =
          source.select('PRAGMA user_version').first.columnAt(0) as int;
      source.execute('PRAGMA encrypted.user_version = $version');
      source.execute('DETACH DATABASE encrypted');
    } catch (_) {
      await secureFiles.bestEffortDelete(encrypted);
      throw const EncryptedDatabaseFailure('plaintext_encryption_failed');
    } finally {
      source.close();
    }

    _verifyEncryptedFile(encrypted, key);

    try {
      if (await plaintextCheckpoint.exists()) {
        await secureFiles.bestEffortDelete(plaintextCheckpoint);
      }
      await live.rename(plaintextCheckpoint.path);
      await encrypted.rename(live.path);
      await secureFiles.bestEffortDelete(plaintextCheckpoint);
    } catch (_) {
      if (!await live.exists() && await plaintextCheckpoint.exists()) {
        await plaintextCheckpoint.rename(live.path);
      }
      throw const EncryptedDatabaseFailure('database_replace_failed');
    }
  }

  void _verifyEncryptedFile(File file, List<int> key) {
    final database = sqlite.sqlite3.open(file.path);
    try {
      database.execute('PRAGMA key = ${_hexKeyLiteral(key)}');
      _verifyOpenedDatabase(database);
    } on sqlite.SqliteException {
      throw const EncryptedDatabaseFailure('encrypted_database_unreadable');
    } finally {
      database.close();
    }
  }

  void _verifyOpenedDatabase(sqlite.Database database) {
    if (database.select('PRAGMA cipher_version').isEmpty) {
      throw const EncryptedDatabaseFailure('sqlcipher_unavailable');
    }
    final integrity = database.select('PRAGMA cipher_integrity_check');
    if (integrity.isNotEmpty) {
      final first = integrity.first.columnAt(0);
      if (first is String && first.toLowerCase() != 'ok') {
        throw const EncryptedDatabaseFailure('cipher_integrity_failed');
      }
    }
    final quick = database.select('PRAGMA quick_check');
    if (quick.isEmpty || quick.first.columnAt(0) != 'ok') {
      throw const EncryptedDatabaseFailure('database_integrity_failed');
    }
    if (database.select('PRAGMA foreign_key_check').isNotEmpty) {
      throw const EncryptedDatabaseFailure('database_foreign_key_failed');
    }
    final version = database.select('PRAGMA user_version').first.columnAt(0);
    if (version is! int || version < 0 || version > lootrSchemaVersion) {
      throw const EncryptedDatabaseFailure('database_schema_unsupported');
    }
  }

  Future<bool> _hasPlaintextHeader(File file) async {
    final handle = await file.open();
    try {
      final header = await handle.read(16);
      return String.fromCharCodes(header) == 'SQLite format 3\u0000';
    } finally {
      await handle.close();
    }
  }
}

String _hexKeyLiteral(List<int> bytes) {
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '"x\'$hex\'"';
}

String _sqlLiteral(String value) => "'${value.replaceAll("'", "''")}'";

class EncryptedDatabaseFailure implements Exception {
  const EncryptedDatabaseFailure(this.code);

  final String code;

  @override
  String toString() => 'EncryptedDatabaseFailure($code)';
}

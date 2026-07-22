import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../database/database_versions.dart';
import '../security/database_key_store.dart';
import '../security/secure_file_lifecycle.dart';

class LootrBackupService {
  LootrBackupService({
    required this.keyStore,
    this.secureFiles = const SecureFileLifecycle(),
  });

  static const formatVersion = 1;

  final DatabaseKeyStore keyStore;
  final SecureFileLifecycle secureFiles;

  Future<BackupResult> create({
    required File liveDatabase,
    required File destination,
  }) async {
    final key = await keyStore.loadOrCreate();
    final temporary = File('${destination.path}.creating');
    await secureFiles.bestEffortDelete(temporary);

    // SQLCipher requires a writable connection to create an attached export
    // even though the main database is only read.
    final source = _openEncrypted(liveDatabase, key, readOnly: false);
    var phase = 'attach';
    try {
      final targetPath = _sqlLiteral(temporary.path);
      source.execute(
        'ATTACH DATABASE $targetPath AS backup KEY ${_hexKeyLiteral(key)}',
      );
      phase = 'export';
      source.select("SELECT sqlcipher_export('backup')");
      phase = 'manifest';
      final schemaVersion =
          source.select('PRAGMA main.user_version').first.columnAt(0) as int;
      source.execute('PRAGMA backup.user_version = $schemaVersion');
      source.execute('''
        CREATE TABLE backup.lootr_backup_manifest (
          format_version INTEGER NOT NULL,
          schema_version INTEGER NOT NULL,
          created_at_utc TEXT NOT NULL
        )
      ''');
      source.execute(
        'INSERT INTO backup.lootr_backup_manifest VALUES '
        '($formatVersion, $schemaVersion, ${_sqlLiteral(DateTime.now().toUtc().toIso8601String())})',
      );
      phase = 'detach';
      source.execute('DETACH DATABASE backup');
    } on sqlite.SqliteException catch (error) {
      await secureFiles.bestEffortDelete(temporary);
      throw BackupFailure(
        'backup_creation_${phase}_failed_${error.extendedResultCode}',
      );
    } catch (_) {
      await secureFiles.bestEffortDelete(temporary);
      throw const BackupFailure('backup_creation_failed_unknown');
    } finally {
      source.close();
    }

    BackupManifest manifest;
    try {
      manifest = _verify(temporary, key);
    } catch (_) {
      await secureFiles.bestEffortDelete(temporary);
      rethrow;
    }
    if (await destination.exists()) {
      await secureFiles.bestEffortDelete(destination);
    }
    await temporary.rename(destination.path);
    final fingerprint = await sha256.bind(destination.openRead()).first;
    return BackupResult(
      file: destination,
      fingerprint: fingerprint.toString(),
      manifest: manifest,
    );
  }

  Future<BackupManifest> verify(File backup) async {
    final key = await keyStore.loadOrCreate();
    return _verify(backup, key);
  }

  /// Caller must close Drift and hold the maintenance lock before invoking.
  /// The returned checkpoint can be retained until the reopened database has
  /// passed application-level reconciliation.
  Future<File> restoreAtomically({
    required File backup,
    required File liveDatabase,
    String markerPayload = 'pending',
  }) async {
    final key = await keyStore.loadOrCreate();
    await _recoverInterruptedRestore(liveDatabase, key);
    _verify(backup, key);

    final staged = File('${liveDatabase.path}.restoring');
    final checkpoint = File('${liveDatabase.path}.pre-restore');
    final marker = File('${liveDatabase.path}.restore-pending');
    await secureFiles.bestEffortDelete(staged);
    await backup.copy(staged.path);
    _verify(staged, key);
    _removeBackupManifest(staged, key);

    try {
      await marker.writeAsString(markerPayload, flush: true);
      if (await liveDatabase.exists()) {
        await liveDatabase.rename(checkpoint.path);
      }
      await staged.rename(liveDatabase.path);
    } catch (_) {
      if (!await liveDatabase.exists() && await checkpoint.exists()) {
        await checkpoint.rename(liveDatabase.path);
      }
      await secureFiles.bestEffortDelete(staged);
      await secureFiles.bestEffortDelete(marker);
      throw const BackupFailure('restore_replace_failed');
    }
    return checkpoint;
  }

  /// Restores the live file retained by [restoreAtomically] when application
  /// reopening or post-restore validation fails.
  Future<void> restoreCheckpointAtomically({
    required File checkpoint,
    required File liveDatabase,
  }) async {
    final key = await keyStore.loadOrCreate();
    _verifyEncryptedDatabase(checkpoint, key);
    final rejected = File('${liveDatabase.path}.rejected-restore');
    await secureFiles.bestEffortDelete(rejected);
    try {
      if (await liveDatabase.exists()) {
        await liveDatabase.rename(rejected.path);
      }
      await checkpoint.rename(liveDatabase.path);
      _verifyEncryptedDatabase(liveDatabase, key);
      await secureFiles.bestEffortDelete(rejected);
      await _clearRestoreArtifacts(liveDatabase);
    } catch (_) {
      if (await rejected.exists()) {
        await secureFiles.bestEffortDelete(liveDatabase);
        await rejected.rename(liveDatabase.path);
      }
      throw const BackupFailure('restore_checkpoint_failed');
    }
  }

  void _removeBackupManifest(File staged, List<int> key) {
    final database = _openEncrypted(staged, key, readOnly: false);
    try {
      database.execute('DROP TABLE lootr_backup_manifest');
      if (database.select('PRAGMA quick_check').first.columnAt(0) != 'ok' ||
          database.select('PRAGMA foreign_key_check').isNotEmpty) {
        throw const BackupFailure('restored_database_integrity_failed');
      }
    } on sqlite.SqliteException {
      throw const BackupFailure('restored_database_prepare_failed');
    } finally {
      database.close();
    }
  }

  Future<void> discardCheckpoint(File checkpoint) {
    return _discardCheckpoint(checkpoint);
  }

  Future<void> _discardCheckpoint(File checkpoint) async {
    await secureFiles.bestEffortDelete(checkpoint);
    final suffix = '.pre-restore';
    if (!checkpoint.path.endsWith(suffix)) return;
    final live = File(
      checkpoint.path.substring(0, checkpoint.path.length - suffix.length),
    );
    await _clearRestoreArtifacts(live);
  }

  BackupManifest _verify(File file, List<int> key) {
    if (!file.existsSync()) {
      throw const BackupFailure('backup_missing');
    }
    final database = _openEncrypted(file, key, readOnly: true);
    try {
      final cipherIntegrity = database.select('PRAGMA cipher_integrity_check');
      if (cipherIntegrity.isNotEmpty &&
          cipherIntegrity.first.columnAt(0).toString().toLowerCase() != 'ok') {
        throw const BackupFailure('backup_cipher_integrity_failed');
      }
      if (database.select('PRAGMA quick_check').first.columnAt(0) != 'ok') {
        throw const BackupFailure('backup_integrity_failed');
      }
      if (database.select('PRAGMA foreign_key_check').isNotEmpty) {
        throw const BackupFailure('backup_foreign_key_failed');
      }
      final rows = database.select(
        'SELECT format_version, schema_version, created_at_utc '
        'FROM lootr_backup_manifest',
      );
      if (rows.length != 1) {
        throw const BackupFailure('backup_manifest_missing');
      }
      final format = rows.first['format_version'] as int;
      if (format != formatVersion) {
        throw const BackupFailure('backup_format_unsupported');
      }
      final schema = rows.first['schema_version'] as int;
      if (schema < 1 || schema > lootrSchemaVersion) {
        throw const BackupFailure('backup_schema_unsupported');
      }
      final databaseSchema = database
          .select('PRAGMA user_version')
          .first
          .columnAt(0);
      if (databaseSchema != schema) {
        throw const BackupFailure('backup_schema_mismatch');
      }
      return BackupManifest(
        formatVersion: format,
        schemaVersion: schema,
        createdAt: DateTime.parse(rows.first['created_at_utc'] as String),
      );
    } on sqlite.SqliteException {
      throw const BackupFailure('backup_unreadable');
    } finally {
      database.close();
    }
  }

  Future<void> _recoverInterruptedRestore(
    File liveDatabase,
    List<int> key,
  ) async {
    final checkpoint = File('${liveDatabase.path}.pre-restore');
    final marker = File('${liveDatabase.path}.restore-pending');
    if (!await checkpoint.exists()) {
      await secureFiles.bestEffortDelete(marker);
      return;
    }
    if (await liveDatabase.exists()) {
      try {
        _verifyEncryptedDatabase(liveDatabase, key);
        await secureFiles.bestEffortDelete(checkpoint);
        await _clearRestoreArtifacts(liveDatabase);
        return;
      } catch (_) {
        await secureFiles.bestEffortDelete(liveDatabase);
      }
    }
    await checkpoint.rename(liveDatabase.path);
    _verifyEncryptedDatabase(liveDatabase, key);
    await _clearRestoreArtifacts(liveDatabase);
  }

  void _verifyEncryptedDatabase(File file, List<int> key) {
    final database = _openEncrypted(file, key, readOnly: true);
    try {
      final cipherIntegrity = database.select('PRAGMA cipher_integrity_check');
      final cipherFailed =
          cipherIntegrity.isNotEmpty &&
          cipherIntegrity.first.columnAt(0).toString().toLowerCase() != 'ok';
      if (cipherFailed ||
          database.select('PRAGMA quick_check').first.columnAt(0) != 'ok' ||
          database.select('PRAGMA foreign_key_check').isNotEmpty) {
        throw const BackupFailure('database_checkpoint_invalid');
      }
      final version = database.select('PRAGMA user_version').first.columnAt(0);
      if (version is! int || version < 0 || version > lootrSchemaVersion) {
        throw const BackupFailure('database_schema_unsupported');
      }
    } finally {
      database.close();
    }
  }

  Future<void> _clearRestoreArtifacts(File liveDatabase) async {
    await secureFiles.bestEffortDelete(
      File('${liveDatabase.path}.restore-pending'),
    );
    await secureFiles.bestEffortDelete(File('${liveDatabase.path}.restoring'));
  }

  sqlite.Database _openEncrypted(
    File file,
    List<int> key, {
    required bool readOnly,
  }) {
    final database = sqlite.sqlite3.open(
      file.path,
      mode: readOnly
          ? sqlite.OpenMode.readOnly
          : sqlite.OpenMode.readWriteCreate,
    );
    try {
      database.execute('PRAGMA key = ${_hexKeyLiteral(key)}');
      if (database.select('PRAGMA cipher_version').isEmpty) {
        throw const BackupFailure('sqlcipher_unavailable');
      }
      database.select('SELECT count(*) FROM sqlite_master');
      if (readOnly) database.execute('PRAGMA query_only = ON');
      return database;
    } on BackupFailure {
      database.close();
      rethrow;
    } on sqlite.SqliteException {
      database.close();
      throw const BackupFailure('backup_key_or_cipher_invalid');
    } catch (_) {
      database.close();
      throw const BackupFailure('backup_open_failed');
    }
  }
}

class BackupResult {
  const BackupResult({
    required this.file,
    required this.fingerprint,
    required this.manifest,
  });

  final File file;
  final String fingerprint;
  final BackupManifest manifest;
}

class BackupManifest {
  const BackupManifest({
    required this.formatVersion,
    required this.schemaVersion,
    required this.createdAt,
  });

  final int formatVersion;
  final int schemaVersion;
  final DateTime createdAt;
}

class BackupFailure implements Exception {
  const BackupFailure(this.code);

  final String code;

  @override
  String toString() => 'BackupFailure($code)';
}

String _hexKeyLiteral(List<int> bytes) {
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '"x\'$hex\'"';
}

String _sqlLiteral(String value) => "'${value.replaceAll("'", "''")}'";

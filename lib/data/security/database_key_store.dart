import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract interface class DatabaseKeyStore {
  Future<List<int>> loadOrCreate();
}

class PlatformDatabaseKeyStore implements DatabaseKeyStore {
  PlatformDatabaseKeyStore({
    FlutterSecureStorage? storage,
    Random? random,
    Future<Directory> Function()? documentsDirectory,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(
               storageNamespace: 'lootr_database',
               migrateWithBackup: true,
               // Resetting this value would permanently orphan the database.
               resetOnError: false,
             ),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.unlocked_this_device,
               synchronizable: false,
             ),
           ),
       _random = random ?? Random.secure(),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  static const _storageKey = 'lootr_sqlcipher_key_v1';
  static const _keyLength = 32;

  final FlutterSecureStorage _storage;
  final Random _random;
  final Future<Directory> Function() _documentsDirectory;

  // Multiple services construct their own key-store instance. Serialize the
  // read-create-write sequence across all of them so two first-launch callers
  // cannot persist different keys for the same database.
  static Future<void> _initializationTail = Future<void>.value();

  @override
  Future<List<int>> loadOrCreate() {
    final predecessor = _initializationTail;
    final released = Completer<void>();
    _initializationTail = released.future;
    return () async {
      await predecessor;
      try {
        return await _loadOrCreate();
      } finally {
        released.complete();
      }
    }();
  }

  Future<List<int>> _loadOrCreate() async {
    final encoded = await _storage.read(key: _storageKey);
    if (encoded != null) {
      final List<int> bytes;
      try {
        bytes = base64Url.decode(encoded);
      } on FormatException {
        throw const DatabaseKeyFailure('invalid_stored_database_key');
      }
      if (bytes.length != _keyLength) {
        throw const DatabaseKeyFailure('invalid_stored_database_key');
      }
      return bytes;
    }

    if (await _hasProtectedDatabaseArtifacts()) {
      throw const DatabaseKeyFailure('database_key_missing');
    }

    final bytes = List<int>.generate(
      _keyLength,
      (_) => _random.nextInt(256),
      growable: false,
    );
    await _storage.write(key: _storageKey, value: base64UrlEncode(bytes));
    final persisted = await _storage.read(key: _storageKey);
    if (persisted != base64UrlEncode(bytes)) {
      throw const DatabaseKeyFailure('database_key_persistence_failed');
    }
    return bytes;
  }

  Future<bool> _hasProtectedDatabaseArtifacts() async {
    final directory = await _documentsDirectory();
    final live = File(p.join(directory.path, 'lootr.sqlite'));
    final plaintextCheckpoint = File('${live.path}.plaintext-checkpoint');

    // A legacy plaintext database is the one valid case where a database file
    // exists before its SQLCipher key. The encryption recovery path can safely
    // create a key and convert either of these plaintext copies.
    if (await _hasPlaintextHeader(live) ||
        await _hasPlaintextHeader(plaintextCheckpoint)) {
      return false;
    }

    for (final file in <File>[
      live,
      File('${live.path}.encrypting'),
      File('${live.path}.pre-restore'),
      File('${live.path}.rejected-restore'),
      File('${live.path}.restoring'),
    ]) {
      if (await file.exists() && await file.length() > 0) return true;
    }
    return false;
  }

  Future<bool> _hasPlaintextHeader(File file) async {
    if (!await file.exists() || await file.length() < 16) return false;
    final handle = await file.open();
    try {
      return String.fromCharCodes(await handle.read(16)) ==
          'SQLite format 3\u0000';
    } finally {
      await handle.close();
    }
  }
}

class InMemoryDatabaseKeyStore implements DatabaseKeyStore {
  InMemoryDatabaseKeyStore(this.key);

  final List<int> key;

  @override
  Future<List<int>> loadOrCreate() async => List<int>.unmodifiable(key);
}

class DatabaseKeyFailure implements Exception {
  const DatabaseKeyFailure(this.code);

  final String code;

  @override
  String toString() => 'DatabaseKeyFailure($code)';
}

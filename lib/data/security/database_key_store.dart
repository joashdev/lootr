import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class DatabaseKeyStore {
  Future<List<int>> loadOrCreate();
}

class PlatformDatabaseKeyStore implements DatabaseKeyStore {
  PlatformDatabaseKeyStore({
    FlutterSecureStorage? storage,
    Random? random,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                storageNamespace: 'lootr_database',
                migrateWithBackup: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.unlocked_this_device,
                synchronizable: false,
              ),
            ),
        _random = random ?? Random.secure();

  static const _storageKey = 'lootr_sqlcipher_key_v1';
  static const _keyLength = 32;

  final FlutterSecureStorage _storage;
  final Random _random;

  @override
  Future<List<int>> loadOrCreate() async {
    final encoded = await _storage.read(key: _storageKey);
    if (encoded != null) {
      final bytes = base64Url.decode(encoded);
      if (bytes.length != _keyLength) {
        throw const DatabaseKeyFailure('invalid_stored_database_key');
      }
      return bytes;
    }

    final bytes = List<int>.generate(
      _keyLength,
      (_) => _random.nextInt(256),
      growable: false,
    );
    await _storage.write(
      key: _storageKey,
      value: base64UrlEncode(bytes),
    );
    return bytes;
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

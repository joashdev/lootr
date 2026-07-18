import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/security/database_key_store.dart';
import 'package:lootr/data/security/encrypted_database_connection.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory temporary;
  late InMemoryDatabaseKeyStore keys;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('lootr-cipher-test-');
    keys = InMemoryDatabaseKeyStore(List<int>.generate(32, (index) => index));
  });

  tearDown(() async {
    await temporary.delete(recursive: true);
  });

  test(
    'new Lootr database is encrypted and readable with its secure key',
    () async {
      final database = AppDatabase(
        EncryptedDatabaseConnection(
          keyStore: keys,
          documentsDirectory: () async => temporary,
        ).lazy(),
      );
      await database
          .into(database.users)
          .insert(UsersCompanion.insert(id: 'owner'));
      await database.close();

      final file = File('${temporary.path}/lootr.sqlite');
      expect(await _hasPlaintextHeader(file), isFalse);
      final raw = sqlite.sqlite3.open(file.path);
      try {
        raw.execute('PRAGMA key = ${_keyLiteral(await keys.loadOrCreate())}');
        expect(raw.select('PRAGMA cipher_version'), isNotEmpty);
        expect(
          raw.select('SELECT COUNT(*) AS count FROM users').single['count'],
          1,
        );
      } finally {
        raw.close();
      }
    },
  );

  test(
    'existing plaintext Lootr database migrates without losing rows',
    () async {
      final file = File('${temporary.path}/lootr.sqlite');
      final plaintext = AppDatabase(NativeDatabase(file));
      await plaintext
          .into(plaintext.users)
          .insert(
            UsersCompanion.insert(
              id: 'owner',
              displayName: const Value('Synthetic owner'),
            ),
          );
      await plaintext.close();
      expect(await _hasPlaintextHeader(file), isTrue);

      final encrypted = AppDatabase(
        EncryptedDatabaseConnection(
          keyStore: keys,
          documentsDirectory: () async => temporary,
        ).lazy(),
      );
      final users = await encrypted.select(encrypted.users).get();
      expect(users, hasLength(1));
      expect(users.single.displayName, 'Synthetic owner');
      await encrypted.close();

      expect(await _hasPlaintextHeader(file), isFalse);
      expect(await File('${file.path}.plaintext-checkpoint').exists(), isFalse);
      expect(await File('${file.path}.encrypting').exists(), isFalse);
    },
  );
}

Future<bool> _hasPlaintextHeader(File file) async {
  final handle = await file.open();
  try {
    return String.fromCharCodes(await handle.read(16)) ==
        'SQLite format 3\u0000';
  } finally {
    await handle.close();
  }
}

String _keyLiteral(List<int> bytes) {
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '"x\'$hex\'"';
}

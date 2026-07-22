import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
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

  test(
    'startup recovers a plaintext checkpoint left between replacement renames',
    () async {
      final live = File('${temporary.path}/lootr.sqlite');
      final checkpoint = File('${live.path}.plaintext-checkpoint');
      final plaintext = AppDatabase(NativeDatabase(checkpoint));
      await plaintext
          .into(plaintext.users)
          .insert(UsersCompanion.insert(id: 'checkpoint-owner'));
      await plaintext.close();
      expect(await live.exists(), isFalse);

      final recovered = AppDatabase(
        EncryptedDatabaseConnection(
          keyStore: keys,
          documentsDirectory: () async => temporary,
        ).lazy(),
      );
      expect(await recovered.select(recovered.users).get(), hasLength(1));
      await recovered.close();

      expect(await live.exists(), isTrue);
      expect(await _hasPlaintextHeader(live), isFalse);
      expect(await checkpoint.exists(), isFalse);
    },
  );

  test(
    'startup restores a pre-restore checkpoint when live is absent',
    () async {
      final live = File('${temporary.path}/lootr.sqlite');
      final original = AppDatabase(
        EncryptedDatabaseConnection(
          keyStore: keys,
          documentsDirectory: () async => temporary,
        ).lazy(),
      );
      await original
          .into(original.users)
          .insert(UsersCompanion.insert(id: 'restore-owner'));
      await original.close();

      final checkpoint = File('${live.path}.pre-restore');
      await live.rename(checkpoint.path);
      await File('${live.path}.restoring').writeAsString('synthetic');
      await File('${live.path}.restore-pending').writeAsString('pending');

      final recovered = AppDatabase(
        EncryptedDatabaseConnection(
          keyStore: keys,
          documentsDirectory: () async => temporary,
        ).lazy(),
      );
      expect(await recovered.select(recovered.users).get(), hasLength(1));
      await recovered.close();

      expect(await live.exists(), isTrue);
      expect(await checkpoint.exists(), isFalse);
      expect(await File('${live.path}.restoring').exists(), isFalse);
      expect(await File('${live.path}.restore-pending').exists(), isFalse);
    },
  );

  test(
    'startup keeps a valid restored database and removes its checkpoint',
    () async {
      final live = File('${temporary.path}/lootr.sqlite');
      final restored = AppDatabase(
        EncryptedDatabaseConnection(
          keyStore: keys,
          documentsDirectory: () async => temporary,
        ).lazy(),
      );
      await restored
          .into(restored.users)
          .insert(UsersCompanion.insert(id: 'restored-owner'));
      await restored.close();

      final checkpoint = File('${live.path}.pre-restore');
      await live.copy(checkpoint.path);
      await File('${live.path}.restoring').writeAsString('synthetic');
      await File('${live.path}.restore-pending').writeAsString('pending');

      final reopened = AppDatabase(
        EncryptedDatabaseConnection(
          keyStore: keys,
          documentsDirectory: () async => temporary,
        ).lazy(),
      );
      expect(await reopened.select(reopened.users).get(), hasLength(1));
      await reopened.close();

      expect(await live.exists(), isTrue);
      expect(await checkpoint.exists(), isFalse);
      expect(await File('${live.path}.restoring').exists(), isFalse);
      expect(await File('${live.path}.restore-pending').exists(), isFalse);
    },
  );

  test('every encrypted open rejects foreign-key corruption', () async {
    final live = File('${temporary.path}/lootr.sqlite');
    final original = AppDatabase(
      EncryptedDatabaseConnection(
        keyStore: keys,
        documentsDirectory: () async => temporary,
      ).lazy(),
    );
    await original.customSelect('SELECT 1').getSingle();
    await original.close();

    final raw = sqlite.sqlite3.open(live.path);
    try {
      raw.execute('PRAGMA key = ${_keyLiteral(await keys.loadOrCreate())}');
      raw.execute('PRAGMA foreign_keys = OFF');
      raw.execute('''
        INSERT INTO accounts (
          id, owner_user_id, name, account_type, balance, currency_code,
          is_archived, is_hidden, sync_status
        ) VALUES (
          'orphan-account', 'missing-owner', 'Synthetic', 'bank', 0, 'TST',
          0, 0, 'local_only'
        )
      ''');
    } finally {
      raw.close();
    }

    final rejected = AppDatabase(
      EncryptedDatabaseConnection(
        keyStore: keys,
        documentsDirectory: () async => temporary,
      ).lazy(),
    );
    Object? failure;
    try {
      await rejected.customSelect('SELECT 1').getSingle();
    } catch (error) {
      failure = error;
    }
    expect(failure, isNotNull);
    expect(failure.toString(), contains('database_foreign_key_failed'));
  });
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

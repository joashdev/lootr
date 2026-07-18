import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/data/backup/lootr_backup_service.dart';
import 'package:lootr/data/security/database_key_store.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory temporary;
  final key = List<int>.generate(32, (index) => index + 1);

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('lootr-backup-test-');
  });

  tearDown(() async {
    if (await temporary.exists()) {
      await temporary.delete(recursive: true);
    }
  });

  test('encrypted backup verifies and restores full contents', () async {
    final live = File('${temporary.path}/live.sqlite');
    _createEncryptedDatabase(live, key, marker: 'synthetic-before');
    final destination = File('${temporary.path}/backup.lootr');
    final service = LootrBackupService(keyStore: InMemoryDatabaseKeyStore(key));

    final result = await service.create(
      liveDatabase: live,
      destination: destination,
    );

    expect(result.manifest.formatVersion, LootrBackupService.formatVersion);
    expect(result.fingerprint, hasLength(64));
    expect(_hasPlaintextHeader(destination), isFalse);

    _replaceMarker(live, key, 'synthetic-after');
    final checkpoint = await service.restoreAtomically(
      backup: destination,
      liveDatabase: live,
    );
    expect(_readMarker(live, key), 'synthetic-before');
    expect(_hasTable(live, key, 'lootr_backup_manifest'), isFalse);
    expect(await checkpoint.exists(), isTrue);
    await service.discardCheckpoint(checkpoint);
  });

  test('wrong key cannot verify an encrypted backup', () async {
    final live = File('${temporary.path}/live.sqlite');
    _createEncryptedDatabase(live, key, marker: 'synthetic');
    final destination = File('${temporary.path}/backup.lootr');
    final service = LootrBackupService(keyStore: InMemoryDatabaseKeyStore(key));
    await service.create(liveDatabase: live, destination: destination);

    final wrongKey = List<int>.filled(32, 9);
    final wrongService = LootrBackupService(
      keyStore: InMemoryDatabaseKeyStore(wrongKey),
    );
    await expectLater(
      wrongService.verify(destination),
      throwsA(isA<BackupFailure>()),
    );
  });
}

bool _hasTable(File file, List<int> key, String table) {
  final database = sqlite3.open(file.path);
  try {
    database.execute('PRAGMA key = ${_keyLiteral(key)}');
    return database.select(
      'SELECT 1 FROM sqlite_schema WHERE type = ? AND name = ?',
      ['table', table],
    ).isNotEmpty;
  } finally {
    database.close();
  }
}

void _createEncryptedDatabase(
  File file,
  List<int> key, {
  required String marker,
}) {
  final database = sqlite3.open(file.path);
  try {
    database.execute('PRAGMA key = ${_keyLiteral(key)}');
    expect(database.select('PRAGMA cipher_version'), isNotEmpty);
    database.execute('PRAGMA foreign_keys = ON');
    database.execute('PRAGMA user_version = 3');
    database.execute(
      'CREATE TABLE sample (id INTEGER PRIMARY KEY, marker TEXT NOT NULL)',
    );
    database.execute("INSERT INTO sample VALUES (1, '${_escape(marker)}')");
  } finally {
    database.close();
  }
}

void _replaceMarker(File file, List<int> key, String marker) {
  final database = sqlite3.open(file.path);
  try {
    database.execute('PRAGMA key = ${_keyLiteral(key)}');
    database.execute(
      "UPDATE sample SET marker = '${_escape(marker)}' WHERE id = 1",
    );
  } finally {
    database.close();
  }
}

String _readMarker(File file, List<int> key) {
  final database = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    database.execute('PRAGMA key = ${_keyLiteral(key)}');
    return database.select('SELECT marker FROM sample').first['marker']
        as String;
  } finally {
    database.close();
  }
}

bool _hasPlaintextHeader(File file) {
  final handle = file.openSync();
  try {
    return String.fromCharCodes(handle.readSync(16)) == 'SQLite format 3\u0000';
  } finally {
    handle.closeSync();
  }
}

String _keyLiteral(List<int> bytes) {
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '"x\'$hex\'"';
}

String _escape(String value) => value.replaceAll("'", "''");

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/data/security/database_key_store.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late Directory temporary;
  late _MockSecureStorage storage;
  String? storedValue;
  var writes = 0;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('lootr-key-store-test-');
    storage = _MockSecureStorage();
    storedValue = null;
    writes = 0;
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => storedValue);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      writes++;
      storedValue = invocation.namedArguments[#value]! as String;
    });
  });

  tearDown(() async {
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });

  PlatformDatabaseKeyStore createStore({Random? random}) {
    return PlatformDatabaseKeyStore(
      storage: storage,
      random: random ?? Random(7),
      documentsDirectory: () async => temporary,
    );
  }

  test(
    'creates and verifies one key when no protected database exists',
    () async {
      final key = await createStore().loadOrCreate();

      expect(key, hasLength(32));
      expect(base64Url.decode(storedValue!), key);
      expect(writes, 1);
    },
  );

  test(
    'fails closed when an encrypted database exists without its key',
    () async {
      await File(
        '${temporary.path}/lootr.sqlite',
      ).writeAsBytes(List<int>.generate(64, (index) => index + 1), flush: true);

      await expectLater(
        createStore().loadOrCreate(),
        throwsA(
          isA<DatabaseKeyFailure>().having(
            (failure) => failure.code,
            'code',
            'database_key_missing',
          ),
        ),
      );
      expect(writes, 0);
    },
  );

  test('allows a key for legacy plaintext database encryption', () async {
    await File('${temporary.path}/lootr.sqlite').writeAsBytes(<int>[
      ...utf8.encode('SQLite format 3\u0000'),
      ...List<int>.filled(48, 0),
    ], flush: true);

    expect(await createStore().loadOrCreate(), hasLength(32));
    expect(writes, 1);
  });

  test(
    'serializes concurrent first-launch creation across instances',
    () async {
      final firstReadStarted = Completer<void>();
      final releaseFirstRead = Completer<void>();
      var reads = 0;
      when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async {
        reads++;
        if (reads == 1) {
          firstReadStarted.complete();
          await releaseFirstRead.future;
        }
        return storedValue;
      });

      final first = createStore(random: Random(1)).loadOrCreate();
      await firstReadStarted.future;
      final second = createStore(random: Random(2)).loadOrCreate();
      await Future<void>.delayed(Duration.zero);

      expect(reads, 1);
      releaseFirstRead.complete();
      final keys = await Future.wait([first, second]);

      expect(keys[1], keys[0]);
      expect(writes, 1);
    },
  );

  test('rejects malformed stored key material', () async {
    storedValue = 'not-base64!';

    await expectLater(
      createStore().loadOrCreate(),
      throwsA(
        isA<DatabaseKeyFailure>().having(
          (failure) => failure.code,
          'code',
          'invalid_stored_database_key',
        ),
      ),
    );
    expect(writes, 0);
  });
}

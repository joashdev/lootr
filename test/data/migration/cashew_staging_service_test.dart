import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/data/migration/cashew_staging_service.dart';

void main() {
  late Directory temporary;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('lootr-stage-test-');
  });

  tearDown(() async {
    if (await temporary.exists()) {
      await temporary.delete(recursive: true);
    }
  });

  test('copies and fingerprints without modifying selected source', () async {
    final source = File('${temporary.path}/synthetic.sql');
    final bytes = <int>[
      ...'SQLite format 3\u0000'.codeUnits,
      ...List<int>.generate(256, (index) => index % 251),
    ];
    await source.writeAsBytes(bytes, flush: true);
    final beforeModified = await source.lastModified();
    final expectedHash = sha256.convert(bytes).toString();

    final staging = CashewStagingService(
      supportDirectory: () async => Directory('${temporary.path}/support'),
    );
    final result = await staging.stage(XFile(source.path));

    expect(result.sourceFingerprint, expectedHash);
    expect(await result.file.readAsBytes(), bytes);
    expect(await source.readAsBytes(), bytes);
    expect(await source.lastModified(), beforeModified);

    await staging.cleanup(result);
    expect(await result.file.exists(), isFalse);
    expect(await source.exists(), isTrue);
  });

  test('rejects a non-SQLite file and cleans staging', () async {
    final source = File('${temporary.path}/invalid.sql');
    await source.writeAsString('synthetic invalid input');
    final stagingRoot = Directory('${temporary.path}/support');
    final staging = CashewStagingService(
      supportDirectory: () async => stagingRoot,
    );

    await expectLater(
      staging.stage(XFile(source.path)),
      throwsA(
        isA<StagingFailure>().having(
          (failure) => failure.code,
          'code',
          'invalid_sqlite_header',
        ),
      ),
    );

    final stagedFiles = stagingRoot.existsSync()
        ? stagingRoot.listSync(recursive: true).whereType<File>()
        : const <File>[];
    expect(stagedFiles, isEmpty);
  });
}

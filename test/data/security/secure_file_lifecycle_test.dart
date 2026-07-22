import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/data/security/secure_file_lifecycle.dart';

void main() {
  test('best-effort cleanup unlinks a plaintext staging file', () async {
    final directory =
        await Directory.systemTemp.createTemp('lootr-secure-delete-test-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final file = File('${directory.path}/source.sqlite');
    await file.writeAsBytes(List<int>.generate(4096, (index) => index % 256));

    await const SecureFileLifecycle().bestEffortDelete(file);

    expect(await file.exists(), isFalse);
  });
}

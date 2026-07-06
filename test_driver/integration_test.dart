import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Driver for the storyboard capture integration test.
///
/// Writes every screenshot taken by `binding.takeScreenshot(<name>)` to
/// `docs/storyboard-shots/<name>.png`, creating directories recursively so
/// that names like `seeded/01-onboarding-welcome` land in nested folders.
Future<void> main() async {
  await integrationDriver(
    onScreenshot:
        (String name, List<int> bytes, [Map<String, Object?>? args]) async {
          final file = File('docs/storyboard-shots/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes);
          return true;
        },
  );
}

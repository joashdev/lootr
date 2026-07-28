import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

import '../../core/reporting/diagnostic_logger.dart';
import '../../core/reporting/feedback_report_client.dart';

const _feedbackEndpoint = String.fromEnvironment('LOOTR_REPORT_ENDPOINT');

typedef ScreenshotSelector = Future<Uint8List?> Function();

final diagnosticLoggerProvider = Provider<DiagnosticLogger>(
  (ref) => DiagnosticLogger.instance,
);

final feedbackHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final feedbackSubmitterProvider = Provider<FeedbackSubmitter>((ref) {
  return CloudflareFeedbackSubmitter(
    endpoint: _feedbackEndpoint.isEmpty
        ? null
        : Uri.parse('$_feedbackEndpoint/reports'),
    client: ref.watch(feedbackHttpClientProvider),
  );
});

final screenshotSelectorProvider = Provider<ScreenshotSelector>((ref) {
  return () async {
    final selected = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 90,
    );
    if (selected == null) return null;
    return compute(_sanitizeScreenshot, await selected.readAsBytes());
  };
});

Uint8List _sanitizeScreenshot(Uint8List source) {
  final decoded = image.decodeImage(source);
  if (decoded == null) {
    throw const FormatException('The selected screenshot could not be read.');
  }

  var resized = decoded;
  final longest = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  if (longest > 1280) {
    if (decoded.width >= decoded.height) {
      resized = image.copyResize(decoded, width: 1280);
    } else {
      resized = image.copyResize(decoded, height: 1280);
    }
  }

  for (final quality in [78, 68, 58]) {
    final encoded = Uint8List.fromList(
      image.encodeJpg(resized, quality: quality),
    );
    if (encoded.lengthInBytes <= 1024 * 1024) return encoded;
  }
  throw const FormatException(
    'The selected screenshot is still larger than 1 MiB after compression.',
  );
}

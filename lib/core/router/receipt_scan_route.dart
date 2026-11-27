import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../domain/value_objects/ocr_payload.dart';

class ReceiptScanRequest {
  const ReceiptScanRequest._();

  static const path = '/scan';

  static Future<OcrPayload?> open(BuildContext context) =>
      context.push<OcrPayload>(path, extra: const ReceiptScanRequest._());
}

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../domain/value_objects/ocr_payload.dart';

class ReceiptScanRequest {
  const ReceiptScanRequest._();

  static const path = '/scan';

  static Future<OcrPayload?> open(BuildContext context) async {
    final router = GoRouter.of(context);
    if (router.routeInformationProvider.value.uri.path == path) return null;

    return router.push<OcrPayload>(path, extra: const ReceiptScanRequest._());
  }
}

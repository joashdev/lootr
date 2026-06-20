import '../value_objects/result.dart';
import '../value_objects/ocr_payload.dart';

class RunOCR {
  Future<Result<OcrPayload>> call(String imagePath) async {
    return Failure('OCR not available in V1', code: 'ocr_disabled');
  }
}

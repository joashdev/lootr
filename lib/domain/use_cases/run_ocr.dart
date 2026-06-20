import '../value_objects/result.dart';
import '../value_objects/ocr_payload.dart';
import '../../ai/ocr_pipeline.dart';

class RunOCR {
  final OCRPipeline _pipeline;
  final bool _aiEnabled;

  RunOCR({
    OCRPipeline? pipeline,
    bool aiEnabled = true,
  })  : _pipeline = pipeline ?? const OCRPipeline(),
        _aiEnabled = aiEnabled;

  Future<Result<OcrPayload>> call(String imagePath) async {
    if (!_aiEnabled) {
      return Failure('OCR not available in V1', code: 'ocr_disabled');
    }

    final ocrResult = await _pipeline.process(imagePath);
    return Success(ocrResult.payload);
  }
}

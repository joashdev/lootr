import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/domain/use_cases/run_ocr.dart';
import 'package:lootr/domain/value_objects/result.dart';
import 'package:lootr/domain/value_objects/ocr_payload.dart';

void main() {
  group('RunOCR', () {
    test('should return Failure when aiEnabled is false', () async {
      final useCase = RunOCR(aiEnabled: false);
      final result = await useCase('/path/to/image.jpg');

      expect(result.isFailure, isTrue);
      final failure = result as Failure<OcrPayload>;
      expect(failure.code, 'ocr_disabled');
    });

    test('should process image when aiEnabled is true', () async {
      final useCase = RunOCR(aiEnabled: true);
      final result = await useCase('/path/to/image.jpg');

      expect(result.isSuccess, isTrue);
      final payload = (result as Success<OcrPayload>).value;
      expect(payload.rawText, '');
      expect(payload.confidence, 0.0);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/domain/use_cases/run_ocr.dart';
import 'package:lootr/domain/value_objects/result.dart';
import 'package:lootr/domain/value_objects/ocr_payload.dart';

void main() {
  late RunOCR useCase;

  setUp(() {
    useCase = RunOCR();
  });

  group('RunOCR', () {
    test('should return Failure in V1', () async {
      final result = await useCase('/path/to/image.jpg');

      expect(result.isFailure, isTrue);
      final failure = result as Failure<OcrPayload>;
      expect(failure.code, 'ocr_disabled');
    });
  });
}

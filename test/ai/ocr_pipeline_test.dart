import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/ai/ocr_pipeline.dart';
import 'package:lootr/domain/value_objects/parsed_transaction.dart';

void main() {
  late OCRPipeline pipeline;

  setUp(() {
    pipeline = const OCRPipeline();
  });

  group('OCRPipeline', () {
    test('process returns OcrResult with empty text when no text extracted', () async {
      final result = await pipeline.process('/path/to/empty_receipt.jpg');
      expect(result.payload.rawText, isEmpty);
      expect(result.payload.confidence, 0.0);
    });

    test('process returns OcrResult with textLines', () async {
      final result = await pipeline.process('/path/to/receipt.jpg');
      expect(result.textLines, isA<List<String>>());
      expect(result.payload.rawText, isA<String>());
    });

    test('creates OcrPayload with ParsedTransaction fields', () async {
      final result = await pipeline.process('/path/to/receipt.jpg');
      expect(result.payload.extractedFields, isA<ParsedTransaction>());
      expect(result.payload.extractedFields.confidence, lessThanOrEqualTo(1.0));
    });

    test('stub returns empty text lines in V1', () async {
      final result = await pipeline.process('/path/to/any.jpg');
      expect(result.textLines, isEmpty);
    });
  });
}

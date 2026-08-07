import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/ai/ocr_pipeline.dart';
import 'package:lootr/domain/value_objects/parsed_transaction.dart';

void main() {
  late OCRPipeline pipeline;

  setUp(() {
    pipeline = const OCRPipeline();
  });

  group('OCRPipeline', () {
    test(
      'process returns OcrResult with empty text when no text extracted',
      () async {
        final result = await pipeline.process('/path/to/empty_receipt.jpg');
        expect(result.payload.rawText, isEmpty);
        expect(result.payload.confidence, 0.0);
      },
    );

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

    test('uses the amount after an item count on the total line', () async {
      final receiptPipeline = OCRPipeline(
        textExtractor: (_) async => const [
          'Philippine Seven Corporation',
          'NaturalSPotato160g 118.00V',
          'SelectaCIUari450ml 125.00V',
          'Total Amount Due (2) 243.00',
          'CASH 1000.00',
          'CHANGE 757.00',
        ],
      );

      final result = await receiptPipeline.process('/path/to/receipt.jpg');

      expect(result.payload.extractedFields.amount, 243.00);
    });

    test('ignores metadata after the total amount', () async {
      for (final totalLine in const [
        'TOTAL 243.00 (2 items)',
        'TOTAL 243.00 VAT 12%',
        'TOTAL Qty 2 Amount 243.00',
      ]) {
        final receiptPipeline = OCRPipeline(
          textExtractor: (_) async => [totalLine],
        );

        final result = await receiptPipeline.process('/path/to/receipt.jpg');

        expect(
          result.payload.extractedFields.amount,
          243.00,
          reason: totalLine,
        );
      }
    });

    test('stub returns empty text lines in V1', () async {
      final result = await pipeline.process('/path/to/any.jpg');
      expect(result.textLines, isEmpty);
    });
  });
}

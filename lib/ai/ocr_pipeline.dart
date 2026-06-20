import 'dart:math';

import '../data/repositories/ai_processing_log_repo.dart';
import '../domain/value_objects/ocr_payload.dart';
import '../domain/value_objects/parsed_transaction.dart';
import 'nl_parser.dart';

class OcrResult {
  final OcrPayload payload;
  final List<String> textLines;

  const OcrResult({
    required this.payload,
    required this.textLines,
  });
}

class OCRPipeline {
  final NLParser _nlParser;
  final AiProcessingLogRepo? _logRepo;
  final bool _aiEnabled;

  const OCRPipeline({
    NLParser? nlParser,
    AiProcessingLogRepo? logRepo,
    bool aiEnabled = true,
  })  : _nlParser = nlParser ?? const NLParser(),
        _logRepo = logRepo,
        _aiEnabled = aiEnabled;

  String _generateId() {
    final r = Random();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  Future<OcrResult> process(String imagePath) async {
    if (!_aiEnabled) {
      return OcrResult(
        payload: const OcrPayload(
          rawText: '',
          extractedFields: ParsedTransaction(confidence: 0.0),
          confidence: 0.0,
        ),
        textLines: const [],
      );
    }

    final textLines = await _extractTextLines(imagePath);
    final rawText = textLines.join('\n');

    final logId = _generateId();

    if (rawText.trim().isEmpty) {
      _logRepo?.log(
        id: logId,
        sourceType: 'ocr',
        modelUsed: 'mlkit',
        extractedPayload: {'raw_text': '', 'image_path': imagePath},
        confidenceScore: 0.0,
      );
      return OcrResult(
        payload: const OcrPayload(
          rawText: '',
          extractedFields: ParsedTransaction(confidence: 0.0),
          confidence: 0.0,
        ),
        textLines: textLines,
      );
    }

    final result = _parseReceiptFields(rawText);
    final parseResult = _nlParser.parse(rawText);

    final extractedFields = parseResult?.parsed ?? ParsedTransaction(
      note: rawText,
      confidence: 0.0,
    );

    final amount = result.amount ?? extractedFields.amount;
    final payee = result.payee ?? extractedFields.payee;
    final confidence = result.confidence > extractedFields.confidence
        ? result.confidence
        : extractedFields.confidence;

    final payload = OcrPayload(
      rawText: rawText,
      extractedFields: extractedFields.copyWith(
        amount: () => amount,
        payee: () => payee,
        note: () => rawText,
        confidence: confidence,
      ),
      confidence: confidence,
    );

    _logRepo?.log(
      id: logId,
      sourceType: 'ocr',
      sourceReferenceId: parseResult?.rawText,
      modelUsed: 'mlkit',
      extractedPayload: {
        'raw_text': rawText,
        'image_path': imagePath,
        'text_lines': textLines,
        'receipt_fields': {
          'store_name': result.storeName,
          'amount': result.amount,
          'date': result.date,
        },
        'parsed_fields': {
          'amount': amount,
          'payee': payee,
          'is_transfer': parseResult?.isTransfer ?? false,
          'source_account': parseResult?.sourceAccount,
          'dest_account': parseResult?.destAccount,
        },
      },
      confidenceScore: confidence,
    );

    return OcrResult(
      payload: payload,
      textLines: textLines,
    );
  }

  Future<List<String>> _extractTextLines(String imagePath) async {
    // Stub: google_mlkit_text_recognition not yet integrated.
    // When added, replace with:
    //   final inputImage = InputImage.fromFilePath(imagePath);
    //   final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    //   final recognizedText = await textRecognizer.processImage(inputImage);
    //   return recognizedText.blocks
    //       .expand((b) => b.lines)
    //       .map((l) => l.text)
    //       .toList();
    return [];
  }

  _ReceiptFields _parseReceiptFields(String text) {
    String? storeName;
    double? amount;
    String? date;

    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    if (lines.isNotEmpty) {
      storeName = lines.first;
    }

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('total') || lower.contains('amount')) {
        final result = _nlParser.parse(line);
        if (result != null) {
          amount = result.parsed.amount;
        }
      }

      if (lower.contains('date') || lower.contains('time')) {
        date = line;
      }
    }

    return _ReceiptFields(storeName: storeName, amount: amount, date: date, confidence: storeName != null ? 0.5 : 0.0);
  }
}

class _ReceiptFields {
  final String? storeName;
  final double? amount;
  final String? date;
  final double confidence;

  const _ReceiptFields({this.storeName, this.amount, this.date, this.confidence = 0.0});

  String? get payee => storeName;
}

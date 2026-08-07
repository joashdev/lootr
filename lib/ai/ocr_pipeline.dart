import 'dart:io';
import 'dart:math';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../data/repositories/ai_processing_log_repo.dart';
import '../domain/value_objects/ocr_payload.dart';
import '../domain/value_objects/parsed_transaction.dart';
import 'nl_parser.dart';

/// Signature for the on-device text extraction step. Allows tests to inject a
/// deterministic extractor and the default implementation to call ML Kit.
typedef TextLineExtractor = Future<List<String>> Function(String imagePath);

class OcrResult {
  final OcrPayload payload;
  final List<String> textLines;

  const OcrResult({required this.payload, required this.textLines});
}

class OCRPipeline {
  static const _receiptTotalLabels = [
    'total amount due',
    'grand total',
    'total due',
    'amount due',
    'balance due',
    'net amount',
    'total',
  ];

  final NLParser _nlParser;
  final AiProcessingLogRepo? _logRepo;
  final bool _aiEnabled;
  final TextLineExtractor? _textExtractor;

  const OCRPipeline({
    NLParser? nlParser,
    AiProcessingLogRepo? logRepo,
    bool aiEnabled = true,
    TextLineExtractor? textExtractor,
  }) : _nlParser = nlParser ?? const NLParser(),
       // Keep public named arguments stable while storing them privately.
       // ignore: prefer_initializing_formals
       _logRepo = logRepo,
       // ignore: prefer_initializing_formals
       _aiEnabled = aiEnabled,
       // ignore: prefer_initializing_formals
       _textExtractor = textExtractor;

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

    final extractedFields =
        parseResult?.parsed ??
        ParsedTransaction(note: rawText, confidence: 0.0);

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

    return OcrResult(payload: payload, textLines: textLines);
  }

  Future<List<String>> _extractTextLines(String imagePath) async {
    // Allow tests / callers to inject a deterministic extractor.
    if (_textExtractor != null) {
      return _textExtractor(imagePath);
    }

    // Real on-device extraction via ML Kit. We only attempt this when the file
    // actually exists; non-existent paths (e.g. unit-test fixtures) return an
    // empty result rather than touching the platform channel.
    try {
      if (!File(imagePath).existsSync()) {
        return const [];
      }

      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final recognizedText = await recognizer.processImage(inputImage);
        return recognizedText.blocks
            .expand((block) => block.lines)
            .map((line) => line.text)
            .where((text) => text.trim().isNotEmpty)
            .toList();
      } finally {
        await recognizer.close();
      }
    } catch (_) {
      // ML Kit unavailable (e.g. running in a headless / test environment) or
      // the image could not be processed. Degrade gracefully to no text.
      return const [];
    }
  }

  _ReceiptFields _parseReceiptFields(String text) {
    String? storeName;
    double? amount;
    String? date;

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isNotEmpty) {
      storeName = lines.firstWhere((line) {
        final lower = line.toLowerCase();
        return !lower.contains('vat') &&
            !lower.contains('tin') &&
            !lower.contains('receipt') &&
            !RegExp(r'^\d+$').hasMatch(lower);
      }, orElse: () => lines.first);
    }

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (_looksLikeReceiptTotal(lower)) {
        final totalLabel = _receiptTotalLabels.firstWhere(lower.contains);
        final labelEnd = lower.indexOf(totalLabel) + totalLabel.length;
        final totalText = line
            .substring(labelEnd)
            .replaceAll(
              RegExp(r'\(\s*\d+\s*(?:items?)?\s*\)', caseSensitive: false),
              '',
            )
            .replaceAll(
              RegExp(
                r'\b(?:qty|quantity|count|items?)\s*[:x]?\s*\d+\b',
                caseSensitive: false,
              ),
              '',
            );
        final totalParseResult = _nlParser.parse(totalText);
        if (totalParseResult != null &&
            totalParseResult.parsed.amount != null) {
          amount = totalParseResult.parsed.amount;
        }
      }

      if (_looksLikeDateLine(lower)) {
        date = line;
      }
    }

    amount ??= _fallbackLargestAmount(lines);

    return _ReceiptFields(
      storeName: storeName,
      amount: amount,
      date: date,
      confidence: amount != null ? 0.72 : (storeName != null ? 0.5 : 0.0),
    );
  }

  bool _looksLikeReceiptTotal(String lower) {
    if (lower.contains('subtotal')) return false;
    return _receiptTotalLabels.any(lower.contains);
  }

  bool _looksLikeDateLine(String lower) {
    return lower.contains('date') ||
        lower.contains('time') ||
        RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b').hasMatch(lower) ||
        RegExp(r'\b\d{4}[/-]\d{1,2}[/-]\d{1,2}\b').hasMatch(lower);
  }

  double? _fallbackLargestAmount(List<String> lines) {
    double? best;
    for (final line in lines.reversed.take(12)) {
      final parsed = _nlParser.parse(line);
      final amount = parsed?.parsed.amount;
      if (amount == null) continue;
      if (best == null || amount > best) {
        best = amount;
      }
    }
    return best;
  }
}

class _ReceiptFields {
  final String? storeName;
  final double? amount;
  final String? date;
  final double confidence;

  const _ReceiptFields({
    this.storeName,
    this.amount,
    this.date,
    this.confidence = 0.0,
  });

  String? get payee => storeName;
}

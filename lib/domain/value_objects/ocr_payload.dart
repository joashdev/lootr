import 'parsed_transaction.dart';

class OcrPayload {
  final String rawText;
  final ParsedTransaction extractedFields;
  final double confidence;

  const OcrPayload({
    required this.rawText,
    required this.extractedFields,
    this.confidence = 0.0,
  });

  @override
  bool operator ==(Object other) =>
      other is OcrPayload &&
      rawText == other.rawText &&
      extractedFields == other.extractedFields &&
      confidence == other.confidence;

  @override
  int get hashCode => Object.hash(rawText, extractedFields, confidence);

  @override
  String toString() =>
      'OcrPayload(rawText=$rawText, extractedFields=$extractedFields, '
      'confidence=$confidence)';
}

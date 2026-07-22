import 'dart:math';

import '../data/repositories/ai_processing_log_repo.dart';
import '../domain/value_objects/field_types.dart';

class CategorySuggestion {
  final String categoryId;
  final double confidence;
  final String source;

  const CategorySuggestion({
    required this.categoryId,
    this.confidence = 0.0,
    required this.source,
  });

  bool get isDeterministic => source == 'history';

  @override
  bool operator ==(Object other) =>
      other is CategorySuggestion &&
      categoryId == other.categoryId &&
      confidence == other.confidence &&
      source == other.source;

  @override
  int get hashCode => Object.hash(categoryId, confidence, source);

  @override
  String toString() =>
      'CategorySuggestion(categoryId=$categoryId, confidence=$confidence, '
      'source=$source)';
}

class Categorizer {
  final Map<String, String> payeeCategoryHistory;
  final bool modelEnabled;
  final AiProcessingLogRepo? _logRepo;
  final bool aiEnabled;

  const Categorizer({
    this.payeeCategoryHistory = const {},
    this.modelEnabled = false,
    AiProcessingLogRepo? logRepo,
    this.aiEnabled = true,
    // Keep the public named argument stable while storing it privately.
    // ignore: prefer_initializing_formals
  }) : _logRepo = logRepo;

  Categorizer copyWith({
    Map<String, String>? payeeCategoryHistory,
    bool? modelEnabled,
    AiProcessingLogRepo? logRepo,
    bool? aiEnabled,
  }) {
    return Categorizer(
      payeeCategoryHistory: payeeCategoryHistory ?? this.payeeCategoryHistory,
      modelEnabled: modelEnabled ?? this.modelEnabled,
      logRepo: logRepo ?? _logRepo,
      aiEnabled: aiEnabled ?? this.aiEnabled,
    );
  }

  String _generateId() {
    final r = Random();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  Future<CategorySuggestion?> suggest({
    double? amount,
    required String? payee,
    String? note,
    String? direction,
  }) async {
    if (!aiEnabled) return null;
    if (payee == null && note == null) return null;

    final normalizedPayee = payee?.toLowerCase().trim();

    if (normalizedPayee != null &&
        payeeCategoryHistory.containsKey(normalizedPayee)) {
      final result = CategorySuggestion(
        categoryId: payeeCategoryHistory[normalizedPayee]!,
        confidence: 0.9,
        source: 'history',
      );
      _logRepo?.log(
        id: _generateId(),
        sourceType: 'categorization',
        sourceReferenceId: payee,
        modelUsed: 'history',
        extractedPayload: {
          'payee': payee,
          'amount': amount,
          'note': note,
          'direction': direction,
          'result': result.categoryId,
          'source': result.source,
        },
        confidenceScore: result.confidence,
      );
      return result;
    }

    if (direction == TransactionDirection.income) {
      const result = CategorySuggestion(
        categoryId: 'Income',
        confidence: 0.7,
        source: 'heuristic',
      );
      _logRepo?.log(
        id: _generateId(),
        sourceType: 'categorization',
        sourceReferenceId: payee,
        modelUsed: 'heuristic',
        extractedPayload: {
          'payee': payee,
          'amount': amount,
          'note': note,
          'direction': direction,
          'result': 'Income',
          'source': 'heuristic',
        },
        confidenceScore: 0.7,
      );
      return result;
    }

    if (note != null) {
      final lowerNote = note.toLowerCase();
      const keywordMap = {
        'food': 'Food',
        'groceries': 'Groceries',
        'transport': 'Transport',
        'gas': 'Transport',
        'rent': 'Rent',
        'utilities': 'Utilities',
        'shopping': 'Shopping',
        'health': 'Health',
        'dining': 'Dining',
      };
      for (final entry in keywordMap.entries) {
        if (lowerNote.contains(entry.key)) {
          final result = CategorySuggestion(
            categoryId: entry.value,
            confidence: 0.5,
            source: 'heuristic',
          );
          _logRepo?.log(
            id: _generateId(),
            sourceType: 'categorization',
            sourceReferenceId: payee,
            modelUsed: 'heuristic',
            extractedPayload: {
              'payee': payee,
              'amount': amount,
              'note': note,
              'direction': direction,
              'result': entry.value,
              'source': 'heuristic',
              'matched_keyword': entry.key,
            },
            confidenceScore: 0.5,
          );
          return result;
        }
      }
    }

    if (modelEnabled) {
      return await _aiCategorize(amount: amount, payee: payee, note: note);
    }

    return null;
  }

  Future<CategorySuggestion?> _aiCategorize({
    double? amount,
    String? payee,
    String? note,
  }) async {
    // Stub: llama.cpp / GGUF model inference not yet integrated.
    // When added, replace with inference call using a downloaded model.
    return null;
  }
}

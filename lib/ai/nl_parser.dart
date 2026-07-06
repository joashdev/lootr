import 'dart:math';

import '../data/repositories/ai_processing_log_repo.dart';
import '../domain/value_objects/parsed_transaction.dart';
import '../domain/value_objects/field_types.dart';

class _AmountMatch {
  final double value;
  final String matchedText;

  const _AmountMatch(this.value, this.matchedText);
}

class ParseResult {
  final ParsedTransaction parsed;
  final String? rawText;
  final bool isTransfer;
  final String? sourceAccount;
  final String? destAccount;

  const ParseResult({
    required this.parsed,
    this.rawText,
    this.isTransfer = false,
    this.sourceAccount,
    this.destAccount,
  });
}

class NLParser {
  static const _accountKeywords = {
    'unionbank': 'unionbank',
    'seabank': 'seabank',
    'gotyme': 'gotyme',
    'gcash': 'gcash',
    'maya': 'maya',
    'cash': 'cash',
    'bank': 'bank',
    'bpi': 'bpi',
    'bdo': 'bdo',
    'credit': 'credit_card',
    'card': 'credit_card',
    'wallet': 'ewallet',
    'savings': 'savings',
  };

  static const _accountTokens = [
    'unionbank', 'seabank', 'gotyme',
    'gcash', 'maya', 'cash', 'bank', 'bpi', 'bdo',
    'credit', 'card', 'wallet', 'savings',
  ];

  static const _categoryKeywords = {
    'food': 'Food',
    'groceries': 'Groceries',
    'transport': 'Transport',
    'fare': 'Transport',
    'gas': 'Transport',
    'fuel': 'Transport',
    'rent': 'Rent',
    'utilities': 'Utilities',
    'electric': 'Utilities',
    'water': 'Utilities',
    'internet': 'Utilities',
    'shopping': 'Shopping',
    'clothes': 'Shopping',
    'health': 'Health',
    'medical': 'Health',
    'pharmacy': 'Health',
    'entertainment': 'Entertainment',
    'movie': 'Entertainment',
    'dining': 'Dining',
    'restaurant': 'Dining',
    'coffee': 'Dining',
    'salary': 'Income',
    'income': 'Income',
    'freelance': 'Income',
  };

  static const _categoryTokens = [
    'food', 'groceries', 'transport', 'fare', 'gas', 'fuel',
    'rent', 'utilities', 'electric', 'water', 'internet',
    'shopping', 'clothes', 'health', 'medical', 'pharmacy',
    'entertainment', 'movie', 'dining', 'restaurant', 'coffee',
  ];

  static const _incomeTokens = [
    'received', 'income', 'earned',
  ];

  static const _incomeKeywords = [
    'received', 'income', 'got', 'earned', 'salary', 'refund',
  ];

  static const _transferKeywords = [
    'transfer', 'send', 'sent', 'move', 'moved',
  ];

  final List<String> knownPayees;
  final List<String> knownAccounts;
  final Map<String, String> payeeCategoryHistory;
  final AiProcessingLogRepo? _logRepo;
  final bool aiEnabled;

  const NLParser({
    this.knownPayees = const [],
    this.knownAccounts = const [],
    this.payeeCategoryHistory = const {},
    AiProcessingLogRepo? logRepo,
    this.aiEnabled = true,
  }) : _logRepo = logRepo;

  NLParser copyWith({
    List<String>? knownPayees,
    List<String>? knownAccounts,
    Map<String, String>? payeeCategoryHistory,
    AiProcessingLogRepo? logRepo,
    bool? aiEnabled,
  }) {
    return NLParser(
      knownPayees: knownPayees ?? this.knownPayees,
      knownAccounts: knownAccounts ?? this.knownAccounts,
      payeeCategoryHistory:
          payeeCategoryHistory ?? this.payeeCategoryHistory,
      logRepo: logRepo ?? _logRepo,
      aiEnabled: aiEnabled ?? this.aiEnabled,
    );
  }

  String _generateId() {
    final r = Random();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  ParseResult? parse(String rawText) {
    if (rawText.trim().isEmpty) return null;
    if (!aiEnabled) return null;

    final text = rawText.trim();

    final isTransfer = _detectTransfer(text);
    final amountMatch = _extractAmount(text);

    if (amountMatch == null) return null;

    String? sourceAccount;
    String? destAccount;
    if (isTransfer) {
      final accounts = _extractTransferAccounts(text);
      sourceAccount = accounts.$1;
      destAccount = accounts.$2;
    }

    final direction = isTransfer
        ? TransactionDirection.transfer
        : _extractDirection(text);
    final account = isTransfer
        ? (destAccount ?? sourceAccount ?? _extractAccount(text))
        : _extractAccount(text);
    final payee = _extractPayee(text, amountMatch);
    final category = _extractCategory(text);

    final confidence = _computeConfidence(
      amountMatch.value,
      payee,
      account,
      category,
      isTransfer,
    );

    final logId = _generateId();
    _logRepo?.log(
      id: logId,
      sourceType: 'nlp',
      modelUsed: 'regex',
      extractedPayload: {
        'raw_text': rawText,
        'parsed': {
          'amount': amountMatch.value,
          'payee': payee,
          'account': account,
          'category': category,
          'direction': direction,
          'is_transfer': isTransfer,
          'source_account': sourceAccount,
          'dest_account': destAccount,
        },
      },
      confidenceScore: confidence,
    );

    return ParseResult(
      parsed: ParsedTransaction(
        amount: amountMatch.value,
        payee: payee,
        account: account,
        category: category,
        direction: direction,
        note: text,
        confidence: confidence,
        isTransfer: isTransfer,
        sourceAccount: sourceAccount,
        destAccount: destAccount,
      ),
      rawText: rawText,
      isTransfer: isTransfer,
      sourceAccount: sourceAccount,
      destAccount: destAccount,
    );
  }

  bool _detectTransfer(String text) {
    final lower = text.toLowerCase();
    if (_transferKeywords.any((k) => lower.contains(k))) return true;
    if (lower.contains(' from ') && lower.contains(' to ')) return true;
    return false;
  }

  (String?, String?) _extractTransferAccounts(String text) {
    final lower = text.toLowerCase();

    final fromPattern = RegExp(r'(?:from|send|sent|transfer)\s+([a-zA-Z]\w*)', caseSensitive: false);
    final toPattern = RegExp(r'(?:to|into)\s+([a-zA-Z]\w*)', caseSensitive: false);

    String? source;
    String? dest;

    final fromMatch = fromPattern.firstMatch(text);
    if (fromMatch != null) {
      final original = fromMatch.group(1)!;
      final word = original.toLowerCase();
      source = _accountKeywords[word] ?? original;
    }

    final toMatch = toPattern.firstMatch(text);
    if (toMatch != null) {
      final original = toMatch.group(1)!;
      final word = original.toLowerCase();
      dest = _accountKeywords[word] ?? original;
    }

    final accountWords = _accountTokens
        .where((a) => lower.contains(a))
        .toList();

    if (source == null && dest == null && accountWords.length >= 2) {
      source = accountWords[0];
      dest = accountWords[1];
    } else if (source == null && dest != null) {
      final otherWord = accountWords
          .firstWhere((a) => a != dest, orElse: () => '');
      if (otherWord.isNotEmpty) source = otherWord;
    } else if (source != null && dest == null) {
      final otherWord = accountWords
          .firstWhere((a) => a != source, orElse: () => '');
      if (otherWord.isNotEmpty) dest = otherWord;
    }

    if (source == null) {
      for (final acc in knownAccounts) {
        if (lower.contains(acc.toLowerCase())) {
          if (dest != null && acc.toLowerCase() != dest.toLowerCase()) {
            source = acc;
            break;
          }
        }
      }
    }
    if (dest == null && source != null) {
      for (final acc in knownAccounts) {
        if (lower.contains(acc.toLowerCase())) {
          if (acc.toLowerCase() != source.toLowerCase()) {
            dest = acc;
            break;
          }
        }
      }
    }

    return (source, dest);
  }

  _AmountMatch? _extractAmount(String text) {
    final currencyPattern = RegExp(
        r'(?:[₱\$€£¥]\s*)?(-?(?:\d+(?:,\d{3})*(?:\.\d+)?|\.\d+))\s*(k|K|m|M)?\b');
    final match = currencyPattern.firstMatch(text);
    if (match == null) return null;

    var value = double.tryParse(match.group(1)!.replaceAll(',', ''));
    if (value == null) return null;

    final suffix = match.group(2);
    if (suffix != null) {
      if (suffix.toLowerCase() == 'k') value *= 1000;
      if (suffix.toLowerCase() == 'm') value *= 1000000;
    }

    return _AmountMatch(value, match.group(0)!);
  }

  String? _extractDirection(String text) {
    final lower = text.toLowerCase();
    if (_incomeKeywords.any((k) => lower.contains(k))) {
      return TransactionDirection.income;
    }
    return TransactionDirection.expense;
  }

  String? _extractAccount(String text) {
    final lower = text.toLowerCase();

    for (final acc in knownAccounts) {
      final pattern = RegExp(r'\b' + RegExp.escape(acc.toLowerCase()) + r'\b');
      if (pattern.hasMatch(lower)) return acc;
    }

    for (final entry in _accountKeywords.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  String? _extractPayee(String text, _AmountMatch? amountMatch) {
    var clean = text;

    if (amountMatch != null) {
      clean = clean.replaceFirst(amountMatch.matchedText, '');
    }

    clean = clean
        .replaceAll(RegExp(r'[₱\$€£¥]'), '')
        .replaceAll(RegExp(r'\b(from|to|into)\s+\w+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (clean.isEmpty) return null;

    final words = clean.split(' ');

    final nonMetaWords = words
        .where((w) =>
            !_accountTokens.contains(w.toLowerCase()) &&
            !_categoryTokens.contains(w.toLowerCase()) &&
            !_transferKeywords.contains(w.toLowerCase()) &&
            !_incomeTokens.contains(w.toLowerCase()))
        .toList();

    // Drop leading connector words left behind after meta words are removed,
    // e.g. "Coffee at Starbucks" -> "at Starbucks" once "coffee" (a category
    // token) is filtered out. The payee should be "Starbucks", not
    // "at Starbucks".
    const connectors = {'at', 'in', 'on', 'for'};
    while (nonMetaWords.isNotEmpty &&
        connectors.contains(nonMetaWords.first.toLowerCase())) {
      nonMetaWords.removeAt(0);
    }

    if (nonMetaWords.isEmpty) return null;
    final candidate = nonMetaWords.join(' ');

    for (final known in knownPayees) {
      if (candidate.toLowerCase().contains(known.toLowerCase())) return known;
    }

    return candidate;
  }

  String? _extractCategory(String text) {
    final lower = text.toLowerCase();

    for (final entry in _categoryKeywords.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  double _computeConfidence(
    double? amount,
    String? payee,
    String? account,
    String? category,
    bool isTransfer,
  ) {
    int fields = 0;
    int filled = 0;
    if (amount != null) filled++;
    fields++;
    if (payee != null) filled++;
    fields++;
    if (account != null) filled++;
    fields++;
    if (category != null) filled++;
    fields++;
    if (isTransfer) filled++;
    fields++;
    return fields > 0 ? filled / fields : 0.0;
  }
}

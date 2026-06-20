import '../value_objects/result.dart';
import '../value_objects/parsed_transaction.dart';
import '../value_objects/field_types.dart';

class _AmountMatch {
  final double value;
  final String matchedText;

  const _AmountMatch(this.value, this.matchedText);
}

class ParseNL {
  Result<ParsedTransaction> call(String rawText) {
    if (rawText.trim().isEmpty) {
      return Failure('Input text is empty', code: 'empty_input');
    }

    final text = rawText.trim();

    final amountMatch = _extractAmount(text);
    final direction = _extractDirection(text);
    final account = _extractAccount(text);
    final payee = _extractPayee(text, amountMatch);
    final category = _extractCategory(text);

    if (amountMatch == null) {
      return Failure('Could not extract amount from input',
          code: 'parse_failed');
    }

    final amount = amountMatch.value;
    final confidence =
        _computeConfidence(amount, payee, account, category);

    return Success(ParsedTransaction(
      amount: amount,
      payee: payee,
      account: account,
      category: category,
      direction: direction,
      note: text,
      confidence: confidence,
    ));
  }

  _AmountMatch? _extractAmount(String text) {
    final currencyPattern = RegExp(
        r'(?:[₱\$€£¥]\s*)?(-?(?:\d+(?:,\d{3})*(?:\.\d+)?|\.\d+))\s*(k|K|m|M)?');
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
    if (RegExp(r'\b(received|income|got|earned|salary|refund)\b')
        .hasMatch(lower)) {
      return TransactionDirection.income;
    }
    return TransactionDirection.expense;
  }

  String? _extractAccount(String text) {
    final lower = text.toLowerCase();
    const accountKeywords = {
      'gcash': 'gcash',
      'maya': 'maya',
      'cash': 'cash',
      'bank': 'bank',
      'bpi': 'bpi',
      'bdo': 'bdo',
      'unionbank': 'unionbank',
      'gotyme': 'gotyme',
      'seabank': 'seabank',
      'credit': 'credit_card',
      'card': 'credit_card',
      'wallet': 'ewallet',
      'savings': 'savings',
    };

    for (final entry in accountKeywords.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static const _accountKeywords = [
    'gcash', 'maya', 'cash', 'bank', 'bpi', 'bdo',
    'unionbank', 'gotyme', 'seabank', 'credit', 'card',
    'wallet', 'savings',
  ];

  static const _categoryKeywords = [
    'food', 'groceries', 'transport', 'fare', 'gas', 'fuel',
    'rent', 'utilities', 'electric', 'water', 'internet',
    'shopping', 'clothes', 'health', 'medical', 'pharmacy',
    'entertainment', 'movie', 'dining', 'restaurant', 'coffee',
    'salary', 'income', 'freelance',
  ];

  String? _extractPayee(String text, _AmountMatch? amountMatch) {
    var clean = text;

    if (amountMatch != null) {
      clean = clean.replaceFirst(amountMatch.matchedText, '');
    }

    clean = clean
        .replaceAll(RegExp(r'[₱\$€£¥]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (clean.isEmpty) return null;

    final words = clean.split(' ');

    final nonMetaWords = words
        .where((w) =>
            !_accountKeywords.contains(w.toLowerCase()) &&
            !_categoryKeywords.contains(w.toLowerCase()))
        .toList();

    if (nonMetaWords.isEmpty) return null;
    return nonMetaWords.join(' ');
  }

  String? _extractCategory(String text) {
    final lower = text.toLowerCase();
    const categoryKeywords = {
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

    for (final entry in categoryKeywords.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  double _computeConfidence(
    double? amount,
    String? payee,
    String? account,
    String? category,
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
    return fields > 0 ? filled / fields : 0.0;
  }
}

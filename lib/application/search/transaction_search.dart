import '../../domain/entities/payee.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/value_objects/exact_money.dart';

/// Deterministic search constraints extracted from the ledger search field.
///
/// Recognized constraints compose with each other using AND semantics. Any
/// remaining input is matched as text using the existing phrase behavior.
class TransactionSearch {
  TransactionSearch._({
    required this.text,
    required this.periods,
    required this.amount,
  });

  factory TransactionSearch.parse(String query) {
    var remainder = normalizeSearchText(query);
    ExactMoney? amount;
    final periods = <({int month, int? year})>[];

    remainder = remainder.replaceAllMapped(
      RegExp(r'\b(?:([a-z]{3})\s+(\d+\.\d+)|(\d+\.\d+)\s+([a-z]{3}))\b'),
      (match) {
        if (amount != null) return match.group(0)!;
        final currency = (match.group(1) ?? match.group(4)!).toUpperCase();
        final decimal = match.group(2) ?? match.group(3)!;
        amount = ExactMoney.parse(decimal, currency);
        return ' ';
      },
    );

    remainder = remainder.replaceAllMapped(
      RegExp(r'\b(\d{4})-(0[1-9]|1[0-2])\b'),
      (match) {
        periods.add((
          month: int.parse(match.group(2)!),
          year: int.parse(match.group(1)!),
        ));
        return ' ';
      },
    );

    remainder = remainder.replaceAllMapped(
      RegExp(
        r'\b(january|february|march|april|may|june|july|august|'
        r'september|october|november|december)(?:\s+(\d{4}))?\b',
      ),
      (match) {
        periods.add((
          month: _monthNames.indexOf(match.group(1)!) + 1,
          year: match.group(2) == null ? null : int.parse(match.group(2)!),
        ));
        return ' ';
      },
    );

    return TransactionSearch._(
      text: remainder.replaceAll(RegExp(r'\s+'), ' ').trim(),
      periods: List.unmodifiable(periods),
      amount: amount,
    );
  }

  final String text;
  final List<({int month, int? year})> periods;
  final ExactMoney? amount;

  bool matches(Transaction transaction, Payee? payee) {
    if (periods.any(
      (period) =>
          transaction.occurredAt.month != period.month ||
          (period.year != null && transaction.occurredAt.year != period.year),
    )) {
      return false;
    }

    final expectedAmount = amount;
    if (expectedAmount != null) {
      final storedAmount = transaction.exactAmount;
      final actualAmount = ExactMoney(
        coefficient: storedAmount.coefficient,
        scale: storedAmount.scale,
        currencyCode: storedAmount.currencyCode.toUpperCase(),
      );
      if (actualAmount.currencyCode != expectedAmount.currencyCode ||
          actualAmount.compareTo(expectedAmount) != 0) {
        return false;
      }
    }

    if (text.isEmpty) return true;
    final values = <String?>[
      transaction.title,
      transaction.note,
      transaction.amount.toString(),
      transaction.amount.toStringAsFixed(2),
      payee?.displayName,
      payee?.normalizedName,
    ];
    return values.any(
      (value) => value != null && normalizeSearchText(value).contains(text),
    );
  }
}

/// Lower-cases and strips diacritics for accent-insensitive search.
String normalizeSearchText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp('[àáâãäåāăą]'), 'a')
      .replaceAll(RegExp('[çćč]'), 'c')
      .replaceAll(RegExp('[ďđ]'), 'd')
      .replaceAll(RegExp('[èéêëēĕėęě]'), 'e')
      .replaceAll(RegExp('[ìíîïīĭįı]'), 'i')
      .replaceAll(RegExp('[ñńň]'), 'n')
      .replaceAll(RegExp('[òóôõöøōŏő]'), 'o')
      .replaceAll(RegExp('[ŕř]'), 'r')
      .replaceAll(RegExp('[śšş]'), 's')
      .replaceAll(RegExp('[ťţ]'), 't')
      .replaceAll(RegExp('[ùúûüūŭůűų]'), 'u')
      .replaceAll(RegExp('[ýÿ]'), 'y')
      .replaceAll(RegExp('[žźż]'), 'z')
      .trim();
}

const _monthNames = [
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];

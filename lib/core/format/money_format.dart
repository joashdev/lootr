import 'package:intl/intl.dart';

import '../../domain/value_objects/exact_money.dart';

/// Centralized currency formatting for Lootr.
///
/// Formatting registers chosen by how much space and precision a figure needs:
///
///  * [exactMoney] — full, grouped, configured-scale form. Use for persisted
///    financial values on rows and detail screens.
///  * [exact] — compatibility formatter for numeric projections.
///  * [display] — space-aware summary form for dashboard headlines and cards.
///    Drops centavos, and switches to compact `K`/`M`/`B` notation once a
///    number would otherwise run long. The precise value is always one tap
///    away on the underlying detail screen.
///
/// Every formatter honours its currency identifier rather than hard-coding
/// `₱`.
abstract class MoneyFormat {
  MoneyFormat._();

  /// Threshold above which [display] abbreviates instead of grouping in full.
  /// Below ₱1,000,000 a grouped integer (`₱999,999`) still reads cleanly; at or
  /// above it we switch to compact (`₱1.2M`) to keep headlines from truncating.
  static const double _compactFrom = 1000000;

  static String symbolFor(String currencyCode) {
    switch (currencyCode) {
      case 'PHP':
        return '₱';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      default:
        return currencyCode;
    }
  }

  /// Precise, grouped, two-decimal: `₱24,000.23`.
  static String exact(num amount, String currencyCode, {String? locale}) {
    return NumberFormat.currency(
      locale: locale,
      symbol: symbolFor(currencyCode),
      name: currencyCode,
    ).format(amount);
  }

  /// Precise, grouped formatting that preserves the value's configured scale.
  ///
  /// This path never projects through [double], so imported 4- and 12-decimal
  /// values remain byte-for-byte legible at their source precision.
  static String exactMoney(ExactMoney amount) {
    final digits = amount.coefficient.abs().toString().padLeft(
      amount.scale + 1,
      '0',
    );
    final wholeLength = digits.length - amount.scale;
    final whole = digits.substring(0, wholeLength);
    final groupedWhole = whole.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final fraction = amount.scale == 0
        ? ''
        : '.${digits.substring(wholeLength)}';
    final sign = amount.isNegative ? '-' : '';

    return '$sign${symbolFor(amount.currencyCode)}$groupedWhole$fraction';
  }

  /// Summary form tuned to fit headline/card space.
  ///
  ///  * `|amount| < 1,000,000` → grouped integer, no centavos: `₱24,000`
  ///  * `|amount| >= 1,000,000` → compact, one decimal: `₱1.2M` · `₱24.0M` · `₱1.2B`
  ///
  /// Sign is rendered ahead of the symbol so negatives read as `-₱24,000`.
  static String display(num amount, String currencyCode, {String? locale}) {
    final symbol = symbolFor(currencyCode);
    final sign = amount < 0 ? '-' : '';
    final abs = amount.abs();

    if (abs >= _compactFrom) {
      final compact = NumberFormat.compactCurrency(
        locale: locale,
        symbol: symbol,
        decimalDigits: 1,
      ).format(abs);
      return '$sign$compact';
    }

    return '$sign$symbol${NumberFormat('#,##0', locale).format(abs)}';
  }
}

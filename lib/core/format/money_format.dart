import 'package:intl/intl.dart';

/// Centralized currency formatting for Lootr.
///
/// Two registers, chosen by how much space the figure has to live in:
///
///  * [exact] — full, grouped, two-decimal form (e.g. `₱24,000.23`). Use on
///    transaction rows, detail screens, and inputs — anywhere the precise
///    figure matters and there is room for it.
///  * [display] — space-aware summary form for dashboard headlines and cards.
///    Drops centavos, and switches to compact `K`/`M`/`B` notation once a
///    number would otherwise run long. The precise value is always one tap
///    away on the underlying detail screen.
///
/// Both honour the account's [currencyCode] rather than hard-coding `₱`.
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

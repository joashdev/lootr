import 'package:intl/intl.dart';

class Money {
  final double amount;
  final String currencyCode;

  const Money(this.amount, this.currencyCode);

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(amount + other.amount, currencyCode);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(amount - other.amount, currencyCode);
  }

  Money abs() => Money(amount.abs(), currencyCode);

  String format({String? locale}) {
    final fmt = NumberFormat.currency(
      symbol: _currencySymbol(currencyCode),
      name: currencyCode,
      locale: locale,
    );
    return fmt.format(amount);
  }

  void _assertSameCurrency(Money other) {
    if (currencyCode != other.currencyCode) {
      throw ArgumentError(
        'Currency mismatch: $currencyCode vs ${other.currencyCode}',
      );
    }
  }

  String _currencySymbol(String code) {
    switch (code) {
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
        return code;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Money && amount == other.amount && currencyCode == other.currencyCode;

  @override
  int get hashCode => Object.hash(amount, currencyCode);

  @override
  String toString() => 'Money($amount $currencyCode)';
}

/// Exact base-10 representation used while inspecting SQLite REAL values.
///
/// SQLite exposes REAL values as binary doubles. Dart's `double.toString()`
/// gives the shortest decimal which round-trips to that binary value. Parsing
/// that text into a coefficient and scale lets migration reconciliation avoid
/// any further floating-point aggregation.
final class CashewDecimal implements Comparable<CashewDecimal> {
  const CashewDecimal._(this.coefficient, this.scale);

  factory CashewDecimal.parse(String source) {
    final value = source.trim().toLowerCase();
    final match = RegExp(
      r'^([+-]?)(\d+)(?:\.(\d*))?(?:e([+-]?\d+))?$',
    ).firstMatch(value);
    if (match == null) {
      throw const FormatException('Invalid decimal value');
    }

    final negative = match.group(1) == '-';
    final whole = match.group(2)!;
    final fraction = match.group(3) ?? '';
    final exponent = int.tryParse(match.group(4) ?? '0');
    if (exponent == null) {
      throw const FormatException('Invalid decimal exponent');
    }

    var coefficient = BigInt.parse('$whole$fraction');
    if (negative) coefficient = -coefficient;
    var scale = fraction.length - exponent;
    if (scale < 0) {
      coefficient *= _pow10(-scale);
      scale = 0;
    }
    return CashewDecimal._normalize(coefficient, scale);
  }

  factory CashewDecimal.fromSqlite(Object value) {
    return switch (value) {
      int integer => CashewDecimal.parse(integer.toString()),
      double real when real.isFinite => CashewDecimal.parse(real.toString()),
      String text => CashewDecimal.parse(text),
      _ => throw const FormatException('Unsupported SQLite numeric value'),
    };
  }

  factory CashewDecimal._normalize(BigInt coefficient, int scale) {
    if (coefficient == BigInt.zero) {
      return CashewDecimal._(BigInt.zero, 0);
    }
    var normalized = coefficient;
    var normalizedScale = scale;
    while (normalizedScale > 0 &&
        normalized.remainder(BigInt.from(10)) == BigInt.zero) {
      normalized ~/= BigInt.from(10);
      normalizedScale--;
    }
    return CashewDecimal._(normalized, normalizedScale);
  }

  static final zero = CashewDecimal._(BigInt.zero, 0);

  final BigInt coefficient;
  final int scale;

  bool get isNegative => coefficient.isNegative;
  bool get isZero => coefficient == BigInt.zero;
  CashewDecimal get absolute =>
      isNegative ? CashewDecimal._(-coefficient, scale) : this;
  CashewDecimal get negated => CashewDecimal._(-coefficient, scale);

  CashewDecimal operator +(CashewDecimal other) {
    final targetScale = scale > other.scale ? scale : other.scale;
    final left = coefficient * _pow10(targetScale - scale);
    final right = other.coefficient * _pow10(targetScale - other.scale);
    return CashewDecimal._normalize(left + right, targetScale);
  }

  CashewDecimal operator -(CashewDecimal other) => this + other.negated;

  /// Rounds to [precision] decimal places, using round-half-to-even.
  CashewDecimal quantized(int precision) {
    if (precision < 0) {
      throw ArgumentError.value(precision, 'precision');
    }
    if (scale <= precision) {
      return CashewDecimal._(
        coefficient * _pow10(precision - scale),
        precision,
      );
    }

    final divisor = _pow10(scale - precision);
    final magnitude = coefficient.abs();
    var quotient = magnitude ~/ divisor;
    final remainder = magnitude.remainder(divisor);
    final doubledRemainder = remainder * BigInt.two;
    if (doubledRemainder > divisor ||
        (doubledRemainder == divisor && quotient.isOdd)) {
      quotient += BigInt.one;
    }
    if (coefficient.isNegative) quotient = -quotient;
    return CashewDecimal._(quotient, precision);
  }

  String toPlainString() {
    final negative = coefficient.isNegative;
    var digits = coefficient.abs().toString();
    if (scale == 0) return '${negative ? '-' : ''}$digits';
    if (digits.length <= scale) {
      final padding = List.filled(scale - digits.length + 1, '0').join();
      digits = '$padding$digits';
    }
    final split = digits.length - scale;
    return '${negative ? '-' : ''}${digits.substring(0, split)}.'
        '${digits.substring(split)}';
  }

  @override
  int compareTo(CashewDecimal other) {
    final targetScale = scale > other.scale ? scale : other.scale;
    return (coefficient * _pow10(targetScale - scale)).compareTo(
      other.coefficient * _pow10(targetScale - other.scale),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CashewDecimal && compareTo(other) == 0;

  @override
  int get hashCode {
    final normalized = CashewDecimal._normalize(coefficient, scale);
    return Object.hash(normalized.coefficient, normalized.scale);
  }

  @override
  String toString() => toPlainString();

  static BigInt _pow10(int exponent) {
    var result = BigInt.one;
    for (var i = 0; i < exponent; i++) {
      result *= BigInt.from(10);
    }
    return result;
  }
}

enum MoneyRoundingMode { reject, towardZero, awayFromZero, halfUp, halfEven }

/// Exact fixed-scale money represented as an integer coefficient.
///
/// A value of `123.4500 USD` is stored as coefficient `1234500`, scale `4`,
/// and currency `USD`. Scale is intentionally preserved because imported
/// account precision is part of the financial record.
class ExactMoney implements Comparable<ExactMoney> {
  ExactMoney({
    required this.coefficient,
    required this.scale,
    required String currencyCode,
  }) : currencyCode = currencyCode.trim() {
    if (scale < 0) {
      throw ArgumentError.value(scale, 'scale', 'must not be negative');
    }
    if (this.currencyCode.isEmpty) {
      throw ArgumentError.value(
        currencyCode,
        'currencyCode',
        'must not be empty',
      );
    }
  }

  factory ExactMoney.parse(String value, String currencyCode) {
    final match = RegExp(
      r'^([+-]?)(\d+)(?:\.(\d+))?$',
    ).firstMatch(value.trim());
    if (match == null) {
      throw FormatException('Invalid decimal money value');
    }

    final sign = match.group(1) == '-' ? BigInt.from(-1) : BigInt.one;
    final whole = match.group(2)!;
    final fraction = match.group(3) ?? '';
    final digits = '$whole$fraction';

    return ExactMoney(
      coefficient: BigInt.parse(digits) * sign,
      scale: fraction.length,
      currencyCode: currencyCode,
    );
  }

  final BigInt coefficient;
  final int scale;
  final String currencyCode;

  bool get isNegative => coefficient.isNegative;
  bool get isZero => coefficient == BigInt.zero;

  ExactMoney abs() => ExactMoney(
    coefficient: coefficient.abs(),
    scale: scale,
    currencyCode: currencyCode,
  );

  ExactMoney operator -() => ExactMoney(
    coefficient: -coefficient,
    scale: scale,
    currencyCode: currencyCode,
  );

  ExactMoney operator +(ExactMoney other) {
    _requireSameCurrency(other);
    final commonScale = scale > other.scale ? scale : other.scale;
    return ExactMoney(
      coefficient:
          _coefficientAt(commonScale) + other._coefficientAt(commonScale),
      scale: commonScale,
      currencyCode: currencyCode,
    );
  }

  ExactMoney operator -(ExactMoney other) => this + (-other);

  ExactMoney rescale(
    int newScale, {
    MoneyRoundingMode rounding = MoneyRoundingMode.reject,
  }) {
    if (newScale < 0) {
      throw ArgumentError.value(newScale, 'newScale', 'must not be negative');
    }
    if (newScale == scale) return this;
    if (newScale > scale) {
      return ExactMoney(
        coefficient: coefficient * _powerOfTen(newScale - scale),
        scale: newScale,
        currencyCode: currencyCode,
      );
    }

    final divisor = _powerOfTen(scale - newScale);
    final quotient = coefficient ~/ divisor;
    final remainder = coefficient.remainder(divisor);
    if (remainder == BigInt.zero) {
      return ExactMoney(
        coefficient: quotient,
        scale: newScale,
        currencyCode: currencyCode,
      );
    }
    if (rounding == MoneyRoundingMode.reject) {
      throw StateError('Rescaling would lose precision');
    }

    final direction = coefficient.isNegative ? -BigInt.one : BigInt.one;
    final rounded = switch (rounding) {
      MoneyRoundingMode.towardZero => quotient,
      MoneyRoundingMode.awayFromZero => quotient + direction,
      MoneyRoundingMode.halfUp =>
        remainder.abs() * BigInt.two >= divisor
            ? quotient + direction
            : quotient,
      MoneyRoundingMode.halfEven => _roundHalfEven(
        quotient: quotient,
        remainder: remainder,
        divisor: divisor,
        direction: direction,
      ),
      MoneyRoundingMode.reject => throw StateError('Unreachable'),
    };

    return ExactMoney(
      coefficient: rounded,
      scale: newScale,
      currencyCode: currencyCode,
    );
  }

  String toDecimalString() {
    final negative = coefficient.isNegative;
    final digits = coefficient.abs().toString().padLeft(scale + 1, '0');
    final sign = negative ? '-' : '';
    if (scale == 0) return '$sign$digits';

    final split = digits.length - scale;
    return '$sign${digits.substring(0, split)}.${digits.substring(split)}';
  }

  @override
  int compareTo(ExactMoney other) {
    _requireSameCurrency(other);
    final commonScale = scale > other.scale ? scale : other.scale;
    return _coefficientAt(
      commonScale,
    ).compareTo(other._coefficientAt(commonScale));
  }

  BigInt _coefficientAt(int targetScale) =>
      coefficient * _powerOfTen(targetScale - scale);

  void _requireSameCurrency(ExactMoney other) {
    if (currencyCode != other.currencyCode) {
      throw ArgumentError(
        'Currency mismatch: $currencyCode vs ${other.currencyCode}',
      );
    }
  }

  static BigInt _powerOfTen(int exponent) => BigInt.from(10).pow(exponent);

  static BigInt _roundHalfEven({
    required BigInt quotient,
    required BigInt remainder,
    required BigInt divisor,
    required BigInt direction,
  }) {
    final doubled = remainder.abs() * BigInt.two;
    if (doubled < divisor) return quotient;
    if (doubled > divisor) return quotient + direction;
    return quotient.isEven ? quotient : quotient + direction;
  }

  @override
  bool operator ==(Object other) =>
      other is ExactMoney &&
      coefficient == other.coefficient &&
      scale == other.scale &&
      currencyCode == other.currencyCode;

  @override
  int get hashCode => Object.hash(coefficient, scale, currencyCode);

  @override
  String toString() => '${toDecimalString()} $currencyCode';
}

import 'package:lootr/domain/value_objects/exact_money.dart';
import 'package:test/test.dart';

void main() {
  group('ExactMoney', () {
    test('parses and preserves 2, 4, and 12 decimal scales', () {
      expect(ExactMoney.parse('12.30', 'C2').scale, 2);
      expect(ExactMoney.parse('0.0040', 'C4').coefficient, BigInt.from(40));
      expect(ExactMoney.parse('0.000000000001', 'C12').coefficient, BigInt.one);
      expect(
        ExactMoney.parse('0.000000000001', 'C12').toDecimalString(),
        '0.000000000001',
      );
    });

    test('supports values larger than a signed 64-bit scaled integer', () {
      final value = ExactMoney.parse('99999999999999999999.999999999999', 'X');

      expect(value.toDecimalString(), '99999999999999999999.999999999999');
      expect(value.coefficient.bitLength, greaterThan(63));
    });

    test('adds by aligning scales without premature rounding', () {
      final result =
          ExactMoney.parse('1.20', 'USD') + ExactMoney.parse('0.0001', 'USD');

      expect(result.toDecimalString(), '1.2001');
      expect(result.scale, 4);
    });

    test('rejects arithmetic across currencies', () {
      final left = ExactMoney.parse('1.00', 'USD');
      final right = ExactMoney.parse('1.00', 'EUR');

      expect(() => left + right, throwsArgumentError);
      expect(() => left.compareTo(right), throwsArgumentError);
    });

    test('rejects lossy rescale by default', () {
      final value = ExactMoney.parse('1.005', 'USD');

      expect(() => value.rescale(2), throwsStateError);
    });

    test('uses deterministic half-even rounding at boundaries', () {
      expect(
        ExactMoney.parse(
          '1.005',
          'USD',
        ).rescale(2, rounding: MoneyRoundingMode.halfEven).toDecimalString(),
        '1.00',
      );
      expect(
        ExactMoney.parse(
          '1.015',
          'USD',
        ).rescale(2, rounding: MoneyRoundingMode.halfEven).toDecimalString(),
        '1.02',
      );
      expect(
        ExactMoney.parse(
          '-1.015',
          'USD',
        ).rescale(2, rounding: MoneyRoundingMode.halfEven).toDecimalString(),
        '-1.02',
      );
    });
  });
}

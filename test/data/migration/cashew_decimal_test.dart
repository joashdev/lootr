import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/data/migration/cashew/cashew_decimal.dart';

void main() {
  group('CashewDecimal', () {
    test('parses plain and exponent values without floating aggregation', () {
      expect(
        CashewDecimal.parse('0.000000000001').toPlainString(),
        '0.000000000001',
      );
      expect(CashewDecimal.parse('1.25e3').toPlainString(), '1250');
      expect(CashewDecimal.parse('-4.2e-3').toPlainString(), '-0.0042');
    });

    test('adds very small and large values exactly', () {
      final result =
          CashewDecimal.parse('999999999999999999.999999999999') +
          CashewDecimal.parse('0.000000000001');
      expect(result.toPlainString(), '1000000000000000000');
    });

    test('rounds ties to even at configured wallet precision', () {
      expect(CashewDecimal.parse('1.005').quantized(2).toPlainString(), '1.00');
      expect(CashewDecimal.parse('1.015').quantized(2).toPlainString(), '1.02');
      expect(
        CashewDecimal.parse('-1.005').quantized(2).toPlainString(),
        '-1.00',
      );
      expect(
        CashewDecimal.parse('-1.015').quantized(2).toPlainString(),
        '-1.02',
      );
      expect(
        CashewDecimal.parse('0.00005').quantized(4).toPlainString(),
        '0.0000',
      );
      expect(
        CashewDecimal.parse('0.0000000000015').quantized(12).toPlainString(),
        '0.000000000002',
      );
      expect(
        CashewDecimal.parse('0.0000000000005').quantized(12).toPlainString(),
        '0.000000000000',
      );
      expect(
        CashewDecimal.parse('0.0000000000006').quantized(12).toPlainString(),
        '0.000000000001',
      );
    });

    test('compares values with different scales exactly', () {
      expect(CashewDecimal.parse('5.0'), CashewDecimal.parse('5.000000000000'));
      expect(
        CashewDecimal.parse('5.0001').compareTo(CashewDecimal.parse('5')),
        greaterThan(0),
      );
    });
  });
}

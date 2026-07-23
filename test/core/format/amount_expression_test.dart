import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/core/format/amount_expression.dart';

void main() {
  test('evaluates deterministic arithmetic with precedence', () {
    expect(AmountExpression.evaluate('120 + 30 * 2'), 180);
    expect(AmountExpression.evaluate('(120 + 30) / 2'), 75);
    expect(AmountExpression.evaluate('-2.5 + 10'), 7.5);
  });

  test('rejects invalid and non-finite expressions', () {
    expect(() => AmountExpression.evaluate('1 / 0'), throwsFormatException);
    expect(() => AmountExpression.evaluate('2 +'), throwsFormatException);
    expect(() => AmountExpression.evaluate('(2 + 3'), throwsFormatException);
  });
}

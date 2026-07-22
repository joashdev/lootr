import 'package:lootr/core/format/money_format.dart';
import 'package:lootr/domain/value_objects/exact_money.dart';
import 'package:test/test.dart';

void main() {
  group('MoneyFormat.exactMoney', () {
    test('preserves configured 2, 4, and 12 decimal scales', () {
      expect(
        MoneyFormat.exactMoney(ExactMoney.parse('12.30', 'USD')),
        r'$12.30',
      );
      expect(
        MoneyFormat.exactMoney(ExactMoney.parse('12.3000', 'EUR')),
        '€12.3000',
      );
      expect(
        MoneyFormat.exactMoney(ExactMoney.parse('0.000000000001', 'BTC')),
        'BTC0.000000000001',
      );
    });

    test('groups large values without projecting through double', () {
      expect(
        MoneyFormat.exactMoney(
          ExactMoney.parse('99999999999999999999.999999999999', 'X'),
        ),
        'X99,999,999,999,999,999,999.999999999999',
      );
    });

    test('places a negative sign before the currency symbol', () {
      expect(
        MoneyFormat.exactMoney(ExactMoney.parse('-1234.5000', 'PHP')),
        '-₱1,234.5000',
      );
    });

    test('supports zero-decimal currencies', () {
      expect(MoneyFormat.exactMoney(ExactMoney.parse('1234', 'JPY')), '¥1,234');
    });
  });
}

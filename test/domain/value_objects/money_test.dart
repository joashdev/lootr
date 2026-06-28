import 'package:test/test.dart';
import 'package:lootr/domain/value_objects/money.dart';

void main() {
  group('Money', () {
    group('construction', () {
      test('should create with amount and currency', () {
        final m = Money(100, 'PHP');
        expect(m.amount, 100);
        expect(m.currencyCode, 'PHP');
      });
    });

    group('addition', () {
      test('should add two Money of same currency', () {
        final a = Money(100, 'PHP');
        final b = Money(50, 'PHP');
        final result = a + b;
        expect(result.amount, 150);
        expect(result.currencyCode, 'PHP');
      });

      test('should throw on currency mismatch', () {
        final a = Money(100, 'PHP');
        final b = Money(50, 'USD');
        expect(() => a + b, throwsArgumentError);
      });
    });

    group('subtraction', () {
      test('should subtract two Money of same currency', () {
        final a = Money(100, 'PHP');
        final b = Money(30, 'PHP');
        final result = a - b;
        expect(result.amount, 70);
        expect(result.currencyCode, 'PHP');
      });

      test('should throw on currency mismatch', () {
        final a = Money(100, 'PHP');
        final b = Money(50, 'USD');
        expect(() => a - b, throwsArgumentError);
      });
    });

    group('abs', () {
      test('should return absolute value', () {
        final m = Money(-100, 'PHP');
        final result = m.abs();
        expect(result.amount, 100);
        expect(result.currencyCode, 'PHP');
      });

      test('should not change positive value', () {
        final m = Money(100, 'PHP');
        final result = m.abs();
        expect(result.amount, 100);
      });
    });

    group('format', () {
      test('should format with currency symbol', () {
        final m = Money(100.50, 'PHP');
        final formatted = m.format();
        expect(formatted, contains('₱'));
        expect(formatted, contains('100.50'));
      });

      test('should format USD', () {
        final m = Money(100, 'USD');
        final formatted = m.format();
        expect(formatted, contains('\$'));
        expect(formatted, contains('100.00'));
      });
    });

    group('equality', () {
      test('should equal same amount and currency', () {
        final a = Money(100, 'PHP');
        final b = Money(100, 'PHP');
        expect(a, equals(b));
      });

      test('should not equal different amount', () {
        final a = Money(100, 'PHP');
        final b = Money(200, 'PHP');
        expect(a, isNot(equals(b)));
      });

      test('should not equal different currency', () {
        final a = Money(100, 'PHP');
        final b = Money(100, 'USD');
        expect(a, isNot(equals(b)));
      });
    });
  });
}

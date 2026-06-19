import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/domain/value_objects/date_range.dart';

void main() {
  group('DateRange', () {
    final start = DateTime(2026, 1, 1);
    final end = DateTime(2026, 12, 31);

    group('construction', () {
      test('should create with start and end', () {
        final range = DateRange(start, end);
        expect(range.start, start);
        expect(range.end, end);
      });

      test('should throw when start is after end', () {
        expect(
          () => DateRange(end, start),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('contains', () {
      test('should contain date within range', () {
        final range = DateRange(start, end);
        expect(range.contains(DateTime(2026, 6, 15)), isTrue);
      });

      test('should contain start date', () {
        final range = DateRange(start, end);
        expect(range.contains(start), isTrue);
      });

      test('should contain end date', () {
        final range = DateRange(start, end);
        expect(range.contains(end), isTrue);
      });

      test('should not contain date before start', () {
        final range = DateRange(start, end);
        expect(range.contains(DateTime(2025, 12, 31)), isFalse);
      });

      test('should not contain date after end', () {
        final range = DateRange(start, end);
        expect(range.contains(DateTime(2027, 1, 1)), isFalse);
      });
    });

    group('duration', () {
      test('should return correct duration', () {
        final range = DateRange(start, end);
        expect(range.duration.inDays, 364);
      });

      test('should return zero for same day', () {
        final range = DateRange(start, start);
        expect(range.duration.inDays, 0);
      });
    });

    group('monthsInRange', () {
      test('should return all months in range', () {
        final range = DateRange(
          DateTime(2026, 1, 15),
          DateTime(2026, 3, 20),
        );
        final months = range.monthsInRange();

        expect(months.length, 3);
        expect(months[0], (month: 1, year: 2026));
        expect(months[1], (month: 2, year: 2026));
        expect(months[2], (month: 3, year: 2026));
      });

      test('should return single month when start and end same month', () {
        final range = DateRange(
          DateTime(2026, 6, 1),
          DateTime(2026, 6, 30),
        );
        final months = range.monthsInRange();

        expect(months.length, 1);
        expect(months[0], (month: 6, year: 2026));
      });

      test('should span across years', () {
        final range = DateRange(
          DateTime(2025, 11, 1),
          DateTime(2026, 2, 28),
        );
        final months = range.monthsInRange();

        expect(months.length, 4);
        expect(months[0], (month: 11, year: 2025));
        expect(months[1], (month: 12, year: 2025));
        expect(months[2], (month: 1, year: 2026));
        expect(months[3], (month: 2, year: 2026));
      });
    });

    group('equality', () {
      test('should equal same start and end', () {
        final a = DateRange(start, end);
        final b = DateRange(start, end);
        expect(a, equals(b));
      });

      test('should not equal different end', () {
        final a = DateRange(start, end);
        final b = DateRange(start, DateTime(2026, 12, 30));
        expect(a, isNot(equals(b)));
      });
    });
  });
}

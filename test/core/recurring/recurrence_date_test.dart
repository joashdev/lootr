import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/core/recurring/recurrence_date.dart';

void main() {
  test(
    'calendar recurrence keeps time and clamps only to the target month',
    () {
      final current = DateTime(2026, 1, 31, 9, 45, 30);

      expect(
        nextRecurrenceDate(current, 'monthly'),
        DateTime(2026, 2, 28, 9, 45, 30),
      );
      expect(
        nextRecurrenceDate(current, 'quarterly'),
        DateTime(2026, 4, 30, 9, 45, 30),
      );
      expect(
        nextRecurrenceDate(current, 'yearly'),
        DateTime(2027, 1, 31, 9, 45, 30),
      );
    },
  );
}

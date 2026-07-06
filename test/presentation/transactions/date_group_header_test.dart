import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/presentation/screens/transactions/widgets/date_group_header.dart';

void main() {
  group('formatDateGroupTitle', () {
    // Fixed reference "now" so results are deterministic.
    final now = DateTime(2026, 6, 30, 14, 45);

    test('returns Today for the reference date', () {
      expect(formatDateGroupTitle(DateTime(2026, 6, 30), now: now), 'Today');
    });

    test('returns Today regardless of time-of-day components', () {
      expect(
        formatDateGroupTitle(DateTime(2026, 6, 30, 23, 59), now: now),
        'Today',
      );
      expect(
        formatDateGroupTitle(DateTime(2026, 6, 30, 0, 1), now: now),
        'Today',
      );
    });

    test('returns Yesterday for the day before the reference date', () {
      expect(
        formatDateGroupTitle(DateTime(2026, 6, 29), now: now),
        'Yesterday',
      );
    });

    test('handles Yesterday across a month boundary', () {
      final firstOfMonth = DateTime(2026, 7, 1, 8);
      expect(
        formatDateGroupTitle(DateTime(2026, 6, 30), now: firstOfMonth),
        'Yesterday',
      );
    });

    test('handles Yesterday across a year boundary', () {
      final newYear = DateTime(2026, 1, 1, 8);
      expect(
        formatDateGroupTitle(DateTime(2025, 12, 31), now: newYear),
        'Yesterday',
      );
    });

    test('formats current-year dates as MMM d without year', () {
      expect(formatDateGroupTitle(DateTime(2026, 6, 28), now: now), 'Jun 28');
      expect(formatDateGroupTitle(DateTime(2026, 1, 5), now: now), 'Jan 5');
      expect(formatDateGroupTitle(DateTime(2026, 12, 25), now: now), 'Dec 25');
    });

    test('appends the year for dates outside the current year', () {
      expect(
        formatDateGroupTitle(DateTime(2025, 6, 29), now: now),
        'Jun 29, 2025',
      );
      expect(
        formatDateGroupTitle(DateTime(2027, 2, 14), now: now),
        'Feb 14, 2027',
      );
    });

    test('a future date within the current year stays year-less', () {
      expect(formatDateGroupTitle(DateTime(2026, 7, 2), now: now), 'Jul 2');
    });
  });

  group('DateGroupHeader', () {
    testWidgets('renders the provided title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: DateGroupHeader(title: 'Jun 29, 2025')),
        ),
      );

      expect(find.text('Jun 29, 2025'), findsOneWidget);
    });
  });
}

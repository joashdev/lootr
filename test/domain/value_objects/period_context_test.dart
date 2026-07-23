import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/domain/value_objects/period_context.dart';

void main() {
  test('calendar month navigation crosses year boundaries', () {
    final december = PeriodContext.calendarMonth(DateTime(2026, 12, 20));

    expect(december.startsAt, DateTime(2026, 12));
    expect(december.endsAt, DateTime(2027));
    expect(december.label, 'December 2026');
    expect(december.next().startsAt, DateTime(2027));
    expect(december.previous().startsAt, DateTime(2026, 11));
  });

  test('custom cycles retain a distinct label and exact half-open bounds', () {
    final cycle = PeriodContext.customCycle(
      id: 'pay-cycle',
      name: 'Pay cycle',
      startsAt: DateTime(2026, 6, 15),
      endsAt: DateTime(2026, 7, 15),
    );

    expect(cycle.kind, PeriodContextKind.customCycle);
    expect(cycle.description, 'Pay cycle · 2026-06-15–2026-07-14');
    expect(cycle.previous(), same(cycle));
    expect(cycle.inclusiveEnd.isBefore(cycle.endsAt), isTrue);
  });
}

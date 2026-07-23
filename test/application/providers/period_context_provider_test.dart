import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/period_context_provider.dart';
import 'package:lootr/domain/value_objects/ledger_query.dart';
import 'package:lootr/domain/value_objects/period_context.dart';

void main() {
  test('closing a ledger drill-down restores its originating period', () {
    final container = ProviderContainer(
      overrides: [
        periodContextClockProvider.overrideWithValue(DateTime(2026, 6, 15)),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(activeLedgerQueryProvider.notifier)
        .open(
          LedgerQuery(
            explanation: 'May expenses',
            period: PeriodContext.calendarMonth(DateTime(2026, 5)),
          ),
        );
    expect(container.read(periodContextProvider).startsAt, DateTime(2026, 5));

    container.read(activeLedgerQueryProvider.notifier).clear();

    expect(container.read(periodContextProvider).startsAt, DateTime(2026, 6));
    expect(container.read(activeLedgerQueryProvider), isNull);
  });
}

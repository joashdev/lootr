import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/period_context_provider.dart';
import 'package:lootr/presentation/shared/components/period_selector.dart';

void main() {
  testWidgets('custom cycle shows exact dates and supports adjacent cycles', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(periodContextProvider.notifier)
        .selectCustomCycle(
          id: 'pay-cycle',
          name: 'Pay cycle',
          startsAt: DateTime(2026, 6, 15),
          endsAt: DateTime(2026, 7, 15),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: PeriodSelector(compact: true)),
        ),
      ),
    );

    expect(find.text('Pay cycle'), findsOneWidget);
    expect(find.text('2026-06-15–2026-07-14'), findsOneWidget);

    await tester.tap(find.byTooltip('Next cycle'));
    await tester.pump();

    expect(find.text('2026-07-15–2026-08-13'), findsOneWidget);
    expect(container.read(periodContextProvider).cycleId, 'pay-cycle');

    await tester.tap(find.text('Pay cycle'));
    await tester.pumpAndSettle();
    expect(find.text('Select cycle start'), findsOneWidget);
  });
}

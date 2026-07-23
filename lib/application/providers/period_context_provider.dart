import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/ledger_query.dart';
import '../../domain/value_objects/period_context.dart';

final periodContextClockProvider = Provider<DateTime>((ref) => DateTime.now());

class PeriodContextNotifier extends Notifier<PeriodContext> {
  @override
  PeriodContext build() =>
      PeriodContext.calendarMonth(ref.watch(periodContextClockProvider));

  void selectMonth(DateTime month) {
    state = PeriodContext.calendarMonth(month);
  }

  void selectCustomCycle({
    required String id,
    required String name,
    required DateTime startsAt,
    required DateTime endsAt,
  }) {
    state = PeriodContext.customCycle(
      id: id,
      name: name,
      startsAt: startsAt,
      endsAt: endsAt,
    );
  }

  void previous() => state = state.previous();
  void next() => state = state.next();
}

final periodContextProvider =
    NotifierProvider<PeriodContextNotifier, PeriodContext>(
      PeriodContextNotifier.new,
    );

class ActiveLedgerQueryNotifier extends Notifier<LedgerQuery?> {
  PeriodContext? _returnPeriod;

  @override
  LedgerQuery? build() => null;

  void open(LedgerQuery query) {
    _returnPeriod ??= ref.read(periodContextProvider);
    state = query;
    ref.read(periodContextProvider.notifier).selectMonth(query.period.startsAt);
    if (query.period.kind == PeriodContextKind.customCycle) {
      ref
          .read(periodContextProvider.notifier)
          .selectCustomCycle(
            id: query.period.cycleId!,
            name: query.period.label,
            startsAt: query.period.startsAt,
            endsAt: query.period.endsAt,
          );
    }
  }

  void clear() {
    final returnPeriod = _returnPeriod;
    state = null;
    _returnPeriod = null;
    if (returnPeriod == null) return;
    if (returnPeriod.kind == PeriodContextKind.calendarMonth) {
      ref
          .read(periodContextProvider.notifier)
          .selectMonth(returnPeriod.startsAt);
      return;
    }
    ref
        .read(periodContextProvider.notifier)
        .selectCustomCycle(
          id: returnPeriod.cycleId!,
          name: returnPeriod.label,
          startsAt: returnPeriod.startsAt,
          endsAt: returnPeriod.endsAt,
        );
  }
}

final activeLedgerQueryProvider =
    NotifierProvider<ActiveLedgerQueryNotifier, LedgerQuery?>(
      ActiveLedgerQueryNotifier.new,
    );

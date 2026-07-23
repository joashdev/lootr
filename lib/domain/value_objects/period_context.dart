enum PeriodContextKind { calendarMonth, customCycle }

class PeriodContext {
  const PeriodContext._({
    required this.kind,
    required this.startsAt,
    required this.endsAt,
    required this.label,
    this.cycleId,
  });

  factory PeriodContext.calendarMonth(DateTime month) {
    final startsAt = DateTime(month.year, month.month);
    return PeriodContext._(
      kind: PeriodContextKind.calendarMonth,
      startsAt: startsAt,
      endsAt: DateTime(month.year, month.month + 1),
      label: '${_monthNames[month.month - 1]} ${month.year}',
    );
  }

  factory PeriodContext.customCycle({
    required String id,
    required String name,
    required DateTime startsAt,
    required DateTime endsAt,
  }) {
    if (!endsAt.isAfter(startsAt)) {
      throw ArgumentError('A custom cycle must end after it starts');
    }
    return PeriodContext._(
      kind: PeriodContextKind.customCycle,
      startsAt: startsAt,
      endsAt: endsAt,
      label: name,
      cycleId: id,
    );
  }

  final PeriodContextKind kind;
  final DateTime startsAt;

  /// Exclusive upper bound.
  final DateTime endsAt;
  final String label;
  final String? cycleId;

  DateTime get inclusiveEnd => endsAt.subtract(const Duration(microseconds: 1));

  String get description => kind == PeriodContextKind.calendarMonth
      ? label
      : '$label · ${_shortDate(startsAt)}–${_shortDate(inclusiveEnd)}';

  PeriodContext previous() {
    if (kind != PeriodContextKind.calendarMonth) return this;
    return PeriodContext.calendarMonth(
      DateTime(startsAt.year, startsAt.month - 1),
    );
  }

  PeriodContext next() {
    if (kind != PeriodContextKind.calendarMonth) return this;
    return PeriodContext.calendarMonth(
      DateTime(startsAt.year, startsAt.month + 1),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PeriodContext &&
      other.kind == kind &&
      other.startsAt == startsAt &&
      other.endsAt == endsAt &&
      other.label == label &&
      other.cycleId == cycleId;

  @override
  int get hashCode => Object.hash(kind, startsAt, endsAt, label, cycleId);
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _shortDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

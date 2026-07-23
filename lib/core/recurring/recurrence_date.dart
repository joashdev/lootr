DateTime? nextRecurrenceDate(DateTime current, String rule) {
  return switch (rule) {
    'daily' => current.add(const Duration(days: 1)),
    'weekly' => current.add(const Duration(days: 7)),
    'biweekly' => current.add(const Duration(days: 14)),
    'monthly' => _addMonths(current, 1),
    'quarterly' => _addMonths(current, 3),
    'yearly' => _addMonths(current, 12),
    _ => null,
  };
}

DateTime _addMonths(DateTime current, int count) {
  final zeroBasedMonth = current.month - 1 + count;
  final year = current.year + zeroBasedMonth ~/ 12;
  final month = zeroBasedMonth % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = current.day.clamp(1, lastDay);
  return DateTime(
    year,
    month,
    day,
    current.hour,
    current.minute,
    current.second,
    current.millisecond,
    current.microsecond,
  );
}

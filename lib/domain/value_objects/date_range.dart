class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange(this.start, this.end) : assert(!start.isAfter(end));

  bool contains(DateTime date) =>
      !date.isBefore(start) && !date.isAfter(end);

  Duration get duration => end.difference(start);

  List<({int month, int year})> monthsInRange() {
    final months = <({int month, int year})>[];
    var current = DateTime(start.year, start.month);
    final last = DateTime(end.year, end.month);
    while (!current.isAfter(last)) {
      months.add((month: current.month, year: current.year));
      current = DateTime(current.year, current.month + 1);
    }
    return months;
  }

  @override
  bool operator ==(Object other) =>
      other is DateRange && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'DateRange($start – $end)';
}

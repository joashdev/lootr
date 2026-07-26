import 'date_range.dart';
import 'period_context.dart';
import 'transaction_filters.dart';

class LedgerQuery {
  const LedgerQuery({
    required this.explanation,
    required this.period,
    this.directions = const [],
    this.accountIds = const [],
    this.categoryIds = const [],
    this.currencyCode,
    this.uncategorizedOnly = false,
  });

  final String explanation;
  final PeriodContext period;
  final List<String> directions;
  final List<String> accountIds;
  final List<String> categoryIds;
  final String? currencyCode;
  final bool uncategorizedOnly;

  TransactionFilters get filters => TransactionFilters(
    directions: directions,
    accountIds: accountIds,
    categoryIds: categoryIds,
    currencyCode: currencyCode,
    dateRange: DateRange(period.startsAt, period.inclusiveEnd),
  );
}

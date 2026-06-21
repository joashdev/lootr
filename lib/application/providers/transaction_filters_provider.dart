import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/value_objects/date_range.dart';
import '../../domain/value_objects/transaction_filters.dart';

class TransactionFiltersNotifier extends Notifier<TransactionFilters> {
  @override
  TransactionFilters build() => const TransactionFilters();

  void update(TransactionFilters value) => state = value;
  void reset() => state = const TransactionFilters();

  void setDirection(String? direction) {
    state = TransactionFilters(
      direction: direction, mode: state.mode, accountId: state.accountId,
      categoryId: state.categoryId, minAmount: state.minAmount,
      maxAmount: state.maxAmount, dateRange: state.dateRange,
    );
  }

  void setMode(String? mode) {
    state = TransactionFilters(
      direction: state.direction, mode: mode, accountId: state.accountId,
      categoryId: state.categoryId, minAmount: state.minAmount,
      maxAmount: state.maxAmount, dateRange: state.dateRange,
    );
  }

  void setAccountId(String? accountId) {
    state = TransactionFilters(
      direction: state.direction, mode: state.mode, accountId: accountId,
      categoryId: state.categoryId, minAmount: state.minAmount,
      maxAmount: state.maxAmount, dateRange: state.dateRange,
    );
  }

  void setCategoryId(String? categoryId) {
    state = TransactionFilters(
      direction: state.direction, mode: state.mode, accountId: state.accountId,
      categoryId: categoryId, minAmount: state.minAmount,
      maxAmount: state.maxAmount, dateRange: state.dateRange,
    );
  }

  void setAmountRange(double? minAmount, double? maxAmount) {
    state = TransactionFilters(
      direction: state.direction, mode: state.mode, accountId: state.accountId,
      categoryId: state.categoryId, minAmount: minAmount,
      maxAmount: maxAmount, dateRange: state.dateRange,
    );
  }

  void setDateRange(DateRange? dateRange) {
    state = TransactionFilters(
      direction: state.direction, mode: state.mode, accountId: state.accountId,
      categoryId: state.categoryId, minAmount: state.minAmount,
      maxAmount: state.maxAmount, dateRange: dateRange,
    );
  }
}

/// Not autoDispose: filter state must persist across tab switches (Task 16.5).
/// It is in-memory only and resets on app restart.
final transactionFiltersProvider =
    NotifierProvider<TransactionFiltersNotifier, TransactionFilters>(
  TransactionFiltersNotifier.new,
);

/// Debounced search query applied to the transaction list (Task 16.4).
/// Composes with [transactionFiltersProvider] via AND logic.
class TransactionSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query.trim();
  void clear() => state = '';
}

final transactionSearchQueryProvider =
    NotifierProvider<TransactionSearchQueryNotifier, String>(
  TransactionSearchQueryNotifier.new,
);

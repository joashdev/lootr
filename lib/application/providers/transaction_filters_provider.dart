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
      directions: direction == null ? const [] : [direction],
      modes: state.modes,
      accountIds: state.accountIds,
      categoryIds: state.categoryIds,
      minAmount: state.minAmount,
      maxAmount: state.maxAmount,
      dateRange: state.dateRange,
    );
  }

  void toggleDirection(String direction) {
    final next = [...state.directions];
    next.contains(direction) ? next.remove(direction) : next.add(direction);
    state = TransactionFilters(
      directions: next,
      modes: state.modes,
      accountIds: state.accountIds,
      categoryIds: state.categoryIds,
      minAmount: state.minAmount,
      maxAmount: state.maxAmount,
      dateRange: state.dateRange,
    );
  }

  void setMode(String? mode) {
    state = TransactionFilters(
      directions: state.directions,
      modes: mode == null ? const [] : [mode],
      accountIds: state.accountIds,
      categoryIds: state.categoryIds,
      minAmount: state.minAmount,
      maxAmount: state.maxAmount,
      dateRange: state.dateRange,
    );
  }

  void toggleMode(String mode) {
    final next = [...state.modes];
    next.contains(mode) ? next.remove(mode) : next.add(mode);
    state = TransactionFilters(
      directions: state.directions,
      modes: next,
      accountIds: state.accountIds,
      categoryIds: state.categoryIds,
      minAmount: state.minAmount,
      maxAmount: state.maxAmount,
      dateRange: state.dateRange,
    );
  }

  void setAccountId(String? accountId) {
    state = TransactionFilters(
      directions: state.directions,
      modes: state.modes,
      accountIds: accountId == null ? const [] : [accountId],
      categoryIds: state.categoryIds,
      minAmount: state.minAmount,
      maxAmount: state.maxAmount,
      dateRange: state.dateRange,
    );
  }

  void toggleAccountId(String accountId) {
    final next = [...state.accountIds];
    next.contains(accountId) ? next.remove(accountId) : next.add(accountId);
    state = TransactionFilters(
      directions: state.directions,
      modes: state.modes,
      accountIds: next,
      categoryIds: state.categoryIds,
      minAmount: state.minAmount,
      maxAmount: state.maxAmount,
      dateRange: state.dateRange,
    );
  }

  void setCategoryId(String? categoryId) {
    state = TransactionFilters(
      directions: state.directions,
      modes: state.modes,
      accountIds: state.accountIds,
      categoryIds: categoryId == null ? const [] : [categoryId],
      minAmount: state.minAmount,
      maxAmount: state.maxAmount,
      dateRange: state.dateRange,
    );
  }

  void toggleCategoryId(String categoryId) {
    final next = [...state.categoryIds];
    next.contains(categoryId) ? next.remove(categoryId) : next.add(categoryId);
    state = TransactionFilters(
      directions: state.directions,
      modes: state.modes,
      accountIds: state.accountIds,
      categoryIds: next,
      minAmount: state.minAmount,
      maxAmount: state.maxAmount,
      dateRange: state.dateRange,
    );
  }

  void setAmountRange(double? minAmount, double? maxAmount) {
    state = TransactionFilters(
      directions: state.directions,
      modes: state.modes,
      accountIds: state.accountIds,
      categoryIds: state.categoryIds,
      minAmount: minAmount,
      maxAmount: maxAmount,
      dateRange: state.dateRange,
    );
  }

  void setDateRange(DateRange? dateRange) {
    state = TransactionFilters(
      directions: state.directions,
      modes: state.modes,
      accountIds: state.accountIds,
      categoryIds: state.categoryIds,
      minAmount: state.minAmount,
      maxAmount: state.maxAmount,
      dateRange: dateRange,
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/value_objects/transaction_filters.dart';

class TransactionFiltersNotifier extends Notifier<TransactionFilters> {
  @override
  TransactionFilters build() => const TransactionFilters();

  void update(TransactionFilters value) => state = value;
  void reset() => state = const TransactionFilters();
}

final transactionFiltersProvider =
    NotifierProvider.autoDispose<TransactionFiltersNotifier, TransactionFilters>(
  TransactionFiltersNotifier.new,
);

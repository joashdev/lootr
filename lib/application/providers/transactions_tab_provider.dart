import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/transaction.dart';
import 'filtered_transactions_provider.dart';
import 'transaction_filters_provider.dart';

final transactionsTabProvider = Provider<TransactionsTabState>((ref) {
  final transactions = ref.watch(filteredTransactionsProvider);
  final filters = ref.watch(transactionFiltersProvider);

  return transactions.when(
    data: (list) => TransactionsTabState(
      transactions: list,
      filters: filters,
      isLoading: false,
    ),
    loading: () => TransactionsTabState(
      transactions: const [],
      filters: filters,
      isLoading: true,
    ),
    error: (err, _) => TransactionsTabState(
      transactions: const [],
      filters: filters,
      isLoading: false,
      error: err.toString(),
    ),
  );
});

class TransactionsTabState {
  final List<Transaction> transactions;
  final dynamic filters;
  final bool isLoading;
  final String? error;

  const TransactionsTabState({
    required this.transactions,
    required this.filters,
    this.isLoading = false,
    this.error,
  });
}

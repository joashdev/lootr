import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/transaction_repo.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/entities/transaction.dart';
import 'repo_providers.dart';
import 'transaction_filters_provider.dart';

final filteredTransactionsProvider =
    StreamProvider<List<Transaction>>((ref) {
  final repo = ref.watch(transactionRepoProvider);
  final filters = ref.watch(transactionFiltersProvider);

  final repoFilters = TransactionRepoFilters(
    direction: filters.direction,
    accountId: filters.accountId,
    categoryId: filters.categoryId,
    mode: filters.mode,
    from: filters.dateRange?.start,
    to: filters.dateRange?.end,
  );

  return repo.watchFiltered(repoFilters).map((rows) {
    var txns = rows.map((r) => r.toEntity()).toList();

    if (filters.minAmount != null) {
      txns = txns.where((t) => t.amount >= filters.minAmount!).toList();
    }
    if (filters.maxAmount != null) {
      txns = txns.where((t) => t.amount <= filters.maxAmount!).toList();
    }

    txns.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return txns;
  });
});

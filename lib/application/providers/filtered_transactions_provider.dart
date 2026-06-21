import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/transaction_repo.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/entities/payee.dart';
import '../../domain/entities/transaction.dart';
import 'payees_provider.dart';
import 'repo_providers.dart';
import 'transaction_entry_support.dart';
import 'transaction_filters_provider.dart';

final filteredTransactionsProvider =
    StreamProvider<List<Transaction>>((ref) {
  final transactionRepo = ref.watch(transactionRepoProvider);
  final transferRepo = ref.watch(transferRepoProvider);
  final filters = ref.watch(transactionFiltersProvider);
  final searchQuery = ref.watch(transactionSearchQueryProvider);
  final payees = ref.watch(payeesProvider).asData?.value ?? const <Payee>[];
  final payeesById = {for (final payee in payees) payee.id: payee};
  final normalizedQuery = normalizeSearchText(searchQuery);

  final repoFilters = TransactionRepoFilters(
    direction: filters.direction,
    accountId: filters.accountId,
    categoryId: filters.categoryId,
    mode: filters.mode,
    from: filters.dateRange?.start,
    to: filters.dateRange?.end,
  );

  return Rx.combineLatest2<List<TransactionData>, List<TransferData>,
      List<Transaction>>(
    transactionRepo.watchFiltered(repoFilters),
    transferRepo.watchAll(),
    (rows, transferRows) {
      var txns = rows.map((r) => r.toEntity()).toList();
      final transfers = transferRows.map((row) => row.toEntity()).toList();

      if (filters.minAmount != null) {
        txns = txns.where((t) => t.amount >= filters.minAmount!).toList();
      }
      if (filters.maxAmount != null) {
        txns = txns.where((t) => t.amount <= filters.maxAmount!).toList();
      }

      final filteredTransfers = transfers.where((transfer) {
        if (filters.direction != null && filters.direction != 'transfer') {
          return false;
        }
        if (filters.mode != null) return false;
        if (filters.categoryId != null) return false;
        if (filters.accountId != null &&
            transfer.sourceAccountId != filters.accountId &&
            transfer.destinationAccountId != filters.accountId) {
          return false;
        }
        if (filters.dateRange != null &&
            !filters.dateRange!.contains(transfer.occurredAt)) {
          return false;
        }
        if (filters.minAmount != null && transfer.amount < filters.minAmount!) {
          return false;
        }
        if (filters.maxAmount != null && transfer.amount > filters.maxAmount!) {
          return false;
        }
        return true;
      }).map(mapTransferToTransaction);

      txns = [...txns, ...filteredTransfers];

      // Search composes with active filters via AND logic (Task 16.4).
      if (normalizedQuery.isNotEmpty) {
        txns = txns.where((t) {
          final payee = t.payeeId == null ? null : payeesById[t.payeeId];
          return _matchesSearch(t, payee, normalizedQuery);
        }).toList();
      }

      txns.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      return txns;
    },
  );
});

bool _matchesSearch(
  Transaction transaction,
  Payee? payee,
  String normalizedQuery,
) {
  final values = <String?>[
    transaction.note,
    transaction.amount.toString(),
    transaction.amount.toStringAsFixed(2),
    payee?.displayName,
    payee?.normalizedName,
  ];

  return values.any(
    (value) =>
        value != null && normalizeSearchText(value).contains(normalizedQuery),
  );
}

/// Lower-cases and strips diacritics for accent-insensitive search (Task 16.4).
String normalizeSearchText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp('[àáâãäåāăą]'), 'a')
      .replaceAll(RegExp('[çćč]'), 'c')
      .replaceAll(RegExp('[ďđ]'), 'd')
      .replaceAll(RegExp('[èéêëēĕėęě]'), 'e')
      .replaceAll(RegExp('[ìíîïīĭįı]'), 'i')
      .replaceAll(RegExp('[ñńň]'), 'n')
      .replaceAll(RegExp('[òóôõöøōŏő]'), 'o')
      .replaceAll(RegExp('[ŕř]'), 'r')
      .replaceAll(RegExp('[śšş]'), 's')
      .replaceAll(RegExp('[ťţ]'), 't')
      .replaceAll(RegExp('[ùúûüūŭůűų]'), 'u')
      .replaceAll(RegExp('[ýÿ]'), 'y')
      .replaceAll(RegExp('[žźż]'), 'z')
      .trim();
}

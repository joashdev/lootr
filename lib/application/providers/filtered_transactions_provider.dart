import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/transaction_repo.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/entities/payee.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/value_objects/exact_money.dart';
import '../../domain/value_objects/transaction_list_intent.dart';
import 'payees_provider.dart';
import 'period_context_provider.dart';
import 'repo_providers.dart';
import 'transaction_entry_support.dart';
import 'transaction_filters_provider.dart';
import 'transaction_list_intent_provider.dart';

final filteredTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final transactionRepo = ref.watch(transactionRepoProvider);
  final transferRepo = ref.watch(transferRepoProvider);
  final filters = ref.watch(transactionFiltersProvider);
  final ledgerQuery = ref.watch(activeLedgerQueryProvider);
  final ledgerFilters = ledgerQuery?.filters;
  final period = ref.watch(periodContextProvider);
  final searchQuery = ref.watch(transactionSearchQueryProvider);
  final listIntent = ref.watch(transactionListIntentProvider);
  final payees = ref.watch(payeesProvider).asData?.value ?? const <Payee>[];
  final payeesById = {for (final payee in payees) payee.id: payee};
  final normalizedQuery = normalizeSearchText(searchQuery);

  final effectiveFrom = _later(
    _later(filters.dateRange?.start, ledgerFilters?.dateRange?.start),
    period.startsAt,
  );
  final effectiveTo = _earlier(
    _earlier(filters.dateRange?.end, ledgerFilters?.dateRange?.end),
    period.inclusiveEnd,
  );
  final repoFilters = TransactionRepoFilters(
    currencyCode: filters.currencyCode ?? ledgerFilters?.currencyCode,
    minAmountCoefficient: filters.minAmountCoefficient,
    minAmountScale: filters.minAmountScale,
    maxAmountCoefficient: filters.maxAmountCoefficient,
    maxAmountScale: filters.maxAmountScale,
    from: effectiveFrom,
    to: effectiveTo,
  );

  return Rx.combineLatest2<
    List<TransactionData>,
    List<TransferData>,
    List<Transaction>
  >(transactionRepo.watchFiltered(repoFilters), transferRepo.watchAll(), (
    rows,
    transferRows,
  ) {
    var txns = rows.map((r) => r.toEntity()).toList();
    final transfers = transferRows.map((row) => row.toEntity()).toList();

    // Exact money constraints were evaluated at the repository boundary,
    // where legacy rows can be promoted with their account precision.
    txns = filters.apply(txns, includeMoney: false);

    final filteredTransfers = transfers
        .where((transfer) {
          if (filters.directions.isNotEmpty &&
              !filters.directions.contains('transfer')) {
            return false;
          }
          if (filters.modes.isNotEmpty) return false;
          if (filters.categoryIds.isNotEmpty) return false;
          if (filters.accountIds.isNotEmpty &&
              !filters.accountIds.contains(transfer.sourceAccountId) &&
              !filters.accountIds.contains(transfer.destinationAccountId)) {
            return false;
          }
          if (effectiveFrom != null &&
              transfer.occurredAt.isBefore(effectiveFrom)) {
            return false;
          }
          if (effectiveTo != null && transfer.occurredAt.isAfter(effectiveTo)) {
            return false;
          }
          final candidateAmounts = <ExactMoney>[
            if (filters.accountIds.isEmpty ||
                filters.accountIds.contains(transfer.sourceAccountId))
              transfer.exactSourceAmount,
            if (filters.accountIds.isEmpty ||
                filters.accountIds.contains(transfer.destinationAccountId))
              transfer.exactDestinationAmount,
          ];
          return candidateAmounts.any((amount) {
            if (filters.currencyCode != null &&
                amount.currencyCode != filters.currencyCode) {
              return false;
            }
            if (!filters.hasExactAmountRange) return true;
            if (filters.minAmountCoefficient != null) {
              final minimum = ExactMoney(
                coefficient: BigInt.parse(filters.minAmountCoefficient!),
                scale: filters.minAmountScale!,
                currencyCode: filters.currencyCode!,
              );
              if (amount.compareTo(minimum) < 0) return false;
            }
            if (filters.maxAmountCoefficient != null) {
              final maximum = ExactMoney(
                coefficient: BigInt.parse(filters.maxAmountCoefficient!),
                scale: filters.maxAmountScale!,
                currencyCode: filters.currencyCode!,
              );
              if (amount.compareTo(maximum) > 0) return false;
            }
            return true;
          });
        })
        .map(mapTransferToTransaction);

    txns = [...txns, ...filteredTransfers];
    if (ledgerFilters != null) {
      txns = ledgerFilters.apply(txns);
      if (ledgerQuery!.uncategorizedOnly) {
        txns = txns
            .where((transaction) => transaction.categoryId == null)
            .toList();
      }
    }

    // Search composes with active filters via AND logic (Task 16.4).
    if (normalizedQuery.isNotEmpty) {
      txns = txns.where((t) {
        final payee = t.payeeId == null ? null : payeesById[t.payeeId];
        return _matchesSearch(t, payee, normalizedQuery);
      }).toList();
    }

    txns.sort(
      listIntent.sort == TransactionSort.newestFirst
          ? (a, b) => b.occurredAt.compareTo(a.occurredAt)
          : (a, b) => a.occurredAt.compareTo(b.occurredAt),
    );
    return txns;
  });
});

DateTime? _later(DateTime? left, DateTime? right) {
  if (left == null) return right;
  if (right == null) return left;
  return left.isAfter(right) ? left : right;
}

DateTime? _earlier(DateTime? left, DateTime? right) {
  if (left == null) return right;
  if (right == null) return left;
  return left.isBefore(right) ? left : right;
}

bool _matchesSearch(
  Transaction transaction,
  Payee? payee,
  String normalizedQuery,
) {
  final values = <String?>[
    transaction.title,
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

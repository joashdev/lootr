import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../../data/repositories/transaction_repo.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/entities/payee.dart';
import '../../domain/entities/transaction.dart';
import 'repo_providers.dart';

class PayeeSummary {
  final Payee payee;
  final int transactionCount;
  final DateTime? lastUsedAt;

  const PayeeSummary({
    required this.payee,
    required this.transactionCount,
    required this.lastUsedAt,
  });
}

final payeeSummariesProvider = StreamProvider<List<PayeeSummary>>((ref) {
  final payeeRepo = ref.watch(payeeRepoProvider);
  final transactionRepo = ref.watch(transactionRepoProvider);

  final payeesStream = payeeRepo.watchAll().map(
    (rows) => rows.map((row) => row.toEntity()).toList(),
  );
  final transactionsStream = transactionRepo
      .watchFiltered(const TransactionRepoFilters())
      .map((rows) => rows.map((row) => row.toEntity()).toList());

  return Rx.combineLatest2(payeesStream, transactionsStream, (
    List<Payee> payees,
    List<Transaction> transactions,
  ) {
    final summaries =
        payees.map((payee) {
          final payeeTransactions =
              transactions
                  .where((transaction) => transaction.payeeId == payee.id)
                  .toList()
                ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
          return PayeeSummary(
            payee: payee,
            transactionCount: payeeTransactions.length,
            lastUsedAt: payeeTransactions.isEmpty
                ? null
                : payeeTransactions.first.occurredAt,
          );
        }).toList()..sort((a, b) {
          final left = (a.payee.displayName ?? a.payee.normalizedName)
              .toLowerCase();
          final right = (b.payee.displayName ?? b.payee.normalizedName)
              .toLowerCase();
          return left.compareTo(right);
        });
    return summaries;
  });
});

final payeeDetailProvider =
    StreamProvider.family<
      ({Payee payee, List<Transaction> transactions})?,
      String
    >((ref, payeeId) {
      final payeeRepo = ref.watch(payeeRepoProvider);
      final transactionRepo = ref.watch(transactionRepoProvider);

      final payeeStream = payeeRepo
          .watchById(payeeId)
          .map((row) => row?.toEntity());
      final transactionsStream = transactionRepo
          .watchFiltered(TransactionRepoFilters(payeeId: payeeId))
          .map(
            (rows) =>
                rows.map((row) => row.toEntity()).toList()
                  ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt)),
          );

      return Rx.combineLatest2(payeeStream, transactionsStream, (
        Payee? payee,
        List<Transaction> transactions,
      ) {
        if (payee == null) return null;
        return (payee: payee, transactions: transactions);
      });
    });

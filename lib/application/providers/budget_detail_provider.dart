import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/entities/transaction.dart';
import '../../data/repositories/transaction_repo.dart';
import 'repo_providers.dart';

final budgetDetailProvider =
    StreamProvider.family<({Budget budget, List<Transaction> transactions})?, String>(
  (ref, budgetId) {
    final budgetRepo = ref.watch(budgetRepoProvider);
    final txnRepo = ref.watch(transactionRepoProvider);

    final budgetStream = budgetRepo.watchById(budgetId).asyncMap(
      (row) async {
        if (row == null) return null;
        final entity = row.toEntity();
        final spentStream = budgetRepo.watchSpentForBudget(entity.id);
        final spent = await spentStream.first;
        return entity.copyWith(spent: spent);
      },
    );

    final txnStream = txnRepo
        .watchFiltered(const TransactionRepoFilters()).asyncMap((rows) async {
      final budget = await budgetStream.first;
      if (budget == null) return <Transaction>[];
      final startOfMonth = DateTime(budget.year, budget.month);
      final endOfMonth = budget.month == 12
          ? DateTime(budget.year + 1, 1)
          : DateTime(budget.year, budget.month + 1);
      return rows
          .where((r) =>
              r.categoryId == budget.categoryId &&
              r.transactionDirection == 'expense' &&
              !r.occurredAt.isBefore(startOfMonth) &&
              r.occurredAt.isBefore(endOfMonth) &&
              r.deletedAt == null)
          .map((r) => r.toEntity())
          .toList();
    });

    return Rx.combineLatest2(
      budgetStream,
      txnStream,
      (Budget? budget, List<Transaction> transactions) {
        if (budget == null) return null;
        return (budget: budget, transactions: transactions);
      },
    );
  },
);

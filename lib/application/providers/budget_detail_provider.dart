import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/transaction_repo.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/entities/transaction.dart';
import 'repo_providers.dart';

final budgetDetailProvider =
    StreamProvider.family<({Budget budget, List<Transaction> transactions})?, String>(
  (ref, budgetId) {
    final budgetRepo = ref.watch(budgetRepoProvider);
    final txnRepo = ref.watch(transactionRepoProvider);

    // Note: never call `.first` on a stream that already has a listener —
    // drift streams are broadcast, so a late `.first` subscriber gets no
    // replay and waits forever (endless-spinner bug). switchMap keeps every
    // subscription first-class instead.
    return budgetRepo.watchById(budgetId).switchMap((row) {
      if (row == null) {
        return Stream.value(null);
      }
      final entity = row.toEntity();
      final startOfMonth = DateTime(entity.year, entity.month);
      final endOfMonth = entity.month == 12
          ? DateTime(entity.year + 1, 1)
          : DateTime(entity.year, entity.month + 1);

      return Rx.combineLatest2(
        budgetRepo.watchSpentForBudget(entity.id),
        txnRepo.watchFiltered(const TransactionRepoFilters()),
        (double spent, List<TransactionData> rows) {
          final transactions = rows
              .where((r) =>
                  r.categoryId == entity.categoryId &&
                  r.transactionDirection == 'expense' &&
                  !r.occurredAt.isBefore(startOfMonth) &&
                  r.occurredAt.isBefore(endOfMonth) &&
                  r.deletedAt == null)
              .map((r) => r.toEntity())
              .toList();
          return (
            budget: entity.copyWith(spent: spent),
            transactions: transactions,
          );
        },
      );
    });
  },
);

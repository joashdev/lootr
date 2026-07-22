import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/exact_money_codec.dart';
import '../../data/repositories/transaction_repo.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/value_objects/exact_money.dart';
import 'repo_providers.dart';

final budgetDetailProvider =
    StreamProvider.family<
      ({Budget budget, List<Transaction> transactions})?,
      String
    >((ref, budgetId) {
      final budgetRepo = ref.watch(budgetRepoProvider);
      final txnRepo = ref.watch(transactionRepoProvider);
      final accountRepo = ref.watch(accountRepoProvider);

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

        return Rx.combineLatest3(
          budgetRepo.watchExactSpentForBudget(entity.id),
          txnRepo.watchFiltered(
            TransactionRepoFilters(
              categoryId: entity.categoryId,
              direction: 'expense',
              currencyCode: entity.exactAmount.currencyCode,
              from: startOfMonth,
              to: endOfMonth,
            ),
          ),
          accountRepo.watchAll(),
          (
            ExactMoney spent,
            List<TransactionData> rows,
            List<AccountData> accounts,
          ) {
            final accountById = {
              for (final account in accounts) account.id: account,
            };
            final transactions = rows
                .where(
                  (r) =>
                      !r.occurredAt.isBefore(startOfMonth) &&
                      r.occurredAt.isBefore(endOfMonth) &&
                      r.deletedAt == null,
                )
                .map((row) {
                  final account = accountById[row.accountId];
                  if (account == null) return null;
                  final amount = ExactMoneyCodec.transactionAmount(
                    row,
                    account,
                  );
                  return row.toEntity().copyWith(
                    amount: amount.toDouble(),
                    amountAtoms: () => amount.coefficient.toString(),
                    amountScale: () => amount.scale,
                    currencyCode: () => amount.currencyCode,
                  );
                })
                .whereType<Transaction>()
                .toList();
            return (
              budget: entity.copyWith(
                spent: spent.toDouble(),
                exactSpent: () => spent,
              ),
              transactions: transactions,
            );
          },
        );
      });
    });

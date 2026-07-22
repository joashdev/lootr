import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../../data/repositories/transaction_repo.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/services/currency_aggregation.dart';
import '../../domain/value_objects/exact_money.dart';
import 'repo_providers.dart';
import 'reports_provider.dart';

class DashboardCurrencyPartition {
  const DashboardCurrencyPartition({
    required this.currencyCode,
    required this.balance,
    required this.monthlyFlow,
  });

  final String currencyCode;
  final CurrencyBalanceTotals balance;
  final CurrencyFlowTotals monthlyFlow;
}

class BudgetCurrencyPartition {
  const BudgetCurrencyPartition({
    required this.currencyCode,
    required this.budgeted,
    required this.spent,
  });

  final String currencyCode;
  final ExactMoney budgeted;
  final ExactMoney spent;
}

/// Exact dashboard totals partitioned by currency. Presentation code may
/// project one partition to doubles, but there is deliberately no grand total.
final dashboardCurrencyTotalsProvider =
    StreamProvider<List<DashboardCurrencyPartition>>((ref) {
      final accountRepo = ref.watch(accountRepoProvider);
      final transactionRepo = ref.watch(transactionRepoProvider);
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month);

      final accounts = accountRepo.watchAll().map(
        (rows) => rows.map((row) => row.toEntity()).toList(),
      );
      final transactions = transactionRepo
          .watchFiltered(TransactionRepoFilters(from: monthStart, to: now))
          .map((rows) => rows.map((row) => row.toEntity()).toList());

      return Rx.combineLatest2(accounts, transactions, (accountRows, txRows) {
        final balances = CurrencyAggregation.balances(
          accountRows,
          isLiability: isLiabilityAccountType,
        );
        final flows = CurrencyAggregation.flows(txRows);
        final currencies = {...balances.keys, ...flows.keys}.toList()..sort();
        return [
          for (final currency in currencies)
            DashboardCurrencyPartition(
              currencyCode: currency,
              balance:
                  balances[currency] ??
                  _emptyBalance(currency, flows[currency]!.income.scale),
              monthlyFlow:
                  flows[currency] ??
                  _emptyFlow(currency, balances[currency]!.assets.scale),
            ),
        ];
      });
    });

/// Exact six-month report totals partitioned by currency.
final reportsCurrencyTotalsProvider =
    StreamProvider<Map<String, CurrencyFlowTotals>>((ref) {
      final transactionRepo = ref.watch(transactionRepoProvider);
      final now = ref.watch(reportsClockProvider);
      final windowStart = DateTime(now.year, now.month - 5);
      return transactionRepo
          .watchFiltered(TransactionRepoFilters(from: windowStart, to: now))
          .map(
            (rows) =>
                CurrencyAggregation.flows(rows.map((row) => row.toEntity())),
          );
    });

/// Legacy calendar budgets grouped by their explicit currency. Composite
/// imported budgets expose their own evaluator; neither path forms a
/// cross-currency grand total.
final budgetCurrencyTotalsProvider =
    StreamProvider<List<BudgetCurrencyPartition>>((ref) {
      final budgetRepo = ref.watch(budgetRepoProvider);
      final now = DateTime.now();
      return budgetRepo.watchAll(month: now.month, year: now.year).switchMap((
        rows,
      ) {
        final budgets = rows.map((row) => row.toEntity()).toList();
        if (budgets.isEmpty) {
          return Stream.value(const <BudgetCurrencyPartition>[]);
        }
        return Rx.combineLatestList<ExactMoney>(
          budgets.map(
            (budget) => budgetRepo.watchExactSpentForBudget(budget.id),
          ),
        ).map((spent) {
          final budgetedByCurrency = CurrencyAggregation.budgeted(budgets);
          final spentByCurrency = <String, ExactMoney>{};
          for (var index = 0; index < budgets.length; index++) {
            final value = spent[index];
            spentByCurrency.update(
              value.currencyCode,
              (current) => current + value,
              ifAbsent: () => value,
            );
          }
          final currencies = {
            ...budgetedByCurrency.keys,
            ...spentByCurrency.keys,
          }.toList()..sort();
          return [
            for (final currency in currencies)
              BudgetCurrencyPartition(
                currencyCode: currency,
                budgeted:
                    budgetedByCurrency[currency] ??
                    _zeroLike(spentByCurrency[currency]!),
                spent:
                    spentByCurrency[currency] ??
                    _zeroLike(budgetedByCurrency[currency]!),
              ),
          ];
        });
      });
    });

CurrencyBalanceTotals _emptyBalance(String currency, int scale) {
  final zero = _zero(currency, scale);
  return CurrencyBalanceTotals(assets: zero, liabilities: zero);
}

CurrencyFlowTotals _emptyFlow(String currency, int scale) {
  final zero = _zero(currency, scale);
  return CurrencyFlowTotals(income: zero, expense: zero);
}

ExactMoney _zero(String currency, int scale) =>
    ExactMoney(coefficient: BigInt.zero, scale: scale, currencyCode: currency);

ExactMoney _zeroLike(ExactMoney value) =>
    _zero(value.currencyCode, value.scale);

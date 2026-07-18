import '../entities/account.dart';
import '../entities/budget.dart';
import '../entities/transaction.dart';
import '../value_objects/exact_money.dart';

class CurrencyFlowTotals {
  const CurrencyFlowTotals({required this.income, required this.expense});

  final ExactMoney income;
  final ExactMoney expense;

  ExactMoney get net => income - expense;
}

class CurrencyBalanceTotals {
  const CurrencyBalanceTotals({
    required this.assets,
    required this.liabilities,
  });

  final ExactMoney assets;
  final ExactMoney liabilities;

  ExactMoney get netWorth => assets - liabilities;
}

class CurrencyBudgetTotals {
  const CurrencyBudgetTotals({required this.budgeted, required this.spent});

  final ExactMoney budgeted;
  final ExactMoney spent;
}

class CurrencyAggregation {
  const CurrencyAggregation._();

  static Map<String, CurrencyFlowTotals> flows(
    Iterable<Transaction> transactions,
  ) {
    final income = <String, ExactMoney>{};
    final expense = <String, ExactMoney>{};
    for (final transaction in transactions) {
      if (transaction.deletedAt != null) continue;
      final amount = transaction.exactAmount;
      final target = switch (transaction.direction) {
        'income' => income,
        'expense' => expense,
        _ => null,
      };
      if (target == null) continue;
      target.update(
        amount.currencyCode,
        (current) => current + amount,
        ifAbsent: () => amount,
      );
    }
    final currencies = {...income.keys, ...expense.keys};
    return {
      for (final currency in currencies)
        currency: CurrencyFlowTotals(
          income: income[currency] ?? _zeroLike(expense[currency]!),
          expense: expense[currency] ?? _zeroLike(income[currency]!),
        ),
    };
  }

  static Map<String, CurrencyBalanceTotals> balances(
    Iterable<Account> accounts, {
    required bool Function(String accountType) isLiability,
  }) {
    final assets = <String, ExactMoney>{};
    final liabilities = <String, ExactMoney>{};
    for (final account in accounts) {
      if (account.deletedAt != null || account.isArchived || account.isHidden) {
        continue;
      }
      final amount = account.exactBalance;
      final target = isLiability(account.accountType) ? liabilities : assets;
      final normalized = isLiability(account.accountType)
          ? amount.abs()
          : amount;
      target.update(
        amount.currencyCode,
        (current) => current + normalized,
        ifAbsent: () => normalized,
      );
    }
    final currencies = {...assets.keys, ...liabilities.keys};
    return {
      for (final currency in currencies)
        currency: CurrencyBalanceTotals(
          assets: assets[currency] ?? _zeroLike(liabilities[currency]!),
          liabilities: liabilities[currency] ?? _zeroLike(assets[currency]!),
        ),
    };
  }

  static Map<String, ExactMoney> budgeted(Iterable<Budget> budgets) {
    final totals = <String, ExactMoney>{};
    for (final budget in budgets) {
      if (budget.deletedAt != null) continue;
      final amount = budget.exactAmount;
      totals.update(
        amount.currencyCode,
        (current) => current + amount,
        ifAbsent: () => amount,
      );
    }
    return totals;
  }

  static ExactMoney _zeroLike(ExactMoney value) => ExactMoney(
    coefficient: BigInt.zero,
    scale: value.scale,
    currencyCode: value.currencyCode,
  );
}

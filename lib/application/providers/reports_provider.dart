import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/transaction_repo.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/user.dart';
import '../../domain/services/currency_aggregation.dart';
import '../../domain/value_objects/exact_money.dart';
import 'repo_providers.dart';

/// Injectable clock so report aggregation windows are testable.
final reportsClockProvider = Provider<DateTime>((ref) => DateTime.now());

// ---------------------------------------------------------------------------
// Report models
// ---------------------------------------------------------------------------

class ReportCategorySlice {
  const ReportCategorySlice({
    required this.categoryId,
    required this.name,
    required this.color,
    required this.amount,
    required this.percentage,
  });

  final String? categoryId;
  final String name;
  final Color color;
  final double amount;

  /// Share of total spend, 0..1.
  final double percentage;
}

class CategorySpendingReport {
  const CategorySpendingReport({
    required this.currencyCode,
    required this.periodLabel,
    required this.total,
    required this.slices,
  });

  final String currencyCode;
  final String periodLabel;
  final double total;
  final List<ReportCategorySlice> slices;

  bool get isEmpty => slices.isEmpty;
}

class MonthlyFlowPoint {
  const MonthlyFlowPoint({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
  });

  final int year;
  final int month;
  final double income;
  final double expense;

  double get net => income - expense;

  String get label => DateFormat.MMM().format(DateTime(year, month));
}

class MonthlyFlowReport {
  const MonthlyFlowReport({
    required this.currencyCode,
    required this.months,
    required this.totalIncome,
    required this.totalExpense,
  });

  final String currencyCode;

  /// Oldest first, newest (current month) last.
  final List<MonthlyFlowPoint> months;
  final double totalIncome;
  final double totalExpense;

  double get totalNet => totalIncome - totalExpense;

  bool get isEmpty => totalIncome == 0 && totalExpense == 0;
}

class NetWorthReport {
  const NetWorthReport({
    required this.currencyCode,
    required this.current,
    required this.series,
    required this.changePercent,
    required this.startDate,
    required this.endDate,
    required this.hasAccounts,
  });

  final String currencyCode;
  final double current;

  /// One point per day, oldest first, ending at [current].
  final List<double> series;
  final double changePercent;
  final DateTime startDate;
  final DateTime endDate;
  final bool hasAccounts;

  bool get isEmpty => !hasAccounts;
}

class BudgetPerformanceRow {
  const BudgetPerformanceRow({
    required this.budgetId,
    required this.name,
    required this.color,
    required this.budgeted,
    required this.spent,
  });

  final String budgetId;
  final String name;
  final Color color;
  final double budgeted;
  final double spent;

  double get progress => budgeted <= 0 ? 0 : spent / budgeted;
}

class BudgetPerformanceReport {
  const BudgetPerformanceReport({
    required this.currencyCode,
    required this.periodLabel,
    required this.rows,
    required this.totalBudgeted,
    required this.totalSpent,
  });

  final String currencyCode;
  final String periodLabel;

  /// Sorted by progress, most-consumed budget first.
  final List<BudgetPerformanceRow> rows;
  final double totalBudgeted;
  final double totalSpent;

  double get progress => totalBudgeted <= 0 ? 0 : totalSpent / totalBudgeted;

  bool get isEmpty => rows.isEmpty;
}

class _BudgetWithExactSpent {
  const _BudgetWithExactSpent(this.budget, this.spent);

  final Budget budget;
  final ExactMoney spent;
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final categorySpendingReportProvider = StreamProvider<CategorySpendingReport>((
  ref,
) {
  final userRepo = ref.watch(userRepoProvider);
  final categoryRepo = ref.watch(categoryRepoProvider);
  final transactionRepo = ref.watch(transactionRepoProvider);

  final now = ref.watch(reportsClockProvider);
  final monthStart = DateTime(now.year, now.month);

  final userStream = userRepo.watchCurrentUser().map(
    (row) => row == null ? null : UserDataMapper(row).toEntity(),
  );
  final categoriesStream = categoryRepo.watchAll().map(_activeCategories);
  final transactionsStream = transactionRepo
      .watchFiltered(TransactionRepoFilters(from: monthStart, to: now))
      .map(_activeTransactions);

  return Rx.combineLatest3<
    User?,
    List<Category>,
    List<Transaction>,
    CategorySpendingReport
  >(userStream, categoriesStream, transactionsStream, (
    user,
    categories,
    transactions,
  ) {
    final categoryById = {
      for (final category in categories) category.id: category,
    };

    final currencyCode = user?.currencyCode ?? 'PHP';
    final totals = <String?, ExactMoney>{};
    for (final txn in transactions) {
      if (txn.direction != 'expense' ||
          txn.exactAmount.currencyCode != currencyCode) {
        continue;
      }
      totals.update(
        txn.categoryId,
        (current) => current + txn.exactAmount,
        ifAbsent: () => txn.exactAmount,
      );
    }
    final total = totals.values.isEmpty
        ? null
        : totals.values.reduce((left, right) => left + right);

    final slices = totals.entries.map((entry) {
      final category = entry.key == null ? null : categoryById[entry.key];
      return ReportCategorySlice(
        categoryId: entry.key,
        name: category?.name ?? 'Uncategorized',
        color: categoryColorFromHex(category?.color),
        amount: entry.value.toDouble(),
        percentage: total == null || total.isZero
            ? 0
            : entry.value.toDouble() / total.toDouble(),
      );
    }).toList()..sort((a, b) => b.amount.compareTo(a.amount));

    return CategorySpendingReport(
      currencyCode: currencyCode,
      periodLabel: DateFormat.yMMMM().format(monthStart),
      total: total?.toDouble() ?? 0,
      slices: slices,
    );
  });
});

/// Income and expense totals for the trailing six months (current inclusive).
/// Backs both the "Income vs Expenses" and "Cash Flow" reports.
final monthlyFlowReportProvider = StreamProvider<MonthlyFlowReport>((ref) {
  final userRepo = ref.watch(userRepoProvider);
  final transactionRepo = ref.watch(transactionRepoProvider);

  final now = ref.watch(reportsClockProvider);
  final windowStart = DateTime(now.year, now.month - 5);

  final userStream = userRepo.watchCurrentUser().map(
    (row) => row == null ? null : UserDataMapper(row).toEntity(),
  );
  final transactionsStream = transactionRepo
      .watchFiltered(TransactionRepoFilters(from: windowStart, to: now))
      .map(_activeTransactions);

  return Rx.combineLatest2<User?, List<Transaction>, MonthlyFlowReport>(
    userStream,
    transactionsStream,
    (user, transactions) {
      final currencyCode = user?.currencyCode ?? 'PHP';
      final incomeByMonth = <int, ExactMoney>{};
      final expenseByMonth = <int, ExactMoney>{};
      for (final txn in transactions) {
        if (txn.exactAmount.currencyCode != currencyCode) continue;
        final key = txn.occurredAt.year * 12 + (txn.occurredAt.month - 1);
        if (txn.direction == 'income') {
          incomeByMonth.update(
            key,
            (current) => current + txn.exactAmount,
            ifAbsent: () => txn.exactAmount,
          );
        } else if (txn.direction == 'expense') {
          expenseByMonth.update(
            key,
            (current) => current + txn.exactAmount,
            ifAbsent: () => txn.exactAmount,
          );
        }
      }

      final months = <MonthlyFlowPoint>[];
      ExactMoney? totalIncome;
      ExactMoney? totalExpense;
      for (var i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i);
        final key = month.year * 12 + (month.month - 1);
        final income = incomeByMonth[key];
        final expense = expenseByMonth[key];
        if (income != null) {
          totalIncome = totalIncome == null ? income : totalIncome + income;
        }
        if (expense != null) {
          totalExpense = totalExpense == null
              ? expense
              : totalExpense + expense;
        }
        months.add(
          MonthlyFlowPoint(
            year: month.year,
            month: month.month,
            income: income?.toDouble() ?? 0,
            expense: expense?.toDouble() ?? 0,
          ),
        );
      }

      return MonthlyFlowReport(
        currencyCode: currencyCode,
        months: months,
        totalIncome: totalIncome?.toDouble() ?? 0,
        totalExpense: totalExpense?.toDouble() ?? 0,
      );
    },
  );
});

/// Daily net worth over the trailing 90 days, reconstructed from the current
/// account balances minus the net impact of transactions after each day.
final netWorthReportProvider = StreamProvider<NetWorthReport>((ref) {
  final userRepo = ref.watch(userRepoProvider);
  final accountRepo = ref.watch(accountRepoProvider);
  final transactionRepo = ref.watch(transactionRepoProvider);

  final now = ref.watch(reportsClockProvider);
  final today = DateTime(now.year, now.month, now.day);
  const days = 90;
  final windowStart = today.subtract(const Duration(days: days - 1));

  final userStream = userRepo.watchCurrentUser().map(
    (row) => row == null ? null : UserDataMapper(row).toEntity(),
  );
  final accountsStream = accountRepo.watchAll().map(
    (rows) => rows
        .map((row) => AccountDataMapper(row).toEntity())
        .where(
          (account) =>
              !account.isArchived &&
              !account.isHidden &&
              account.deletedAt == null,
        )
        .toList(),
  );
  final transactionsStream = transactionRepo
      .watchFiltered(TransactionRepoFilters(from: windowStart, to: now))
      .map(_activeTransactions);

  return Rx.combineLatest3<
    User?,
    List<Account>,
    List<Transaction>,
    NetWorthReport
  >(userStream, accountsStream, transactionsStream, (
    user,
    accounts,
    transactions,
  ) {
    final currencyCode = user?.currencyCode ?? 'PHP';
    final currencyAccounts = accounts
        .where((account) => account.currencyCode == currencyCode)
        .toList();
    final exactBalances = CurrencyAggregation.balances(
      currencyAccounts,
      isLiability: isLiabilityAccountType,
    )[currencyCode];
    final exactNetWorth =
        exactBalances?.netWorth ??
        ExactMoney(
          coefficient: BigInt.zero,
          scale: 2,
          currencyCode: currencyCode,
        );
    final netWorth = exactNetWorth.toDouble();

    final impactByDay = <int, ExactMoney>{};
    for (final txn in transactions) {
      if (txn.exactAmount.currencyCode != currencyCode) continue;
      final day = DateTime(
        txn.occurredAt.year,
        txn.occurredAt.month,
        txn.occurredAt.day,
      );
      final index = day.difference(windowStart).inDays;
      if (index < 0 || index >= days) continue;
      final impact = switch (txn.direction) {
        'income' => txn.exactAmount,
        'expense' => -txn.exactAmount,
        _ => null,
      };
      if (impact == null) continue;
      impactByDay.update(
        index,
        (current) => current + impact,
        ifAbsent: () => impact,
      );
    }

    final zero = ExactMoney(
      coefficient: BigInt.zero,
      scale: exactNetWorth.scale,
      currencyCode: currencyCode,
    );
    final totalImpact = impactByDay.values.fold<ExactMoney>(
      zero,
      (sum, value) => sum + value,
    );
    var running = exactNetWorth - totalImpact;
    final series = <double>[];
    for (var i = 0; i < days; i++) {
      running += impactByDay[i] ?? zero;
      series.add(running.toDouble());
    }

    final first = series.first;
    final changePercent = first == 0
        ? 0.0
        : ((series.last - first) / first.abs()) * 100;

    return NetWorthReport(
      currencyCode: currencyCode,
      current: netWorth,
      series: series,
      changePercent: changePercent,
      startDate: windowStart,
      endDate: today,
      hasAccounts: currencyAccounts.isNotEmpty,
    );
  });
});

final budgetPerformanceReportProvider = StreamProvider<BudgetPerformanceReport>(
  (ref) {
    final userRepo = ref.watch(userRepoProvider);
    final budgetRepo = ref.watch(budgetRepoProvider);
    final categoryRepo = ref.watch(categoryRepoProvider);

    final now = ref.watch(reportsClockProvider);

    final userStream = userRepo.watchCurrentUser().map(
      (row) => row == null ? null : UserDataMapper(row).toEntity(),
    );
    final categoriesStream = categoryRepo.watchAll().map(_activeCategories);
    final budgetsStream = budgetRepo
        .watchAll(month: now.month, year: now.year)
        .map(
          (rows) => rows
              .map((row) => BudgetDataMapper(row).toEntity())
              .where((budget) => budget.deletedAt == null)
              .toList(),
        )
        .switchMap((budgets) {
          if (budgets.isEmpty) {
            return Stream.value(<_BudgetWithExactSpent>[]);
          }

          return Rx.combineLatestList<ExactMoney>(
            budgets.map(
              (budget) => budgetRepo.watchExactSpentForBudget(budget.id),
            ),
          ).map((spentValues) {
            return [
              for (var i = 0; i < budgets.length; i++)
                _BudgetWithExactSpent(budgets[i], spentValues[i]),
            ];
          });
        });

    return Rx.combineLatest3<
      User?,
      List<Category>,
      List<_BudgetWithExactSpent>,
      BudgetPerformanceReport
    >(userStream, categoriesStream, budgetsStream, (user, categories, entries) {
      final currencyCode = user?.currencyCode ?? 'PHP';
      final categoryById = {
        for (final category in categories) category.id: category,
      };

      final selected = entries
          .where(
            (entry) =>
                entry.budget.exactAmount.currencyCode == currencyCode &&
                entry.spent.currencyCode == currencyCode,
          )
          .toList();
      final rows = selected.map((entry) {
        final budget = entry.budget;
        final category = categoryById[budget.categoryId];
        return BudgetPerformanceRow(
          budgetId: budget.id,
          name: category?.name ?? 'Budget',
          color: categoryColorFromHex(category?.color),
          budgeted: budget.exactAmount.toDouble(),
          spent: entry.spent.toDouble(),
        );
      }).toList()..sort((a, b) => b.progress.compareTo(a.progress));

      ExactMoney? totalBudgeted;
      ExactMoney? totalSpent;
      for (final entry in selected) {
        totalBudgeted = totalBudgeted == null
            ? entry.budget.exactAmount
            : totalBudgeted + entry.budget.exactAmount;
        totalSpent = totalSpent == null
            ? entry.spent
            : totalSpent + entry.spent;
      }

      return BudgetPerformanceReport(
        currencyCode: currencyCode,
        periodLabel: DateFormat.yMMMM().format(DateTime(now.year, now.month)),
        rows: rows,
        totalBudgeted: totalBudgeted?.toDouble() ?? 0,
        totalSpent: totalSpent?.toDouble() ?? 0,
      );
    });
  },
);

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

List<Category> _activeCategories(List<CategoryData> rows) => rows
    .map((row) => CategoryDataMapper(row).toEntity())
    .where((category) => category.deletedAt == null)
    .toList();

List<Transaction> _activeTransactions(List<TransactionData> rows) => rows
    .where((row) => row.deletedAt == null)
    .map((row) => TransactionDataMapper(row).toEntity())
    .toList();

bool isLiabilityAccountType(String accountType) {
  return accountType == 'credit_card' ||
      accountType == 'loan' ||
      accountType == 'bnpl';
}

Color categoryColorFromHex(String? rawColor) {
  if (rawColor == null || rawColor.isEmpty) return Colors.blueGrey;
  final hex = rawColor.replaceFirst('#', '');
  if (hex.length != 6) return Colors.blueGrey;
  return Color(int.parse('FF$hex', radix: 16));
}

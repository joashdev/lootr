import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/transaction_repo.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/services/currency_aggregation.dart';
import '../../domain/value_objects/exact_money.dart';
import 'budget_projection.dart';
import 'budgets_tab_provider.dart';
import 'period_context_provider.dart';
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
    required this.isImported,
    required this.isReadOnly,
    required this.periodStart,
  });

  final String budgetId;
  final String name;
  final Color color;
  final double budgeted;
  final double spent;
  final bool isImported;
  final bool isReadOnly;
  final DateTime periodStart;

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

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final categorySpendingReportProvider =
    StreamProvider<List<CategorySpendingReport>>((ref) {
      final categoryRepo = ref.watch(categoryRepoProvider);
      final transactionRepo = ref.watch(transactionRepoProvider);

      final period = ref.watch(periodContextProvider);
      final periodStart = period.startsAt;
      final periodEnd = period.inclusiveEnd;

      final categoriesStream = categoryRepo.watchAll().map(_activeCategories);
      final transactionsStream = transactionRepo
          .watchFiltered(
            TransactionRepoFilters(from: periodStart, to: periodEnd),
          )
          .map(_activeTransactions);

      return Rx.combineLatest2<
        List<Category>,
        List<Transaction>,
        List<CategorySpendingReport>
      >(categoriesStream, transactionsStream, (categories, transactions) {
        final categoryById = {
          for (final category in categories) category.id: category,
        };

        final totalsByCurrency = <String, Map<String?, ExactMoney>>{};
        for (final txn in transactions) {
          if (txn.direction != 'expense') continue;
          final currencyTotals = totalsByCurrency.putIfAbsent(
            txn.exactAmount.currencyCode,
            () => <String?, ExactMoney>{},
          );
          currencyTotals.update(
            txn.categoryId,
            (current) => current + txn.exactAmount,
            ifAbsent: () => txn.exactAmount,
          );
        }

        final currencyCodes = totalsByCurrency.keys.toList()..sort();
        return [
          for (final currencyCode in currencyCodes)
            _buildCategorySpendingReport(
              currencyCode: currencyCode,
              periodLabel: period.description,
              categoryById: categoryById,
              totals: totalsByCurrency[currencyCode]!,
            ),
        ];
      });
    });

CategorySpendingReport _buildCategorySpendingReport({
  required String currencyCode,
  required String periodLabel,
  required Map<String, Category> categoryById,
  required Map<String?, ExactMoney> totals,
}) {
  final total = totals.values.reduce((left, right) => left + right);
  final slices = totals.entries.map((entry) {
    final category = entry.key == null ? null : categoryById[entry.key];
    return ReportCategorySlice(
      categoryId: entry.key,
      name: category?.name ?? 'Uncategorized',
      color: categoryColorFromHex(category?.color),
      amount: entry.value.toDouble(),
      percentage: total.isZero ? 0 : entry.value.toDouble() / total.toDouble(),
    );
  }).toList()..sort((a, b) => b.amount.compareTo(a.amount));

  return CategorySpendingReport(
    currencyCode: currencyCode,
    periodLabel: periodLabel,
    total: total.toDouble(),
    slices: slices,
  );
}

/// Income and expense totals for the trailing six months (current inclusive).
/// Backs both the "Income vs Expenses" and "Cash Flow" reports.
final monthlyFlowReportProvider = StreamProvider<List<MonthlyFlowReport>>((
  ref,
) {
  final transactionRepo = ref.watch(transactionRepoProvider);

  final period = ref.watch(periodContextProvider);
  final windowEnd = period.inclusiveEnd;
  final windowStart = DateTime(period.startsAt.year, period.startsAt.month - 5);

  final transactionsStream = transactionRepo
      .watchFiltered(TransactionRepoFilters(from: windowStart, to: windowEnd))
      .map(_activeTransactions);

  return transactionsStream.map((transactions) {
    final currencyCodes =
        transactions
            .where(
              (txn) => txn.direction == 'income' || txn.direction == 'expense',
            )
            .map((txn) => txn.exactAmount.currencyCode)
            .toSet()
            .toList()
          ..sort();

    return [
      for (final currencyCode in currencyCodes)
        _buildMonthlyFlowReport(
          currencyCode: currencyCode,
          transactions: transactions,
          now: period.startsAt,
        ),
    ];
  });
});

MonthlyFlowReport _buildMonthlyFlowReport({
  required String currencyCode,
  required List<Transaction> transactions,
  required DateTime now,
}) {
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
      totalExpense = totalExpense == null ? expense : totalExpense + expense;
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
}

/// Daily net worth over the trailing 90 days, reconstructed from the current
/// account balances minus the net impact of transactions after each day.
final netWorthReportProvider = StreamProvider<List<NetWorthReport>>((ref) {
  final accountRepo = ref.watch(accountRepoProvider);
  final transactionRepo = ref.watch(transactionRepoProvider);

  final period = ref.watch(periodContextProvider);
  final periodEnd = period.inclusiveEnd;
  final today = DateTime(periodEnd.year, periodEnd.month, periodEnd.day);
  const days = 90;
  final windowStart = today.subtract(const Duration(days: days - 1));

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
      .watchFiltered(TransactionRepoFilters(from: windowStart))
      .map(_activeTransactions);

  return Rx.combineLatest2<
    List<Account>,
    List<Transaction>,
    List<NetWorthReport>
  >(accountsStream, transactionsStream, (accounts, transactions) {
    final currencyCodes =
        accounts.map((account) => account.currencyCode).toSet().toList()
          ..sort();
    return [
      for (final currencyCode in currencyCodes)
        _buildNetWorthReport(
          currencyCode: currencyCode,
          accounts: accounts,
          transactions: transactions,
          windowStart: windowStart,
          today: today,
          days: days,
        ),
    ];
  });
});

NetWorthReport _buildNetWorthReport({
  required String currencyCode,
  required List<Account> accounts,
  required List<Transaction> transactions,
  required DateTime windowStart,
  required DateTime today,
  required int days,
}) {
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
  final zero = ExactMoney(
    coefficient: BigInt.zero,
    scale: exactNetWorth.scale,
    currencyCode: currencyCode,
  );
  var totalImpactSinceWindowStart = zero;
  for (final txn in transactions) {
    if (txn.exactAmount.currencyCode != currencyCode) continue;
    final day = DateTime(
      txn.occurredAt.year,
      txn.occurredAt.month,
      txn.occurredAt.day,
    );
    final index = day.difference(windowStart).inDays;
    final impact = switch (txn.direction) {
      'income' => txn.exactAmount,
      'expense' => -txn.exactAmount,
      _ => null,
    };
    if (impact == null) continue;
    totalImpactSinceWindowStart += impact;
    if (index < 0 || index >= days) continue;
    impactByDay.update(
      index,
      (current) => current + impact,
      ifAbsent: () => impact,
    );
  }

  var running = exactNetWorth - totalImpactSinceWindowStart;
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
}

final budgetPerformanceReportProvider =
    StreamProvider<List<BudgetPerformanceReport>>((ref) {
      final budgetRepo = ref.watch(budgetRepoProvider);
      final compositeBudgetRepo = ref.watch(compositeBudgetRepoProvider);
      final categoryRepo = ref.watch(categoryRepoProvider);

      final period = ref.watch(periodContextProvider);
      final anchor = period.startsAt;

      final categoriesStream = categoryRepo.watchAll().map(_activeCategories);
      final legacyBudgetsStream = budgetRepo
          .watchAll(month: anchor.month, year: anchor.year)
          .map(
            (rows) => rows
                .map((row) => BudgetDataMapper(row).toEntity())
                .where((budget) => budget.deletedAt == null)
                .toList(),
          )
          .switchMap((budgets) {
            if (budgets.isEmpty) return Stream.value(<BudgetOverview>[]);

            return Rx.combineLatestList<ExactMoney>(
              budgets.map(
                (budget) => budgetRepo.watchExactSpentForBudget(budget.id),
              ),
            ).map((spentValues) {
              return [
                for (var i = 0; i < budgets.length; i++)
                  BudgetOverview(
                    id: budgets[i].id,
                    name: 'Budget',
                    categoryId: budgets[i].categoryId,
                    budgeted: budgets[i].exactAmount,
                    spent: spentValues[i],
                    startsAt: DateTime(anchor.year, anchor.month),
                    endsAt: anchor.month == 12
                        ? DateTime(anchor.year + 1)
                        : DateTime(anchor.year, anchor.month + 1),
                    isImported: false,
                    isReadOnly: false,
                    needsReview: false,
                    missingReferenceCount: 0,
                    legacyBudget: budgets[i],
                  ),
              ];
            });
          });
      final importedBudgetsStream = compositeBudgetRepo
          .watchForPeriod(anchor)
          .map((snapshots) => snapshots.map(compositeBudgetOverview).toList());
      final budgetsStream =
          Rx.combineLatest2<
            List<BudgetOverview>,
            List<BudgetOverview>,
            List<BudgetOverview>
          >(
            legacyBudgetsStream,
            importedBudgetsStream,
            (legacy, imported) => [...legacy, ...imported],
          );

      return Rx.combineLatest2<
        List<Category>,
        List<BudgetOverview>,
        List<BudgetPerformanceReport>
      >(categoriesStream, budgetsStream, (categories, entries) {
        final categoryById = {
          for (final category in categories) category.id: category,
        };
        final currencyCodes =
            entries.map((entry) => entry.currencyCode).toSet().toList()..sort();

        return [
          for (final currencyCode in currencyCodes)
            _buildBudgetPerformanceReport(
              currencyCode: currencyCode,
              periodLabel: period.description,
              categoryById: categoryById,
              entries: entries,
            ),
        ];
      });
    });

BudgetPerformanceReport _buildBudgetPerformanceReport({
  required String currencyCode,
  required String periodLabel,
  required Map<String, Category> categoryById,
  required List<BudgetOverview> entries,
}) {
  final selected = entries
      .where(
        (entry) =>
            entry.budgeted.currencyCode == currencyCode &&
            entry.spent.currencyCode == currencyCode,
      )
      .toList();
  final rows = selected.map((entry) {
    final category = entry.categoryId == null
        ? null
        : categoryById[entry.categoryId];
    return BudgetPerformanceRow(
      budgetId: entry.id,
      name: entry.isImported ? entry.name : category?.name ?? 'Budget',
      color: categoryColorFromHex(category?.color),
      budgeted: entry.budgeted.toDouble(),
      spent: entry.spent.toDouble(),
      isImported: entry.isImported,
      isReadOnly: entry.isReadOnly,
      periodStart: entry.startsAt,
    );
  }).toList()..sort((a, b) => b.progress.compareTo(a.progress));

  ExactMoney? totalBudgeted;
  ExactMoney? totalSpent;
  for (final entry in selected) {
    totalBudgeted = totalBudgeted == null
        ? entry.budgeted
        : totalBudgeted + entry.budgeted;
    totalSpent = totalSpent == null ? entry.spent : totalSpent + entry.spent;
  }

  return BudgetPerformanceReport(
    currencyCode: currencyCode,
    periodLabel: periodLabel,
    rows: rows,
    totalBudgeted: totalBudgeted?.toDouble() ?? 0,
    totalSpent: totalSpent?.toDouble() ?? 0,
  );
}

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

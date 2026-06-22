import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../../data/repositories/transaction_repo.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/entities/payee.dart';
import '../../domain/entities/recurring_template.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/user.dart';
import 'repo_providers.dart';

class DashboardBudgetSummary {
  const DashboardBudgetSummary({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.budgeted,
    required this.spent,
  });

  final String id;
  final String name;
  final String? icon;
  final Color color;
  final double budgeted;
  final double spent;

  double get progress => budgeted <= 0 ? 0 : spent / budgeted;
}

class DashboardSpendingSlice {
  const DashboardSpendingSlice({
    required this.categoryId,
    required this.name,
    required this.color,
    required this.amount,
    required this.percentage,
  });

  final String categoryId;
  final String name;
  final Color color;
  final double amount;
  final double percentage;
}

class DashboardTransactionItem {
  const DashboardTransactionItem({
    required this.id,
    required this.payeeName,
    required this.accountName,
    required this.categoryName,
    required this.amount,
    required this.direction,
    required this.occurredAt,
  });

  final String id;
  final String payeeName;
  final String accountName;
  final String categoryName;
  final double amount;
  final String direction;
  final DateTime occurredAt;
}

class DashboardRecurringItem {
  const DashboardRecurringItem({
    required this.id,
    required this.payeeName,
    required this.amount,
    required this.nextOccurrenceAt,
  });

  final String id;
  final String payeeName;
  final double amount;
  final DateTime nextOccurrenceAt;
}

class DashboardInsight {
  const DashboardInsight({
    required this.id,
    required this.title,
    required this.body,
  });

  final String id;
  final String title;
  final String body;
}

class DashboardData {
  const DashboardData({
    required this.greeting,
    required this.displayName,
    required this.currentDate,
    required this.currencyCode,
    required this.safeToSpend,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.netWorth,
    required this.netWorthSeries,
    required this.netWorthChangePercent,
    required this.accounts,
    required this.budgets,
    required this.recentTransactions,
    required this.upcomingRecurring,
    required this.spendingByCategory,
    required this.insights,
  });

  final String greeting;
  final String? displayName;
  final DateTime currentDate;
  final String currencyCode;
  final double safeToSpend;
  final double monthlyIncome;
  final double monthlyExpense;
  final double netWorth;
  final List<double> netWorthSeries;
  final double netWorthChangePercent;
  final List<Account> accounts;
  final List<DashboardBudgetSummary> budgets;
  final List<DashboardTransactionItem> recentTransactions;
  final List<DashboardRecurringItem> upcomingRecurring;
  final List<DashboardSpendingSlice> spendingByCategory;
  final List<DashboardInsight> insights;

  bool get isEmpty => accounts.isEmpty && recentTransactions.isEmpty;
}

final recentTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final repo = ref.watch(transactionRepoProvider);
  final now = DateTime.now();
  final from = now.subtract(const Duration(days: 30));

  return repo.watchFiltered(TransactionRepoFilters(from: from, to: now)).map((
    rows,
  ) {
    final sorted =
        rows
            .where((row) => row.deletedAt == null)
            .map((row) => TransactionDataMapper(row).toEntity())
            .toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return sorted.take(10).toList();
  });
});

final dashboardProvider = StreamProvider<DashboardData>((ref) {
  final userRepo = ref.watch(userRepoProvider);
  final accountRepo = ref.watch(accountRepoProvider);
  final budgetRepo = ref.watch(budgetRepoProvider);
  final transactionRepo = ref.watch(transactionRepoProvider);
  final recurringRepo = ref.watch(recurringRepoProvider);
  final categoryRepo = ref.watch(categoryRepoProvider);
  final payeeRepo = ref.watch(payeeRepoProvider);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monthStart = DateTime(now.year, now.month);
  final sparklineStart = today.subtract(const Duration(days: 29));

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
  final categoriesStream = categoryRepo.watchAll().map(
    (rows) => rows
        .map((row) => CategoryDataMapper(row).toEntity())
        .where((category) => category.deletedAt == null)
        .toList(),
  );
  final payeesStream = payeeRepo.watchAll().map(
    (rows) => rows
        .map((row) => PayeeDataMapper(row).toEntity())
        .where((payee) => payee.deletedAt == null)
        .toList(),
  );
  final budgetsStream = budgetRepo
      .watchAll(month: now.month, year: now.year)
      .asyncMap((rows) async {
        final budgets = <Budget>[];
        for (final row in rows) {
          final budget = BudgetDataMapper(row).toEntity();
          final spent = await budgetRepo.watchSpentForBudget(budget.id).first;
          budgets.add(budget.copyWith(spent: spent));
        }
        return budgets;
      });
  final recentTransactionsStream = transactionRepo
      .watchFiltered(TransactionRepoFilters(from: sparklineStart, to: now))
      .map(
        (rows) =>
            rows
                .where((row) => row.deletedAt == null)
                .map((row) => TransactionDataMapper(row).toEntity())
                .toList()
              ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt)),
      );
  final monthTransactionsStream = transactionRepo
      .watchFiltered(TransactionRepoFilters(from: monthStart, to: now))
      .map(
        (rows) =>
            rows
                .where((row) => row.deletedAt == null)
                .map((row) => TransactionDataMapper(row).toEntity())
                .toList()
              ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt)),
      );
  final recurringStream = recurringRepo.watchAll().map((rows) {
    final items =
        rows
            .map((row) => RecurringTemplateDataMapper(row).toEntity())
            .where(
              (template) =>
                  template.deletedAt == null &&
                  template.nextOccurrenceAt != null &&
                  !template.autoCreateDisabled,
            )
            .toList()
          ..sort((a, b) => a.nextOccurrenceAt!.compareTo(b.nextOccurrenceAt!));
    return items;
  });

  return Rx.combineLatestList<dynamic>([
    userStream,
    accountsStream,
    categoriesStream,
    payeesStream,
    budgetsStream,
    recentTransactionsStream,
    monthTransactionsStream,
    recurringStream,
  ]).map((values) {
    final user = values[0] as User?;
    final accounts = values[1] as List<Account>;
    final categories = values[2] as List<Category>;
    final payees = values[3] as List<Payee>;
    final budgets = values[4] as List<Budget>;
    final recentTransactions = values[5] as List<Transaction>;
    final monthTransactions = values[6] as List<Transaction>;
    final recurringTemplates = values[7] as List<RecurringTemplate>;

    final greeting = _greetingFor(now.hour);
    final currencyCode = user?.currencyCode ?? 'PHP';
    final accountById = {for (final account in accounts) account.id: account};
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    final payeeById = {for (final payee in payees) payee.id: payee};

    double totalAssets = 0;
    double totalLiabilities = 0;
    for (final account in accounts) {
      if (_isLiability(account.accountType)) {
        totalLiabilities += account.balance.abs();
      } else {
        totalAssets += account.balance;
      }
    }
    final netWorth = totalAssets - totalLiabilities;

    final upcomingRecurring = recurringTemplates
        .where((item) => !item.nextOccurrenceAt!.isBefore(now))
        .take(5)
        .map(
          (item) => DashboardRecurringItem(
            id: item.id,
            payeeName: _resolveRecurringLabel(item, payeeById, categoryById),
            amount: item.amount,
            nextOccurrenceAt: item.nextOccurrenceAt!,
          ),
        )
        .toList();

    final monthlyIncome = monthTransactions
        .where((txn) => txn.direction == 'income')
        .fold<double>(0, (sum, txn) => sum + txn.amount);
    final monthlyExpense = monthTransactions
        .where((txn) => txn.direction == 'expense')
        .fold<double>(0, (sum, txn) => sum + txn.amount);

    final committedExpenses =
        budgets.fold<double>(0, (sum, budget) => sum + budget.amount) +
        recurringTemplates
            .where(
              (item) => !item.nextOccurrenceAt!.isAfter(
                now.add(const Duration(days: 30)),
              ),
            )
            .fold<double>(0, (sum, item) => sum + item.amount) +
        totalLiabilities;
    final safeToSpend = totalAssets - committedExpenses;

    final budgetSummaries =
        budgets
            .map(
              (budget) => DashboardBudgetSummary(
                id: budget.id,
                name: categoryById[budget.categoryId]?.name ?? 'Budget',
                icon: _categoryBadge(categoryById[budget.categoryId]),
                color: _categoryColor(categoryById[budget.categoryId]?.color),
                budgeted: budget.amount,
                spent: budget.spent,
              ),
            )
            .toList()
          ..sort((a, b) => b.progress.compareTo(a.progress));

    final totalCategorySpend = monthTransactions
        .where((txn) => txn.direction == 'expense' && txn.categoryId != null)
        .fold<double>(0, (sum, txn) => sum + txn.amount);
    final spendingTotals = <String, double>{};
    for (final txn in monthTransactions) {
      if (txn.direction == 'expense' && txn.categoryId != null) {
        spendingTotals[txn.categoryId!] =
            (spendingTotals[txn.categoryId!] ?? 0) + txn.amount;
      }
    }
    final spendingByCategory = spendingTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSpending = spendingByCategory.take(5).map((entry) {
      final category = categoryById[entry.key];
      final percentage = totalCategorySpend == 0
          ? 0
          : entry.value / totalCategorySpend;
      return DashboardSpendingSlice(
        categoryId: entry.key,
        name: category?.name ?? 'Uncategorized',
        color: _categoryColor(category?.color),
        amount: entry.value,
        percentage: percentage.toDouble(),
      );
    }).toList();

    final transactionItems = recentTransactions.take(10).map((txn) {
      final payee = txn.payeeId != null ? payeeById[txn.payeeId!] : null;
      final category = txn.categoryId != null
          ? categoryById[txn.categoryId!]
          : null;
      final account = accountById[txn.accountId];
      return DashboardTransactionItem(
        id: txn.id,
        payeeName: payee?.displayName ?? payee?.normalizedName ?? 'Transaction',
        accountName: account?.name ?? 'Account',
        categoryName: category?.name ?? _fallbackCategoryName(txn.direction),
        amount: txn.amount,
        direction: txn.direction,
        occurredAt: txn.occurredAt,
      );
    }).toList();

    final netWorthSeries = _buildNetWorthSeries(
      currentNetWorth: netWorth,
      startDate: sparklineStart,
      transactions: recentTransactions,
    );
    final firstNetWorth = netWorthSeries.first;
    final netWorthChangePercent = firstNetWorth == 0
        ? 0.0
        : ((netWorthSeries.last - firstNetWorth) / firstNetWorth.abs()) * 100;

    final insights = _buildInsights(
      aiEnabled: user?.aiEnabled ?? false,
      spending: topSpending,
      monthlyIncome: monthlyIncome,
      safeToSpend: safeToSpend,
      budgets: budgetSummaries,
    );

    return DashboardData(
      greeting: greeting,
      displayName: user?.displayName,
      currentDate: now,
      currencyCode: currencyCode,
      safeToSpend: safeToSpend,
      monthlyIncome: monthlyIncome,
      monthlyExpense: monthlyExpense,
      netWorth: netWorth,
      netWorthSeries: netWorthSeries,
      netWorthChangePercent: netWorthChangePercent,
      accounts: accounts,
      budgets: budgetSummaries,
      recentTransactions: transactionItems,
      upcomingRecurring: upcomingRecurring,
      spendingByCategory: topSpending,
      insights: insights,
    );
  });
});

String _greetingFor(int hour) {
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

bool _isLiability(String accountType) {
  return accountType == 'credit_card' ||
      accountType == 'loan' ||
      accountType == 'bnpl';
}

String _fallbackCategoryName(String direction) {
  switch (direction) {
    case 'income':
      return 'Income';
    case 'transfer':
      return 'Transfer';
    default:
      return 'Expense';
  }
}

String _resolveRecurringLabel(
  RecurringTemplate template,
  Map<String, Payee> payeeById,
  Map<String, Category> categoryById,
) {
  final payee = template.payeeId != null ? payeeById[template.payeeId!] : null;
  if (payee != null) {
    return payee.displayName ?? payee.normalizedName;
  }
  if (template.categoryId != null) {
    return categoryById[template.categoryId!]?.name ?? 'Recurring payment';
  }
  return 'Recurring payment';
}

String? _categoryBadge(Category? category) {
  return category?.icon;
}

Color _categoryColor(String? rawColor) {
  if (rawColor == null || rawColor.isEmpty) {
    return Colors.blueGrey;
  }
  final hex = rawColor.replaceFirst('#', '');
  if (hex.length != 6) {
    return Colors.blueGrey;
  }
  return Color(int.parse('FF$hex', radix: 16));
}

List<double> _buildNetWorthSeries({
  required double currentNetWorth,
  required DateTime startDate,
  required List<Transaction> transactions,
}) {
  final impactByDay = <int, double>{};
  for (final txn in transactions) {
    final occurredDay = DateTime(
      txn.occurredAt.year,
      txn.occurredAt.month,
      txn.occurredAt.day,
    );
    final index = occurredDay.difference(startDate).inDays;
    if (index < 0 || index > 29) {
      continue;
    }
    impactByDay[index] = (impactByDay[index] ?? 0) + _netWorthImpact(txn);
  }

  final totalImpact = impactByDay.values.fold<double>(
    0,
    (sum, value) => sum + value,
  );
  var runningNetWorth = currentNetWorth - totalImpact;
  final series = <double>[];

  for (var i = 0; i < 30; i++) {
    runningNetWorth += impactByDay[i] ?? 0;
    series.add(runningNetWorth);
  }

  return series;
}

double _netWorthImpact(Transaction txn) {
  switch (txn.direction) {
    case 'income':
      return txn.amount;
    case 'expense':
      return -txn.amount;
    default:
      return 0;
  }
}

List<DashboardInsight> _buildInsights({
  required bool aiEnabled,
  required List<DashboardSpendingSlice> spending,
  required double monthlyIncome,
  required double safeToSpend,
  required List<DashboardBudgetSummary> budgets,
}) {
  if (!aiEnabled) {
    return const [];
  }

  final insights = <DashboardInsight>[];
  if (spending.isNotEmpty) {
    final topSlice = spending.first;
    insights.add(
      DashboardInsight(
        id: 'top-category',
        title: '${topSlice.name} is leading this month',
        body:
            '${(topSlice.percentage * 100).round()}% of your spending is in ${topSlice.name.toLowerCase()}.',
      ),
    );
  }

  final nearestLimit =
      budgets.where((budget) => budget.progress >= 0.8).toList()
        ..sort((a, b) => b.progress.compareTo(a.progress));
  if (nearestLimit.isNotEmpty) {
    final budget = nearestLimit.first;
    insights.add(
      DashboardInsight(
        id: 'budget-watch',
        title: '${budget.name} is close to the limit',
        body:
            'You have ${(budget.progress * 100).round()}% of the ${budget.name.toLowerCase()} budget used.',
      ),
    );
  } else if (monthlyIncome > 0) {
    final remainingShare = safeToSpend / monthlyIncome;
    final remainingPercent = (remainingShare * 100).clamp(0.0, 999.0);
    insights.add(
      DashboardInsight(
        id: 'safe-to-spend',
        title: 'You still have room this month',
        body:
            '${remainingPercent.round()}% of this month\'s income is still safe to spend.',
      ),
    );
  }

  return insights.take(2).toList();
}

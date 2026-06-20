import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../../data/repositories/transaction_repo.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/entities/recurring_template.dart';
import '../../domain/entities/transaction.dart';
import 'repo_providers.dart';

class DashboardData {
  final String greeting;
  final double safeToSpend;
  final double netWorth;
  final List<Account> accounts;
  final List<Budget> budgets;
  final List<Transaction> recentTransactions;
  final List<RecurringTemplate> upcomingRecurring;
  final Map<String, double> spendingByCategory;
  final bool isLoading;

  const DashboardData({
    required this.greeting,
    required this.safeToSpend,
    required this.netWorth,
    required this.accounts,
    required this.budgets,
    required this.recentTransactions,
    required this.upcomingRecurring,
    required this.spendingByCategory,
    this.isLoading = false,
  });

  static DashboardData loading() => const DashboardData(
        greeting: '',
        safeToSpend: 0,
        netWorth: 0,
        accounts: [],
        budgets: [],
        recentTransactions: [],
        upcomingRecurring: [],
        spendingByCategory: {},
        isLoading: true,
      );
}

final recentTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final repo = ref.watch(transactionRepoProvider);
  final now = DateTime.now();
  final from = now.subtract(const Duration(days: 30));

  return repo
      .watchFiltered(TransactionRepoFilters(from: from, to: now))
      .map((rows) {
    final sorted = rows
        .where((r) => r.deletedAt == null)
        .map((r) => r.toEntity())
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return sorted.take(10).toList();
  });
});

final dashboardProvider = StreamProvider<DashboardData>((ref) {
  final accountRepo = ref.watch(accountRepoProvider);
  final budgetRepo = ref.watch(budgetRepoProvider);
  final txnRepo = ref.watch(transactionRepoProvider);
  final recurringRepo = ref.watch(recurringRepoProvider);

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month);

  final hour = now.hour;
  final greeting = hour < 12
      ? 'Good morning'
      : hour < 17
          ? 'Good afternoon'
          : 'Good evening';

  final accountsStream = accountRepo
      .watchAll()
      .map((rows) => rows.map((r) => r.toEntity()).toList());

  final budgetsStream = budgetRepo
      .watchAll(month: now.month, year: now.year)
      .asyncMap((rows) async {
    final list = <Budget>[];
    for (final row in rows) {
      final entity = row.toEntity();
      final spentStream = budgetRepo.watchSpentForBudget(entity.id);
      final spent = await spentStream.first;
      list.add(entity.copyWith(spent: spent));
    }
    return list;
  });

  final recurringStream = recurringRepo.watchAll().map((rows) {
    final list = rows.map((r) => r.toEntity()).toList();
    list.sort((a, b) {
      if (a.nextOccurrenceAt == null && b.nextOccurrenceAt == null) return 0;
      if (a.nextOccurrenceAt == null) return 1;
      if (b.nextOccurrenceAt == null) return -1;
      return a.nextOccurrenceAt!.compareTo(b.nextOccurrenceAt!);
    });
    return list;
  });

  final txnStream = txnRepo
      .watchFiltered(TransactionRepoFilters(
          from: now.subtract(const Duration(days: 30)), to: now))
      .map((rows) {
    final sorted = rows
        .where((r) => r.deletedAt == null)
        .map((r) => r.toEntity())
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return sorted.take(10).toList();
  });

  final spendingStream = txnRepo
      .watchFiltered(TransactionRepoFilters(from: monthStart, to: now))
      .map((rows) {
    final spending = <String, double>{};
    for (final txn in rows) {
      if (txn.transactionDirection == 'expense' &&
          txn.categoryId != null &&
          txn.deletedAt == null) {
        spending[txn.categoryId!] =
            (spending[txn.categoryId!] ?? 0) + txn.amount;
      }
    }
    return spending;
  });

  return Rx.combineLatest5(
    accountsStream,
    budgetsStream,
    txnStream,
    recurringStream,
    spendingStream,
    (accs, buds, txns, recs, spending) {
      final now = DateTime.now();
      double committedExpenses = 0;
      double totalAssetBalance = 0;
      double totalLiabilityBalance = 0;

      for (final acc in accs) {
        if (acc.accountType == 'credit_card' ||
            acc.accountType == 'loan' ||
            acc.accountType == 'bnpl') {
          totalLiabilityBalance += acc.balance.abs();
        } else {
          totalAssetBalance += acc.balance;
        }
      }

      committedExpenses += buds.fold(0.0, (sum, b) => sum + b.amount);
      committedExpenses += recs
          .where((r) =>
              r.nextOccurrenceAt != null &&
              !r.nextOccurrenceAt!.isAfter(now.add(const Duration(days: 30))) &&
              !r.autoCreateDisabled)
          .fold(0.0, (sum, r) => sum + r.amount);

      return DashboardData(
        greeting: greeting,
        safeToSpend: totalAssetBalance - committedExpenses - totalLiabilityBalance,
        netWorth: totalAssetBalance - totalLiabilityBalance,
        accounts: accs,
        budgets: buds,
        recentTransactions: txns,
        upcomingRecurring: recs,
        spendingByCategory: spending,
      );
    },
  );
});

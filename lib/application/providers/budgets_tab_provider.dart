import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../../core/extensions/async_value_x.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/value_objects/exact_money.dart';
import 'repo_providers.dart';

bool isPastBudgetPeriod(int month, int year) {
  final now = DateTime.now();
  return year < now.year || (year == now.year && month < now.month);
}

class BudgetMonthNotifier extends Notifier<int> {
  @override
  int build() => DateTime.now().month;

  void goTo(int month) => state = month;
}

class BudgetYearNotifier extends Notifier<int> {
  @override
  int build() => DateTime.now().year;

  void goTo(int year) => state = year;
}

final budgetMonthProvider = NotifierProvider<BudgetMonthNotifier, int>(
  BudgetMonthNotifier.new,
);

final budgetYearProvider = NotifierProvider<BudgetYearNotifier, int>(
  BudgetYearNotifier.new,
);

final budgetsTabProvider = StreamProvider<List<Budget>>((ref) {
  final budgetRepo = ref.watch(budgetRepoProvider);
  final month = ref.watch(budgetMonthProvider);
  final year = ref.watch(budgetYearProvider);

  return budgetRepo.watchAll(month: month, year: year).switchMap((rows) {
    final budgets = rows.map((row) => row.toEntity()).toList();
    if (budgets.isEmpty) return Stream.value(<Budget>[]);

    return Rx.combineLatestList<ExactMoney>(
      budgets.map((budget) => budgetRepo.watchExactSpentForBudget(budget.id)),
    ).map((spentValues) {
      return [
        for (var i = 0; i < budgets.length; i++)
          budgets[i].copyWith(
            spent: spentValues[i].toDouble(),
            exactSpent: () => spentValues[i],
          ),
      ];
    });
  });
});

final budgetSummaryProvider = Provider<({double spent, double budgeted})>((
  ref,
) {
  final budgets = ref.watch(budgetsTabProvider).valueOrNull ?? [];
  if (budgets.isEmpty) return (spent: 0, budgeted: 0);
  final currency = budgets.first.exactAmount.currencyCode;
  ExactMoney? totalBudgeted;
  ExactMoney? totalSpent;
  for (final budget in budgets) {
    if (budget.exactAmount.currencyCode != currency) continue;
    final spent = budget.exactSpent;
    if (spent == null || spent.currencyCode != currency) continue;
    totalBudgeted = totalBudgeted == null
        ? budget.exactAmount
        : totalBudgeted + budget.exactAmount;
    totalSpent = totalSpent == null ? spent : totalSpent + spent;
  }
  return (
    spent: totalSpent?.toDouble() ?? 0,
    budgeted: totalBudgeted?.toDouble() ?? 0,
  );
});

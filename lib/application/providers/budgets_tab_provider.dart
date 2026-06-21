import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../../core/extensions/async_value_x.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/mappers.dart';
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

    return Rx.combineLatestList<double>(
      budgets.map((budget) => budgetRepo.watchSpentForBudget(budget.id)),
    ).map((spentValues) {
      return [
        for (var i = 0; i < budgets.length; i++)
          budgets[i].copyWith(spent: spentValues[i]),
      ];
    });
  });
});

final budgetSummaryProvider = Provider<({double spent, double budgeted})>((
  ref,
) {
  final budgets = ref.watch(budgetsTabProvider).valueOrNull ?? [];
  double totalBudgeted = 0;
  double totalSpent = 0;
  for (final b in budgets) {
    totalBudgeted += b.amount;
    totalSpent += b.spent;
  }
  return (spent: totalSpent, budgeted: totalBudgeted);
});

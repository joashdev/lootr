import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../../core/extensions/async_value_x.dart';
import '../../data/repositories/composite_budget_repo.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/value_objects/exact_money.dart';
import '../../domain/value_objects/period_context.dart';
import 'budget_projection.dart';
import 'period_context_provider.dart';
import 'repo_providers.dart';

bool isPastBudgetPeriod(int month, int year) {
  final now = DateTime.now();
  return year < now.year || (year == now.year && month < now.month);
}

class BudgetMonthNotifier extends Notifier<int> {
  @override
  int build() => ref.watch(periodContextProvider).startsAt.month;

  void goTo(int month) {
    final period = ref.read(periodContextProvider);
    ref
        .read(periodContextProvider.notifier)
        .selectMonth(DateTime(period.startsAt.year, month));
  }
}

class BudgetYearNotifier extends Notifier<int> {
  @override
  int build() => ref.watch(periodContextProvider).startsAt.year;

  void goTo(int year) {
    final period = ref.read(periodContextProvider);
    ref
        .read(periodContextProvider.notifier)
        .selectMonth(DateTime(year, period.startsAt.month));
  }
}

final budgetMonthProvider = NotifierProvider<BudgetMonthNotifier, int>(
  BudgetMonthNotifier.new,
);

final budgetYearProvider = NotifierProvider<BudgetYearNotifier, int>(
  BudgetYearNotifier.new,
);

final budgetsTabProvider = StreamProvider<List<BudgetOverview>>((ref) {
  final budgetRepo = ref.watch(budgetRepoProvider);
  final compositeBudgetRepo = ref.watch(compositeBudgetRepoProvider);
  final period = ref.watch(periodContextProvider);
  final month = period.startsAt.month;
  final year = period.startsAt.year;
  final anchor = period.kind == PeriodContextKind.calendarMonth
      ? period.startsAt
      : period.startsAt.add(
          Duration(
            microseconds:
                period.endsAt.difference(period.startsAt).inMicroseconds ~/ 2,
          ),
        );

  final legacyStream = budgetRepo.watchAll(month: month, year: year).switchMap((
    rows,
  ) {
    final budgets = rows.map((row) => row.toEntity()).toList();
    if (budgets.isEmpty) return Stream.value(<BudgetOverview>[]);

    return Rx.combineLatestList<ExactMoney>(
      budgets.map((budget) => budgetRepo.watchExactSpentForBudget(budget.id)),
    ).map((spentValues) {
      return [
        for (var i = 0; i < budgets.length; i++)
          BudgetOverview(
            id: budgets[i].id,
            name: 'Budget',
            categoryId: budgets[i].categoryId,
            budgeted: budgets[i].exactAmount,
            spent: spentValues[i],
            startsAt: DateTime(year, month),
            endsAt: month == 12
                ? DateTime(year + 1)
                : DateTime(year, month + 1),
            isImported: false,
            isReadOnly: isPastBudgetPeriod(month, year),
            needsReview: false,
            missingReferenceCount: 0,
            legacyBudget: budgets[i].copyWith(
              spent: spentValues[i].toDouble(),
              exactSpent: () => spentValues[i],
            ),
          ),
      ];
    });
  });

  final compositeStream = compositeBudgetRepo.watchForPeriod(anchor).map((
    snapshots,
  ) {
    return snapshots.map(compositeBudgetOverview).toList();
  });

  return Rx.combineLatest2(
    legacyStream,
    compositeStream,
    (List<BudgetOverview> legacy, List<BudgetOverview> imported) => [
      ...legacy,
      ...imported,
    ],
  );
});

final budgetSummaryProvider = Provider<List<BudgetSummaryPartition>>((ref) {
  final budgets = ref.watch(budgetsTabProvider).valueOrNull ?? [];
  final budgeted = <String, ExactMoney>{};
  final spent = <String, ExactMoney>{};
  for (final budget in budgets) {
    budgeted.update(
      budget.currencyCode,
      (current) => current + budget.budgeted,
      ifAbsent: () => budget.budgeted,
    );
    spent.update(
      budget.currencyCode,
      (current) => current + budget.spent,
      ifAbsent: () => budget.spent,
    );
  }
  final currencies = budgeted.keys.toList()..sort();
  return [
    for (final currency in currencies)
      BudgetSummaryPartition(
        currencyCode: currency,
        budgeted: budgeted[currency]!,
        spent: spent[currency]!,
      ),
  ];
});

BudgetOverview compositeBudgetOverview(CompositeBudgetSnapshot snapshot) {
  final evaluation = snapshot.evaluation;
  final definition = evaluation.budget;
  final needsReview =
      definition.reviewState != 'ready' || snapshot.review.needsReview;
  return BudgetOverview(
    id: definition.id,
    name: definition.name?.trim().isNotEmpty == true
        ? definition.name!.trim()
        : 'Imported budget',
    budgeted: evaluation.limit,
    spent: evaluation.trackedTotal,
    startsAt: evaluation.period.startsAt,
    endsAt: evaluation.period.endsAt,
    isImported: definition.isReadOnly,
    isReadOnly: definition.isReadOnly,
    isComposite: true,
    needsReview: needsReview,
    missingReferenceCount: snapshot.review.missingReferenceCount,
  );
}

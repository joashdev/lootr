import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/mappers.dart';
import 'repo_providers.dart';

final budgetsTabProvider = StreamProvider<List<Budget>>((ref) {
  final budgetRepo = ref.watch(budgetRepoProvider);

  final now = DateTime.now();
  return budgetRepo.watchAll(month: now.month, year: now.year).asyncMap(
    (rows) async {
      final budgets = <Budget>[];
      for (final row in rows) {
        final entity = row.toEntity();
        final spentStream = budgetRepo.watchSpentForBudget(entity.id);
        final spent = await spentStream.first;
        budgets.add(entity.copyWith(spent: spent));
      }
      return budgets;
    },
  );
});

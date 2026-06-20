import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/value_objects/field_types.dart';
import 'repo_providers.dart';

final safeToSpendProvider = StreamProvider<double>((ref) {
  final accountRepo = ref.watch(accountRepoProvider);
  final budgetRepo = ref.watch(budgetRepoProvider);
  final recurringRepo = ref.watch(recurringRepoProvider);

  return accountRepo.watchAll().asyncMap((accounts) async {
    double committedExpenses = 0;

    for (final acc in accounts) {
      if (acc.accountType == AccountType.creditCard ||
          acc.accountType == AccountType.loan ||
          acc.accountType == AccountType.bnpl) {
        committedExpenses += acc.balance.abs();
      }
    }

    final now = DateTime.now();
    final budgets =
        await budgetRepo.watchAll(month: now.month, year: now.year).first;
    for (final budget in budgets) {
      committedExpenses += budget.amount;
    }

    final recurrings = await recurringRepo.watchAll().first;
    for (final rec in recurrings) {
      if (rec.nextOccurrenceAt != null &&
          !rec.nextOccurrenceAt!
              .isAfter(now.add(const Duration(days: 30))) &&
          !rec.autoCreateDisabled) {
        committedExpenses += rec.amount;
      }
    }

    final totalIncome = accounts
        .where((a) =>
            a.accountType == AccountType.cash ||
            a.accountType == AccountType.bank ||
            a.accountType == AccountType.ewallet ||
            a.accountType == AccountType.savings)
        .fold(0.0, (sum, a) => sum + a.balance);

    return totalIncome - committedExpenses;
  });
});

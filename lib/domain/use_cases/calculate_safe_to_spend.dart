import '../entities/account.dart';
import '../entities/budget.dart';
import '../entities/recurring_template.dart';
import '../value_objects/exact_money.dart';
import '../value_objects/field_types.dart';

/// Which data the safe-to-spend figure was derived from, so the UI can
/// describe the number honestly instead of always claiming an income basis.
enum SafeToSpendBasis {
  /// Income was received this month; the figure is income-driven.
  monthlyIncome,

  /// No income recorded this month; the figure falls back to liquid
  /// account balances minus upcoming commitments.
  liquidBalances,
}

/// Outcome of [CalculateSafeToSpend]. [amount] is intentionally left
/// unclamped — a negative value is the over-committed state and the UI
/// renders it distinctly (danger color) rather than hiding it.
class SafeToSpendResult {
  const SafeToSpendResult({
    required this.amount,
    required this.basis,
    required this.monthlyIncome,
    required this.spentThisMonth,
    required this.committedOutflows,
    required this.liquidBalance,
  });

  /// Money still safe to spend. Negative when commitments exceed the basis.
  final double amount;

  /// Which formula produced [amount] — drives the explanatory copy.
  final SafeToSpendBasis basis;

  /// Income received this month (sum of income transactions).
  final double monthlyIncome;

  /// Expenses already spent this month (sum of expense transactions).
  final double spentThisMonth;

  /// Remaining committed outflows: unpaid recurring items due before month
  /// end (excluding ones whose category already has a budget), plus unspent
  /// budget headroom. On the [SafeToSpendBasis.liquidBalances] basis this
  /// also includes near-term debt balances (credit card / BNPL).
  final double committedOutflows;

  /// Sum of spendable balances (cash, bank, e-wallet, savings). Only the
  /// denominator on the fallback basis, but always populated.
  final double liquidBalance;

  bool get isOverCommitted => amount < 0;
}

/// Computes the dashboard "Safe to spend" hero figure.
///
/// Primary basis — income received this month ([SafeToSpendBasis.monthlyIncome],
/// used when `monthlyIncome > 0`):
///
///     safeToSpend = income received this month
///                 − expenses already spent this month
///                 − remaining committed outflows
///
/// where remaining committed outflows =
///   * unspent budget headroom: Σ max(0, budget.amount − budget.spent) for
///     this month's budgets (spend already inside budgets is counted once,
///     via `spentThisMonth`, never again via the budget amount), plus
///   * recurring items due before month end whose category is NOT already
///     budgeted (budgeted categories are covered by the headroom term, so
///     counting their recurring bills too would double-count).
///
/// Fallback basis — liquid balances ([SafeToSpendBasis.liquidBalances], used
/// when no income was recorded this month):
///
///     safeToSpend = liquid account balances (cash, bank, e-wallet, savings)
///                 − near-term debt owed (credit card + BNPL balances)
///                 − remaining committed outflows (same definition as above)
///
/// Long-term loan principal is excluded from the fallback — its monthly
/// installment is expected to appear as a recurring item instead. Recurring
/// templates with an overdue `nextOccurrenceAt` still count: the bill remains
/// unpaid. The result is never clamped; negative means over-committed.
class CalculateSafeToSpend {
  const CalculateSafeToSpend();

  static const _liquidTypes = {
    AccountType.cash,
    AccountType.bank,
    AccountType.ewallet,
    AccountType.savings,
  };

  static const _nearTermDebtTypes = {AccountType.creditCard, AccountType.bnpl};

  SafeToSpendResult call({
    required List<Account> accounts,
    required List<Budget> budgets,
    required List<RecurringTemplate> recurringTemplates,
    required double monthlyIncome,
    required double monthlyExpense,
    required DateTime now,
    String currencyCode = 'PHP',
    ExactMoney? exactMonthlyIncome,
    ExactMoney? exactMonthlyExpense,
  }) {
    final monthEndExclusive = DateTime(now.year, now.month + 1);
    final income =
        exactMonthlyIncome ??
        ExactMoney.parse(monthlyIncome.toStringAsFixed(2), currencyCode);
    final expense =
        exactMonthlyExpense ??
        ExactMoney.parse(monthlyExpense.toStringAsFixed(2), currencyCode);
    var zero = ExactMoney(
      coefficient: BigInt.zero,
      scale: income.scale > expense.scale ? income.scale : expense.scale,
      currencyCode: currencyCode,
    );

    final activeBudgets = budgets
        .where(
          (budget) =>
              budget.deletedAt == null &&
              budget.exactAmount.currencyCode == currencyCode,
        )
        .toList();
    final budgetedCategoryIds = activeBudgets
        .map((budget) => budget.categoryId)
        .toSet();

    var budgetHeadroom = zero;
    for (final budget in activeBudgets) {
      final spent =
          budget.exactSpent ??
          ExactMoney.parse(
            budget.spent.toStringAsFixed(budget.exactAmount.scale),
            currencyCode,
          );
      final headroom = budget.exactAmount - spent;
      if (!headroom.isNegative) {
        budgetHeadroom += headroom;
      }
    }

    var unbudgetedRecurringDue = zero;
    for (final template in recurringTemplates) {
      if (template.deletedAt != null ||
          template.autoCreateDisabled ||
          template.nextOccurrenceAt == null ||
          !template.nextOccurrenceAt!.isBefore(monthEndExclusive) ||
          template.exactAmount.currencyCode != currencyCode ||
          (template.categoryId != null &&
              budgetedCategoryIds.contains(template.categoryId))) {
        continue;
      }
      unbudgetedRecurringDue += template.exactAmount;
    }

    var committedOutflows = budgetHeadroom + unbudgetedRecurringDue;

    final activeAccounts = accounts.where(
      (account) =>
          !account.isArchived && !account.isHidden && account.deletedAt == null,
    );
    var liquidBalance = zero;
    var nearTermDebt = zero;
    for (final account in activeAccounts) {
      if (account.currencyCode != currencyCode) continue;
      if (_liquidTypes.contains(account.accountType)) {
        liquidBalance += account.exactBalance;
      } else if (_nearTermDebtTypes.contains(account.accountType)) {
        nearTermDebt += account.exactBalance.abs();
      }
    }

    final ExactMoney amount;
    final SafeToSpendBasis basis;
    if (income.coefficient > BigInt.zero) {
      basis = SafeToSpendBasis.monthlyIncome;
      amount = income - expense - committedOutflows;
    } else {
      basis = SafeToSpendBasis.liquidBalances;
      committedOutflows += nearTermDebt;
      amount = liquidBalance - committedOutflows;
    }

    return SafeToSpendResult(
      amount: amount.toDouble(),
      basis: basis,
      monthlyIncome: income.toDouble(),
      spentThisMonth: expense.toDouble(),
      committedOutflows: committedOutflows.toDouble(),
      liquidBalance: liquidBalance.toDouble(),
    );
  }
}

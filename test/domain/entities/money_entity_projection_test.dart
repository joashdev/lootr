import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/domain/entities/account.dart';
import 'package:lootr/domain/entities/budget.dart';
import 'package:lootr/domain/entities/debt_record.dart';
import 'package:lootr/domain/entities/goal.dart';
import 'package:lootr/domain/value_objects/exact_money.dart';

void main() {
  final now = DateTime(2026, 7, 22);

  test('account exposes its exact balance at the configured precision', () {
    final account = Account(
      id: 'account-1',
      ownerUserId: 'owner-1',
      name: 'Account',
      accountType: 'bank',
      balance: 0.000000000001,
      balanceAtoms: '1',
      currencyPrecision: 12,
      currencyCode: 'BTC',
      isArchived: false,
      isHidden: false,
      createdAt: now,
      updatedAt: now,
    );

    expect(account.exactBalance.toDecimalString(), '0.000000000001');
    expect(account.exactBalance.currencyCode, 'BTC');
  });

  test('goal exposes exact target and current values', () {
    final goal = Goal(
      id: 'goal-1',
      ownerUserId: 'owner-1',
      name: 'Goal',
      goalType: 'custom',
      targetAmount: 1.2345,
      currentAmount: 0.0001,
      targetAmountAtoms: '12345',
      currentAmountAtoms: '1',
      amountScale: 4,
      currencyCode: 'USD',
      createdAt: now,
      updatedAt: now,
    );

    expect(goal.exactTargetAmount.toDecimalString(), '1.2345');
    expect(goal.exactCurrentAmount.toDecimalString(), '0.0001');
    expect(goal.exactTargetAmount.currencyCode, 'USD');
  });

  test('debt exposes exact total and remaining values', () {
    final debt = DebtRecord(
      id: 'debt-1',
      ownerUserId: 'owner-1',
      counterpartyName: 'Counterparty',
      debtDirection: 'borrowed',
      amount: 1,
      remainingBalance: 0.000000000001,
      amountAtoms: '1000000000000',
      remainingBalanceAtoms: '1',
      amountScale: 12,
      currencyCode: 'BTC',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );

    expect(debt.exactAmount.toDecimalString(), '1.000000000000');
    expect(debt.exactRemainingBalance.toDecimalString(), '0.000000000001');
    expect(debt.exactAmount.currencyCode, 'BTC');
  });

  test('budget prefers exact computed spending over a double projection', () {
    final budget = Budget(
      id: 'budget-1',
      ownerUserId: 'owner-1',
      categoryId: 'category-1',
      amount: 1,
      amountAtoms: '10000',
      amountScale: 4,
      currencyCode: 'EUR',
      month: 7,
      year: 2026,
      spent: 999,
      exactSpent: ExactMoney.parse('0.0001', 'EUR'),
      createdAt: now,
      updatedAt: now,
    );

    expect(budget.exactSpentAmount.toDecimalString(), '0.0001');
  });
}

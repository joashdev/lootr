import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/domain/entities/account.dart';
import 'package:lootr/domain/entities/budget.dart';
import 'package:lootr/domain/entities/recurring_template.dart';
import 'package:lootr/domain/use_cases/calculate_safe_to_spend.dart';

void main() {
  const calculator = CalculateSafeToSpend();
  final now = DateTime(2026, 7, 15);

  Account account({
    String id = 'acc-1',
    String accountType = 'bank',
    double balance = 0,
    bool isArchived = false,
    bool isHidden = false,
    DateTime? deletedAt,
  }) {
    return Account(
      id: id,
      ownerUserId: 'usr-1',
      name: id,
      accountType: accountType,
      balance: balance,
      currencyCode: 'PHP',
      isArchived: isArchived,
      isHidden: isHidden,
      createdAt: now,
      updatedAt: now,
      deletedAt: deletedAt,
    );
  }

  Budget budget({
    String id = 'bud-1',
    String categoryId = 'cat-1',
    double amount = 0,
    double spent = 0,
    DateTime? deletedAt,
  }) {
    return Budget(
      id: id,
      ownerUserId: 'usr-1',
      categoryId: categoryId,
      amount: amount,
      month: now.month,
      year: now.year,
      spent: spent,
      createdAt: now,
      updatedAt: now,
      deletedAt: deletedAt,
    );
  }

  RecurringTemplate recurring({
    String id = 'rec-1',
    String? categoryId,
    double amount = 0,
    DateTime? nextOccurrenceAt,
    bool autoCreateDisabled = false,
    DateTime? deletedAt,
  }) {
    return RecurringTemplate(
      id: id,
      accountId: 'acc-1',
      categoryId: categoryId,
      amount: amount,
      recurrenceRule: 'FREQ=MONTHLY',
      autoCreateDisabled: autoCreateDisabled,
      nextOccurrenceAt: nextOccurrenceAt,
      createdAt: now,
      updatedAt: now,
      deletedAt: deletedAt,
    );
  }

  group('CalculateSafeToSpend', () {
    test('normal month uses income basis: income − spent − committed', () {
      final result = calculator(
        accounts: [account(balance: 120000)],
        budgets: [
          // ₱8,000 budgeted, ₱2,500 already spent → ₱5,500 headroom.
          budget(amount: 8000, spent: 2500),
        ],
        recurringTemplates: [
          // Unbudgeted category, due before month end → committed.
          recurring(
            id: 'rec-rent',
            categoryId: 'cat-rent',
            amount: 10000,
            nextOccurrenceAt: DateTime(2026, 7, 28),
          ),
          // Same category as the budget → covered by headroom, not re-counted.
          recurring(
            id: 'rec-dining',
            categoryId: 'cat-1',
            amount: 1500,
            nextOccurrenceAt: DateTime(2026, 7, 20),
          ),
          // Due next month → not committed this month.
          recurring(
            id: 'rec-later',
            categoryId: 'cat-sub',
            amount: 999,
            nextOccurrenceAt: DateTime(2026, 8, 2),
          ),
        ],
        monthlyIncome: 50000,
        monthlyExpense: 12000,
        now: now,
      );

      expect(result.basis, SafeToSpendBasis.monthlyIncome);
      // 50,000 − 12,000 − (5,500 headroom + 10,000 rent) = 22,500.
      expect(result.amount, 22500);
      expect(result.committedOutflows, 15500);
      expect(result.spentThisMonth, 12000);
      expect(result.isOverCommitted, isFalse);
    });

    test('overspent budget contributes zero headroom, never a credit', () {
      final result = calculator(
        accounts: const [],
        budgets: [budget(amount: 5000, spent: 7500)],
        recurringTemplates: const [],
        monthlyIncome: 30000,
        monthlyExpense: 7500,
        now: now,
      );

      // Headroom clamps at 0: 30,000 − 7,500 − 0 = 22,500.
      expect(result.amount, 22500);
      expect(result.committedOutflows, 0);
    });

    test(
      'zero income falls back to liquid balances minus commitments',
      () {
        final result = calculator(
          accounts: [
            account(id: 'bank', accountType: 'bank', balance: 40000),
            account(id: 'wallet', accountType: 'ewallet', balance: 5000),
            // Near-term debt is committed on this basis.
            account(id: 'cc', accountType: 'credit_card', balance: -6000),
            // Long-term loan principal excluded.
            account(id: 'loan', accountType: 'loan', balance: -200000),
            // Non-liquid assets excluded.
            account(id: 'stocks', accountType: 'investment', balance: 99999),
            // Archived/hidden/deleted accounts ignored.
            account(id: 'old', balance: 77777, isArchived: true),
            account(id: 'gone', balance: 88888, deletedAt: now),
          ],
          budgets: [budget(amount: 8000, spent: 3000)],
          recurringTemplates: [
            recurring(
              id: 'rec-net',
              categoryId: 'cat-net',
              amount: 1699,
              nextOccurrenceAt: DateTime(2026, 7, 25),
            ),
          ],
          monthlyIncome: 0,
          monthlyExpense: 3000,
          now: now,
        );

        expect(result.basis, SafeToSpendBasis.liquidBalances);
        expect(result.liquidBalance, 45000);
        // Committed: 5,000 headroom + 1,699 recurring + 6,000 credit card.
        expect(result.committedOutflows, 12699);
        // 45,000 − 12,699 = 32,301.
        expect(result.amount, 32301);
        expect(result.isOverCommitted, isFalse);
      },
    );

    test('over-committed month yields a negative, unclamped amount', () {
      final result = calculator(
        accounts: [account(balance: 1000)],
        budgets: [budget(amount: 20000, spent: 0)],
        recurringTemplates: [
          recurring(
            id: 'rec-rent',
            categoryId: 'cat-rent',
            amount: 15000,
            nextOccurrenceAt: DateTime(2026, 7, 30),
          ),
        ],
        monthlyIncome: 25000,
        monthlyExpense: 18000,
        now: now,
      );

      // 25,000 − 18,000 − (20,000 + 15,000) = −28,000.
      expect(result.basis, SafeToSpendBasis.monthlyIncome);
      expect(result.amount, -28000);
      expect(result.isOverCommitted, isTrue);
    });

    test('ignores disabled, deleted, and unscheduled recurring templates', () {
      final result = calculator(
        accounts: const [],
        budgets: const [],
        recurringTemplates: [
          recurring(
            id: 'rec-disabled',
            amount: 500,
            nextOccurrenceAt: DateTime(2026, 7, 20),
            autoCreateDisabled: true,
          ),
          recurring(
            id: 'rec-deleted',
            amount: 500,
            nextOccurrenceAt: DateTime(2026, 7, 20),
            deletedAt: now,
          ),
          recurring(id: 'rec-unscheduled', amount: 500),
          // Overdue bill still counts — it remains unpaid.
          recurring(
            id: 'rec-overdue',
            amount: 700,
            nextOccurrenceAt: DateTime(2026, 7, 10),
          ),
        ],
        monthlyIncome: 10000,
        monthlyExpense: 0,
        now: now,
      );

      expect(result.committedOutflows, 700);
      expect(result.amount, 9300);
    });
  });
}

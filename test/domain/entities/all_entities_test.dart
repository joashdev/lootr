import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/domain/entities/account.dart';
import 'package:lootr/domain/entities/budget.dart';
import 'package:lootr/domain/entities/category.dart';
import 'package:lootr/domain/entities/debt_record.dart';
import 'package:lootr/domain/entities/goal.dart';
import 'package:lootr/domain/entities/household.dart';
import 'package:lootr/domain/entities/household_member.dart';
import 'package:lootr/domain/entities/payee.dart';
import 'package:lootr/domain/entities/recurring_template.dart';
import 'package:lootr/domain/entities/transfer.dart';
import 'package:lootr/domain/entities/user.dart';

final now = DateTime(2026, 6, 19, 12, 0, 0);

void main() {
  group('Account', () {
    test('construction and equality', () {
      final a = Account(
        id: 'a1',
        ownerUserId: 'u1',
        name: 'Checking',
        accountType: 'bank',
        balance: 1000,
        currencyCode: 'PHP',
        isArchived: false,
        isHidden: false,
        createdAt: now,
        updatedAt: now,
      );
      final b = Account(
        id: 'a1',
        ownerUserId: 'u1',
        name: 'Checking',
        accountType: 'bank',
        balance: 1000,
        currencyCode: 'PHP',
        isArchived: false,
        isHidden: false,
        createdAt: now,
        updatedAt: now,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('JSON round-trip', () {
      final a = Account(
        id: 'a1',
        householdId: 'h1',
        ownerUserId: 'u1',
        name: 'Savings',
        accountType: 'savings',
        balance: 5000,
        currencyCode: 'USD',
        isArchived: true,
        isHidden: false,
        createdAt: now,
        updatedAt: now,
        deletedAt: now,
      );
      final json = a.toJson();
      final rebuilt = Account.fromJson(json);
      expect(rebuilt, equals(a));
    });

    test('copyWith nullable-to-null', () {
      final a = Account(
        id: 'a1',
        householdId: 'h1',
        ownerUserId: 'u1',
        name: 'Test',
        accountType: 'cash',
        balance: 0,
        currencyCode: 'PHP',
        isArchived: false,
        isHidden: false,
        createdAt: now,
        updatedAt: now,
      );
      final updated = a.copyWith(
        householdId: () => null,
        deletedAt: () => null,
      );
      expect(updated.householdId, isNull);
      expect(updated.deletedAt, isNull);
      expect(updated.name, a.name);
    });
  });

  group('Budget', () {
    test('construction and equality', () {
      final b = Budget(
        id: 'b1',
        ownerUserId: 'u1',
        categoryId: 'c1',
        amount: 5000,
        month: 6,
        year: 2026,
        spent: 1200,
        createdAt: now,
        updatedAt: now,
      );
      final b2 = Budget(
        id: 'b1',
        ownerUserId: 'u1',
        categoryId: 'c1',
        amount: 5000,
        month: 6,
        year: 2026,
        spent: 1200,
        createdAt: now,
        updatedAt: now,
      );
      expect(b, equals(b2));
    });

    test('JSON round-trip', () {
      final b = Budget(
        id: 'b1',
        ownerUserId: 'u1',
        categoryId: 'c1',
        amount: 5000,
        month: 6,
        year: 2026,
        spent: 1200,
        createdAt: now,
        updatedAt: now,
      );
      final rebuilt = Budget.fromJson(b.toJson());
      expect(rebuilt, equals(b));
    });
  });

  group('Category', () {
    test('construction and equality', () {
      final c = Category(
        id: 'c1',
        name: 'Groceries',
        icon: 'shopping-cart',
        color: '#FF0000',
        categoryGroup: 'expense',
        createdAt: now,
        updatedAt: now,
      );
      final c2 = Category(
        id: 'c1',
        name: 'Groceries',
        icon: 'shopping-cart',
        color: '#FF0000',
        categoryGroup: 'expense',
        createdAt: now,
        updatedAt: now,
      );
      expect(c, equals(c2));
    });

    test('JSON round-trip', () {
      final c = Category(
        id: 'c1',
        parentCategoryId: 'p1',
        name: 'Food',
        icon: 'utensils',
        color: '#00FF00',
        categoryGroup: 'expense',
        createdAt: now,
        updatedAt: now,
      );
      final rebuilt = Category.fromJson(c.toJson());
      expect(rebuilt, equals(c));
    });
  });

  group('DebtRecord', () {
    test('construction and equality', () {
      final d = DebtRecord(
        id: 'd1',
        ownerUserId: 'u1',
        counterpartyName: 'Alice',
        debtDirection: 'lent',
        amount: 1000,
        remainingBalance: 500,
        status: 'active',
        createdAt: now,
        updatedAt: now,
      );
      final d2 = DebtRecord(
        id: 'd1',
        ownerUserId: 'u1',
        counterpartyName: 'Alice',
        debtDirection: 'lent',
        amount: 1000,
        remainingBalance: 500,
        status: 'active',
        createdAt: now,
        updatedAt: now,
      );
      expect(d, equals(d2));
    });

    test('JSON round-trip', () {
      final d = DebtRecord(
        id: 'd1',
        ownerUserId: 'u1',
        counterpartyName: 'Bob',
        debtDirection: 'borrowed',
        amount: 2000,
        remainingBalance: 2000,
        note: 'For laptop',
        dueDate: DateTime(2026, 12, 31),
        status: 'active',
        createdAt: now,
        updatedAt: now,
        deletedAt: now,
      );
      final rebuilt = DebtRecord.fromJson(d.toJson());
      expect(rebuilt, equals(d));
    });
  });

  group('Goal', () {
    test('construction and equality', () {
      final g = Goal(
        id: 'g1',
        ownerUserId: 'u1',
        name: 'Emergency Fund',
        goalType: 'emergency_fund',
        targetAmount: 100000,
        currentAmount: 30000,
        progress: 0.3,
        createdAt: now,
        updatedAt: now,
      );
      final g2 = Goal(
        id: 'g1',
        ownerUserId: 'u1',
        name: 'Emergency Fund',
        goalType: 'emergency_fund',
        targetAmount: 100000,
        currentAmount: 30000,
        progress: 0.3,
        createdAt: now,
        updatedAt: now,
      );
      expect(g, equals(g2));
    });

    test('JSON round-trip', () {
      final g = Goal(
        id: 'g1',
        ownerUserId: 'u1',
        householdId: 'h1',
        name: 'Travel',
        goalType: 'travel',
        targetAmount: 50000,
        currentAmount: 10000,
        targetDate: DateTime(2026, 12, 31),
        progress: 0.2,
        createdAt: now,
        updatedAt: now,
      );
      final rebuilt = Goal.fromJson(g.toJson());
      expect(rebuilt, equals(g));
    });
  });

  group('Household', () {
    test('construction and equality', () {
      final h = Household(
        id: 'h1',
        name: 'Family',
        createdByUserId: 'u1',
        createdAt: now,
        updatedAt: now,
      );
      final h2 = Household(
        id: 'h1',
        name: 'Family',
        createdByUserId: 'u1',
        createdAt: now,
        updatedAt: now,
      );
      expect(h, equals(h2));
    });

    test('JSON round-trip', () {
      final h = Household(
        id: 'h1',
        name: 'Family',
        createdByUserId: 'u1',
        createdAt: now,
        updatedAt: now,
        deletedAt: now,
      );
      final rebuilt = Household.fromJson(h.toJson());
      expect(rebuilt, equals(h));
    });
  });

  group('HouseholdMember', () {
    test('construction and equality', () {
      final m = HouseholdMember(
        id: 'm1',
        householdId: 'h1',
        userId: 'u1',
        role: 'owner',
        createdAt: now,
        updatedAt: now,
      );
      final m2 = HouseholdMember(
        id: 'm1',
        householdId: 'h1',
        userId: 'u1',
        role: 'owner',
        createdAt: now,
        updatedAt: now,
      );
      expect(m, equals(m2));
    });

    test('JSON round-trip', () {
      final m = HouseholdMember(
        id: 'm1',
        householdId: 'h1',
        userId: 'u2',
        role: 'member',
        createdAt: now,
        updatedAt: now,
      );
      final rebuilt = HouseholdMember.fromJson(m.toJson());
      expect(rebuilt, equals(m));
    });
  });

  group('Payee', () {
    test('construction and equality', () {
      final p = Payee(
        id: 'p1',
        normalizedName: 'starbucks',
        displayName: 'Starbucks',
        createdAt: now,
        updatedAt: now,
      );
      final p2 = Payee(
        id: 'p1',
        normalizedName: 'starbucks',
        displayName: 'Starbucks',
        createdAt: now,
        updatedAt: now,
      );
      expect(p, equals(p2));
    });

    test('JSON round-trip', () {
      final p = Payee(
        id: 'p1',
        normalizedName: 'netflix',
        displayName: 'Netflix',
        logoUrl: 'https://logo.example/netflix.png',
        createdAt: now,
        updatedAt: now,
        deletedAt: now,
      );
      final rebuilt = Payee.fromJson(p.toJson());
      expect(rebuilt, equals(p));
    });
  });

  group('RecurringTemplate', () {
    test('construction and equality', () {
      final r = RecurringTemplate(
        id: 'r1',
        accountId: 'a1',
        amount: 500,
        recurrenceRule: 'FREQ=MONTHLY',
        createdAt: now,
        updatedAt: now,
      );
      final r2 = RecurringTemplate(
        id: 'r1',
        accountId: 'a1',
        amount: 500,
        recurrenceRule: 'FREQ=MONTHLY',
        createdAt: now,
        updatedAt: now,
      );
      expect(r, equals(r2));
    });

    test('JSON round-trip', () {
      final r = RecurringTemplate(
        id: 'r1',
        accountId: 'a1',
        categoryId: 'c1',
        payeeId: 'p1',
        amount: 1500,
        recurrenceRule: 'FREQ=WEEKLY',
        reminderEnabled: true,
        autoCreateDisabled: false,
        nextOccurrenceAt: DateTime(2026, 6, 26),
        createdAt: now,
        updatedAt: now,
        deletedAt: now,
      );
      final rebuilt = RecurringTemplate.fromJson(r.toJson());
      expect(rebuilt, equals(r));
    });
  });

  group('Transfer', () {
    test('construction and equality', () {
      final t = Transfer(
        id: 't1',
        sourceAccountId: 'a1',
        destinationAccountId: 'a2',
        amount: 1000,
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );
      final t2 = Transfer(
        id: 't1',
        sourceAccountId: 'a1',
        destinationAccountId: 'a2',
        amount: 1000,
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );
      expect(t, equals(t2));
    });

    test('JSON round-trip', () {
      final t = Transfer(
        id: 't1',
        sourceAccountId: 'a1',
        destinationAccountId: 'a2',
        amount: 5000,
        feeAmount: 25,
        note: 'Rent payment',
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
        deletedAt: now,
      );
      final rebuilt = Transfer.fromJson(t.toJson());
      expect(rebuilt, equals(t));
    });

    test('feeAmount defaults to 0', () {
      final t = Transfer(
        id: 't1',
        sourceAccountId: 'a1',
        destinationAccountId: 'a2',
        amount: 1000,
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );
      expect(t.feeAmount, 0);
    });
  });

  group('User', () {
    test('construction and equality', () {
      final u = User(
        id: 'u1',
        createdAt: now,
        updatedAt: now,
      );
      final u2 = User(
        id: 'u1',
        createdAt: now,
        updatedAt: now,
      );
      expect(u, equals(u2));
    });

    test('JSON round-trip with defaults', () {
      final u = User(
        id: 'u1',
        email: 'test@example.com',
        displayName: 'Test User',
        currencyCode: 'PHP',
        locale: 'en-PH',
        timezone: 'Asia/Manila',
        aiEnabled: false,
        createdAt: now,
        updatedAt: now,
      );
      final rebuilt = User.fromJson(u.toJson());
      expect(rebuilt, equals(u));
    });

    test('JSON round-trip missing optional keys uses defaults', () {
      final json = <String, dynamic>{
        'id': 'u1',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      final u = User.fromJson(json);
      expect(u.currencyCode, 'PHP');
      expect(u.aiEnabled, false);
    });
  });
}

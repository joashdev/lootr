// Maps between Drift DataClasses and domain entities.
//
// NOTE: This file imports `drift` and `app_database.dart` — a deliberate
// exception to the dependency rule. Mappers live alongside entities per
// the task spec. The domain ENTITIES themselves remain pure Dart.
//
// Sync fields (`syncStatus`, `lastSyncedAt`) are intentionally excluded
// from domain entities. The sync engine operates on repositories/companions,
// keeping domain objects free of transport-layer concerns.
//
// `Transfer.feeAmount` is nullable in the DB (with default 0) but
// non-nullable in the entity. The mapper coerces DB null to 0, which
// is safe since the DB default ensures the column is never legitimately null.

import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import 'account.dart';
import 'budget.dart';
import 'category.dart';
import 'debt_record.dart';
import 'goal.dart';
import 'household.dart';
import 'household_member.dart';
import 'payee.dart';
import 'recurring_template.dart';
import 'transaction.dart';
import 'transfer.dart';
import 'user.dart';

// ─── Transaction ───────────────────────────────────────────────────────────

extension TransactionDataMapper on TransactionData {
  Transaction toEntity() => Transaction(
        id: id,
        accountId: accountId,
        categoryId: categoryId,
        payeeId: payeeId,
        parentTransactionId: parentTransactionId,
        recurringTemplateId: recurringTemplateId,
        amount: amount,
        direction: transactionDirection,
        mode: transactionMode,
        subtype: transactionSubtype,
        note: note,
        metadata: metadata,
        occurredAt: occurredAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );
}

extension TransactionEntityMapper on Transaction {
  TransactionsCompanion toCompanion() => TransactionsCompanion.insert(
        id: id,
        accountId: accountId,
        categoryId: Value(categoryId),
        payeeId: Value(payeeId),
        parentTransactionId: Value(parentTransactionId),
        recurringTemplateId: Value(recurringTemplateId),
        amount: amount,
        transactionDirection: direction,
        transactionMode: mode,
        transactionSubtype: Value(subtype),
        note: Value(note),
        metadata: Value(metadata),
        occurredAt: occurredAt,
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
        syncStatus: const Value.absent(),
        lastSyncedAt: const Value.absent(),
      );

  TransactionsCompanion toUpdateCompanion() => TransactionsCompanion(
        id: Value(id),
        accountId: Value(accountId),
        categoryId: Value(categoryId),
        payeeId: Value(payeeId),
        parentTransactionId: Value(parentTransactionId),
        recurringTemplateId: Value(recurringTemplateId),
        amount: Value(amount),
        transactionDirection: Value(direction),
        transactionMode: Value(mode),
        transactionSubtype: Value(subtype),
        note: Value(note),
        metadata: Value(metadata),
        occurredAt: Value(occurredAt),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
      );
}

// ─── Account ───────────────────────────────────────────────────────────────

extension AccountDataMapper on AccountData {
  Account toEntity() => Account(
        id: id,
        householdId: householdId,
        ownerUserId: ownerUserId,
        name: name,
        accountType: accountType,
        balance: balance,
        currencyCode: currencyCode,
        isArchived: isArchived,
        isHidden: isHidden,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );
}

extension AccountEntityMapper on Account {
  AccountsCompanion toCompanion() => AccountsCompanion.insert(
        id: id,
        householdId: Value(householdId),
        ownerUserId: ownerUserId,
        name: name,
        accountType: accountType,
        balance: Value(balance),
        currencyCode: Value(currencyCode),
        isArchived: Value(isArchived),
        isHidden: Value(isHidden),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
        syncStatus: const Value.absent(),
        lastSyncedAt: const Value.absent(),
      );

  AccountsCompanion toUpdateCompanion() => AccountsCompanion(
        id: Value(id),
        householdId: Value(householdId),
        ownerUserId: Value(ownerUserId),
        name: Value(name),
        accountType: Value(accountType),
        balance: Value(balance),
        currencyCode: Value(currencyCode),
        isArchived: Value(isArchived),
        isHidden: Value(isHidden),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
      );
}

// ─── Budget ─────────────────────────────────────────────────────────────────

extension BudgetDataMapper on BudgetData {
  Budget toEntity() => Budget(
        id: id,
        householdId: householdId,
        ownerUserId: ownerUserId,
        categoryId: categoryId,
        amount: amount,
        month: month,
        year: year,
        icon: icon,
        color: color,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );
}

extension BudgetEntityMapper on Budget {
  BudgetsCompanion toCompanion() => BudgetsCompanion.insert(
        id: id,
        householdId: Value(householdId),
        ownerUserId: ownerUserId,
        categoryId: categoryId,
        amount: amount,
        month: month,
        year: year,
        icon: Value(icon),
        color: Value(color),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
        syncStatus: const Value.absent(),
        lastSyncedAt: const Value.absent(),
      );

  BudgetsCompanion toUpdateCompanion() => BudgetsCompanion(
        id: Value(id),
        householdId: Value(householdId),
        ownerUserId: Value(ownerUserId),
        categoryId: Value(categoryId),
        amount: Value(amount),
        month: Value(month),
        year: Value(year),
        icon: Value(icon),
        color: Value(color),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
      );
}

// ─── Category ───────────────────────────────────────────────────────────────

extension CategoryDataMapper on CategoryData {
  Category toEntity() => Category(
        id: id,
        parentCategoryId: parentCategoryId,
        name: name,
        icon: icon,
        color: color,
        categoryGroup: categoryGroup,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );
}

extension CategoryEntityMapper on Category {
  CategoriesCompanion toCompanion() => CategoriesCompanion.insert(
        id: id,
        parentCategoryId: Value(parentCategoryId),
        name: name,
        icon: Value(icon),
        color: Value(color),
        categoryGroup: categoryGroup,
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
        syncStatus: const Value.absent(),
        lastSyncedAt: const Value.absent(),
      );

  CategoriesCompanion toUpdateCompanion() => CategoriesCompanion(
        id: Value(id),
        parentCategoryId: Value(parentCategoryId),
        name: Value(name),
        icon: Value(icon),
        color: Value(color),
        categoryGroup: Value(categoryGroup),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
      );
}

// ─── Payee ──────────────────────────────────────────────────────────────────

extension PayeeDataMapper on PayeeData {
  Payee toEntity() => Payee(
        id: id,
        normalizedName: normalizedName,
        displayName: displayName,
        logoUrl: logoUrl,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );
}

extension PayeeEntityMapper on Payee {
  PayeesCompanion toCompanion() => PayeesCompanion.insert(
        id: id,
        normalizedName: normalizedName,
        displayName: Value(displayName),
        logoUrl: Value(logoUrl),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
        syncStatus: const Value.absent(),
        lastSyncedAt: const Value.absent(),
      );

  PayeesCompanion toUpdateCompanion() => PayeesCompanion(
        id: Value(id),
        normalizedName: Value(normalizedName),
        displayName: Value(displayName),
        logoUrl: Value(logoUrl),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
      );
}

// ─── Transfer ───────────────────────────────────────────────────────────────

extension TransferDataMapper on TransferData {
  Transfer toEntity() => Transfer(
        id: id,
        sourceAccountId: sourceAccountId,
        destinationAccountId: destinationAccountId,
        amount: amount,
        feeAmount: feeAmount ?? 0,
        note: note,
        occurredAt: occurredAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );
}

extension TransferEntityMapper on Transfer {
  TransfersCompanion toCompanion() => TransfersCompanion.insert(
        id: id,
        sourceAccountId: sourceAccountId,
        destinationAccountId: destinationAccountId,
        amount: amount,
        feeAmount: Value<double?>(feeAmount),
        note: Value(note),
        occurredAt: occurredAt,
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
        syncStatus: const Value.absent(),
        lastSyncedAt: const Value.absent(),
      );

  TransfersCompanion toUpdateCompanion() => TransfersCompanion(
        id: Value(id),
        sourceAccountId: Value(sourceAccountId),
        destinationAccountId: Value(destinationAccountId),
        amount: Value(amount),
        feeAmount: Value<double?>(feeAmount),
        note: Value(note),
        occurredAt: Value(occurredAt),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
      );
}

// ─── DebtRecord ─────────────────────────────────────────────────────────────

extension DebtRecordDataMapper on DebtRecordData {
  DebtRecord toEntity() => DebtRecord(
        id: id,
        ownerUserId: ownerUserId,
        counterpartyName: counterpartyName,
        debtDirection: debtDirection,
        amount: amount,
        remainingBalance: remainingBalance,
        note: note,
        dueDate: dueDate,
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );
}

extension DebtRecordEntityMapper on DebtRecord {
  DebtRecordsCompanion toCompanion() => DebtRecordsCompanion.insert(
        id: id,
        ownerUserId: ownerUserId,
        counterpartyName: counterpartyName,
        debtDirection: debtDirection,
        amount: amount,
        remainingBalance: remainingBalance,
        note: Value(note),
        dueDate: Value(dueDate),
        status: status,
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
        syncStatus: const Value.absent(),
        lastSyncedAt: const Value.absent(),
      );

  DebtRecordsCompanion toUpdateCompanion() => DebtRecordsCompanion(
        id: Value(id),
        ownerUserId: Value(ownerUserId),
        counterpartyName: Value(counterpartyName),
        debtDirection: Value(debtDirection),
        amount: Value(amount),
        remainingBalance: Value(remainingBalance),
        note: Value(note),
        dueDate: Value(dueDate),
        status: Value(status),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
      );
}

// ─── Goal ───────────────────────────────────────────────────────────────────

extension GoalDataMapper on GoalData {
  Goal toEntity() => Goal(
        id: id,
        ownerUserId: ownerUserId,
        householdId: householdId,
        name: name,
        goalType: goalType,
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        targetDate: targetDate,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );
}

extension GoalEntityMapper on Goal {
  GoalsCompanion toCompanion() => GoalsCompanion.insert(
        id: id,
        ownerUserId: ownerUserId,
        householdId: Value(householdId),
        name: name,
        goalType: goalType,
        targetAmount: targetAmount,
        currentAmount: Value(currentAmount),
        targetDate: Value(targetDate),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
        syncStatus: const Value.absent(),
        lastSyncedAt: const Value.absent(),
      );

  GoalsCompanion toUpdateCompanion() => GoalsCompanion(
        id: Value(id),
        ownerUserId: Value(ownerUserId),
        householdId: Value(householdId),
        name: Value(name),
        goalType: Value(goalType),
        targetAmount: Value(targetAmount),
        currentAmount: Value(currentAmount),
        targetDate: Value(targetDate),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
      );
}

// ─── RecurringTemplate ──────────────────────────────────────────────────────

extension RecurringTemplateDataMapper on RecurringTemplateData {
  RecurringTemplate toEntity() => RecurringTemplate(
        id: id,
        accountId: accountId,
        categoryId: categoryId,
        payeeId: payeeId,
        amount: amount,
        recurrenceRule: recurrenceRule,
        reminderEnabled: reminderEnabled,
        autoCreateDisabled: autoCreateDisabled,
        nextOccurrenceAt: nextOccurrenceAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );
}

extension RecurringTemplateEntityMapper on RecurringTemplate {
  RecurringTemplatesCompanion toCompanion() =>
      RecurringTemplatesCompanion.insert(
        id: id,
        accountId: accountId,
        categoryId: Value(categoryId),
        payeeId: Value(payeeId),
        amount: amount,
        recurrenceRule: recurrenceRule,
        reminderEnabled: Value(reminderEnabled),
        autoCreateDisabled: Value(autoCreateDisabled),
        nextOccurrenceAt: Value(nextOccurrenceAt),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
        syncStatus: const Value.absent(),
        lastSyncedAt: const Value.absent(),
      );

  RecurringTemplatesCompanion toUpdateCompanion() =>
      RecurringTemplatesCompanion(
        id: Value(id),
        accountId: Value(accountId),
        categoryId: Value(categoryId),
        payeeId: Value(payeeId),
        amount: Value(amount),
        recurrenceRule: Value(recurrenceRule),
        reminderEnabled: Value(reminderEnabled),
        autoCreateDisabled: Value(autoCreateDisabled),
        nextOccurrenceAt: Value(nextOccurrenceAt),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
      );
}

// ─── User ───────────────────────────────────────────────────────────────────

extension UserDataMapper on UserData {
  User toEntity() => User(
        id: id,
        email: email,
        displayName: displayName,
        currencyCode: currencyCode,
        locale: locale,
        timezone: timezone,
        aiEnabled: aiEnabled,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );
}

extension UserEntityMapper on User {
  UsersCompanion toCompanion() => UsersCompanion.insert(
        id: id,
        email: Value(email),
        displayName: Value(displayName),
        currencyCode: Value(currencyCode),
        locale: Value(locale),
        timezone: Value(timezone),
        aiEnabled: Value(aiEnabled),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
        syncStatus: const Value.absent(),
        lastSyncedAt: const Value.absent(),
      );

  UsersCompanion toUpdateCompanion() => UsersCompanion(
        id: Value(id),
        email: Value(email),
        displayName: Value(displayName),
        currencyCode: Value(currencyCode),
        locale: Value(locale),
        timezone: Value(timezone),
        aiEnabled: Value(aiEnabled),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
      );
}

// ─── Household ──────────────────────────────────────────────────────────────

extension HouseholdDataMapper on HouseholdData {
  Household toEntity() => Household(
        id: id,
        name: name,
        createdByUserId: createdByUserId,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );
}

extension HouseholdEntityMapper on Household {
  HouseholdsCompanion toCompanion() => HouseholdsCompanion.insert(
        id: id,
        name: name,
        createdByUserId: createdByUserId,
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
        syncStatus: const Value.absent(),
        lastSyncedAt: const Value.absent(),
      );

  HouseholdsCompanion toUpdateCompanion() => HouseholdsCompanion(
        id: Value(id),
        name: Value(name),
        createdByUserId: Value(createdByUserId),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
      );
}

// ─── HouseholdMember ────────────────────────────────────────────────────────

extension HouseholdMemberDataMapper on HouseholdMemberData {
  HouseholdMember toEntity() => HouseholdMember(
        id: id,
        householdId: householdId,
        userId: userId,
        role: role,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );
}

extension HouseholdMemberEntityMapper on HouseholdMember {
  HouseholdMembersCompanion toCompanion() => HouseholdMembersCompanion.insert(
        id: id,
        householdId: householdId,
        userId: userId,
        role: role,
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
        syncStatus: const Value.absent(),
        lastSyncedAt: const Value.absent(),
      );

  HouseholdMembersCompanion toUpdateCompanion() => HouseholdMembersCompanion(
        id: Value(id),
        householdId: Value(householdId),
        userId: Value(userId),
        role: Value(role),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(deletedAt),
      );
}

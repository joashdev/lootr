import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../security/encrypted_database_connection.dart';
import 'converters/type_converters.dart';
import 'tables/users.dart';
import 'tables/households.dart';
import 'tables/household_members.dart';
import 'tables/accounts.dart';
import 'tables/transactions.dart';
import 'tables/transfers.dart';
import 'tables/categories.dart';
import 'tables/payees.dart';
import 'tables/budgets.dart';
import 'tables/debt_records.dart';
import 'tables/goals.dart';
import 'tables/recurring_templates.dart';
import 'tables/account_balance_snapshots.dart';
import 'tables/notifications.dart';
import 'tables/ai_processing_logs.dart';
import 'tables/sync_metadata.dart';
import 'tables/budget_definitions.dart';
import 'tables/financial_events.dart';
import 'tables/categorization_rules.dart';
import 'tables/transaction_attachment_links.dart';
import 'tables/import_storage.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Households,
    HouseholdMembers,
    Accounts,
    Transactions,
    Transfers,
    Categories,
    Payees,
    Budgets,
    DebtRecords,
    Goals,
    RecurringTemplates,
    AccountBalanceSnapshots,
    Notifications,
    AiProcessingLogs,
    SyncMetadata,
    BudgetDefinitions,
    BudgetCategoryMemberships,
    BudgetAccountMemberships,
    BudgetTransactionMemberships,
    BudgetCategoryLimits,
    BudgetPeriods,
    RecurringOccurrences,
    GoalContributionEvents,
    DebtPaymentEvents,
    CategorizationRules,
    TransactionAttachmentLinks,
    ImportRuns,
    ImportSourceRecords,
    ImportSourceRelations,
    ImportProvenance,
    ImportDiscrepancies,
    ImportPreservedPayloads,
    ImportCheckpoints,
    RollbackCheckpoints,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  factory AppDatabase.inMemory() {
    return AppDatabase(NativeDatabase.memory());
  }

  factory AppDatabase.defaultDatabase() {
    return AppDatabase(EncryptedDatabaseConnection().lazy());
  }

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v2: budgets gain optional icon/color overrides. Null means the
        // budget inherits its category's visuals.
        await m.addColumn(budgets, budgets.icon);
        await m.addColumn(budgets, budgets.color);
      }
      if (from < 3) {
        await _migrateToV3(m);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _migrateToV3(Migrator m) async {
    await m.addColumn(accounts, accounts.balanceAtoms);
    await m.addColumn(accounts, accounts.currencyPrecision);
    await m.addColumn(accounts, accounts.icon);
    await m.addColumn(accounts, accounts.color);
    await m.addColumn(accounts, accounts.emojiIcon);
    await m.addColumn(accounts, accounts.sortOrder);

    await m.addColumn(
      accountBalanceSnapshots,
      accountBalanceSnapshots.balanceAtoms,
    );
    await m.addColumn(
      accountBalanceSnapshots,
      accountBalanceSnapshots.amountScale,
    );
    await m.addColumn(
      accountBalanceSnapshots,
      accountBalanceSnapshots.currencyCode,
    );

    await m.addColumn(categories, categories.emojiIcon);
    await m.addColumn(categories, categories.sourceAssetIcon);
    await m.addColumn(categories, categories.sortOrder);
    await m.addColumn(categories, categories.isArchived);

    await m.addColumn(transactions, transactions.amountAtoms);
    await m.addColumn(transactions, transactions.amountScale);
    await m.addColumn(transactions, transactions.currencyCode);
    await m.addColumn(transactions, transactions.title);

    await m.addColumn(transfers, transfers.sourceAmountAtoms);
    await m.addColumn(transfers, transfers.sourceAmountScale);
    await m.addColumn(transfers, transfers.sourceCurrencyCode);
    await m.addColumn(transfers, transfers.destinationAmountAtoms);
    await m.addColumn(transfers, transfers.destinationAmountScale);
    await m.addColumn(transfers, transfers.destinationCurrencyCode);
    await m.addColumn(transfers, transfers.feeAmountAtoms);
    await m.addColumn(transfers, transfers.feeAmountScale);
    await m.addColumn(transfers, transfers.feeCurrencyCode);

    await m.addColumn(budgets, budgets.amountAtoms);
    await m.addColumn(budgets, budgets.amountScale);
    await m.addColumn(budgets, budgets.currencyCode);

    await m.addColumn(recurringTemplates, recurringTemplates.amountAtoms);
    await m.addColumn(recurringTemplates, recurringTemplates.amountScale);
    await m.addColumn(recurringTemplates, recurringTemplates.currencyCode);
    await m.addColumn(
      recurringTemplates,
      recurringTemplates.transactionDirection,
    );

    await m.addColumn(goals, goals.targetAmountAtoms);
    await m.addColumn(goals, goals.currentAmountAtoms);
    await m.addColumn(goals, goals.amountScale);
    await m.addColumn(goals, goals.currencyCode);

    await m.addColumn(debtRecords, debtRecords.amountAtoms);
    await m.addColumn(debtRecords, debtRecords.remainingBalanceAtoms);
    await m.addColumn(debtRecords, debtRecords.amountScale);
    await m.addColumn(debtRecords, debtRecords.currencyCode);

    await m.createTable(budgetDefinitions);
    await m.createTable(budgetCategoryMemberships);
    await m.createTable(budgetAccountMemberships);
    await m.createTable(budgetTransactionMemberships);
    await m.createTable(budgetCategoryLimits);
    await m.createTable(budgetPeriods);
    await m.createTable(recurringOccurrences);
    await m.createTable(goalContributionEvents);
    await m.createTable(debtPaymentEvents);
    await m.createTable(categorizationRules);
    await m.createTable(transactionAttachmentLinks);
    await m.createTable(importRuns);
    await m.createTable(importSourceRecords);
    await m.createTable(importSourceRelations);
    await m.createTable(importProvenance);
    await m.createTable(importDiscrepancies);
    await m.createTable(importPreservedPayloads);
    await m.createTable(importCheckpoints);
    await m.createTable(rollbackCheckpoints);
  }
}

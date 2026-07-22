import 'package:drift/drift.dart';

import 'accounts.dart';
import 'categories.dart';
import 'households.dart';
import 'transactions.dart';
import 'users.dart';

/// First-class budget model for composite scopes and non-calendar periods.
///
/// The original `budgets` table remains as a compatibility surface for the
/// existing one-category monthly UI while repositories migrate to this model.
@DataClassName('BudgetDefinitionData')
@TableIndex(name: 'idx_budget_definitions_owner', columns: {#ownerUserId})
@TableIndex(
  name: 'idx_budget_definitions_period',
  columns: {#periodStart, #periodEnd},
)
class BudgetDefinitions extends Table {
  TextColumn get id => text()();
  TextColumn get householdId =>
      text().named('household_id').nullable().references(Households, #id)();
  TextColumn get ownerUserId =>
      text().named('owner_user_id').references(Users, #id)();
  TextColumn get name => text().nullable()();
  TextColumn get amountAtoms => text().named('amount_atoms')();
  IntColumn get amountScale => integer().named('amount_scale')();
  TextColumn get currencyCode => text().named('currency_code')();
  TextColumn get periodType =>
      text().named('period_type').withDefault(const Constant('monthly'))();
  DateTimeColumn get periodStart =>
      dateTime().named('period_start').nullable()();
  DateTimeColumn get periodEnd => dateTime().named('period_end').nullable()();
  TextColumn get cycleRule => text().named('cycle_rule').nullable()();
  TextColumn get directionFilter =>
      text().named('direction_filter').withDefault(const Constant('expense'))();
  TextColumn get membershipMode => text()
      .named('membership_mode')
      .withDefault(const Constant('all_matching'))();
  TextColumn get overlapPolicy => text()
      .named('overlap_policy')
      .withDefault(const Constant('independent'))();
  TextColumn get reviewState =>
      text().named('review_state').withDefault(const Constant('ready'))();
  BoolColumn get isReadOnly =>
      boolean().named('is_read_only').withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('local_only'))();
  DateTimeColumn get lastSyncedAt =>
      dateTime().named('last_synced_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (amount_scale >= 0)',
    'CHECK (period_type IN (\'monthly\', \'date_range\', \'custom_cycle\'))',
    'CHECK (direction_filter IN (\'expense\', \'income\', \'both\'))',
    'CHECK (membership_mode IN (\'all_matching\', \'explicit_only\'))',
    'CHECK (overlap_policy IN (\'independent\', \'deduplicated_summary\'))',
    'CHECK (review_state IN (\'ready\', \'needs_review\', \'preserved\'))',
    'CHECK (period_end IS NULL OR period_start IS NULL OR period_end > period_start)',
    'CHECK (sync_status IN (\'local_only\', \'pending_sync\', \'synced\', \'sync_failed\'))',
  ];
}

@DataClassName('BudgetCategoryMembershipData')
@TableIndex(name: 'idx_budget_category_membership_budget', columns: {#budgetId})
class BudgetCategoryMemberships extends Table {
  TextColumn get id => text()();
  TextColumn get budgetId =>
      text().named('budget_id').references(BudgetDefinitions, #id)();
  TextColumn get categoryId =>
      text().named('category_id').nullable().references(Categories, #id)();
  TextColumn get sourceReference =>
      text().named('source_reference').nullable()();
  TextColumn get membership => text().withDefault(const Constant('include'))();
  TextColumn get reviewState =>
      text().named('review_state').withDefault(const Constant('ready'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (category_id IS NOT NULL OR source_reference IS NOT NULL)',
    'CHECK (membership IN (\'include\', \'exclude\'))',
    'CHECK (review_state IN (\'ready\', \'needs_review\', \'missing_reference\'))',
  ];
}

@DataClassName('BudgetAccountMembershipData')
@TableIndex(name: 'idx_budget_account_membership_budget', columns: {#budgetId})
class BudgetAccountMemberships extends Table {
  TextColumn get id => text()();
  TextColumn get budgetId =>
      text().named('budget_id').references(BudgetDefinitions, #id)();
  TextColumn get accountId =>
      text().named('account_id').nullable().references(Accounts, #id)();
  TextColumn get sourceReference =>
      text().named('source_reference').nullable()();
  TextColumn get membership => text().withDefault(const Constant('include'))();
  TextColumn get reviewState =>
      text().named('review_state').withDefault(const Constant('ready'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (account_id IS NOT NULL OR source_reference IS NOT NULL)',
    'CHECK (membership IN (\'include\', \'exclude\'))',
    'CHECK (review_state IN (\'ready\', \'needs_review\', \'missing_reference\'))',
  ];
}

@DataClassName('BudgetTransactionMembershipData')
@TableIndex(
  name: 'idx_budget_transaction_membership_budget',
  columns: {#budgetId},
)
class BudgetTransactionMemberships extends Table {
  TextColumn get id => text()();
  TextColumn get budgetId =>
      text().named('budget_id').references(BudgetDefinitions, #id)();
  TextColumn get transactionId =>
      text().named('transaction_id').nullable().references(Transactions, #id)();
  TextColumn get sourceReference =>
      text().named('source_reference').nullable()();
  TextColumn get membership => text().withDefault(const Constant('include'))();
  TextColumn get reasonCode => text().named('reason_code').nullable()();
  TextColumn get reviewState =>
      text().named('review_state').withDefault(const Constant('ready'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (transaction_id IS NOT NULL OR source_reference IS NOT NULL)',
    'CHECK (membership IN (\'include\', \'exclude\'))',
    'CHECK (review_state IN (\'ready\', \'needs_review\', \'missing_reference\'))',
  ];
}

@DataClassName('BudgetCategoryLimitData')
@TableIndex(name: 'idx_budget_category_limit_budget', columns: {#budgetId})
class BudgetCategoryLimits extends Table {
  TextColumn get id => text()();
  TextColumn get budgetId =>
      text().named('budget_id').references(BudgetDefinitions, #id)();
  TextColumn get categoryId =>
      text().named('category_id').nullable().references(Categories, #id)();
  TextColumn get sourceReference =>
      text().named('source_reference').nullable()();
  TextColumn get amountAtoms => text().named('amount_atoms')();
  IntColumn get amountScale => integer().named('amount_scale')();
  TextColumn get currencyCode => text().named('currency_code')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (category_id IS NOT NULL OR source_reference IS NOT NULL)',
    'CHECK (amount_scale >= 0)',
  ];
}

@DataClassName('BudgetPeriodData')
@TableIndex(name: 'idx_budget_period_budget', columns: {#budgetId})
@TableIndex(
  name: 'uq_budget_period_bounds',
  columns: {#budgetId, #startsAt, #endsAt},
  unique: true,
)
class BudgetPeriods extends Table {
  TextColumn get id => text()();
  TextColumn get budgetId =>
      text().named('budget_id').references(BudgetDefinitions, #id)();
  DateTimeColumn get startsAt => dateTime().named('starts_at')();
  DateTimeColumn get endsAt => dateTime().named('ends_at')();
  TextColumn get amountAtoms => text().named('amount_atoms')();
  IntColumn get amountScale => integer().named('amount_scale')();
  TextColumn get currencyCode => text().named('currency_code')();
  BoolColumn get isImported =>
      boolean().named('is_imported').withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (ends_at > starts_at)',
    'CHECK (amount_scale >= 0)',
  ];
}

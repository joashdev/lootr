# Task 04 — Data Layer — Repositories

**Status:** [x]

---

## Objective

Implement the Repository pattern for all 12 domains. Each repository wraps Drift DAO queries, exposes reactive streams (`watch`), and handles the write-path atomicity (SQLite transaction wrapping balance updates + sync_status flips).

References: `docs/state-management.md` (repository pattern), `docs/solutions-arch.md §6.1-6.2`, `docs/database-schema.md`

## Dependencies

- 03 — Data Layer — Drift Schema & Database

## Deliverables

### 4.1 TransactionRepo (`lib/data/repositories/transaction_repo.dart`)
- `watchFiltered(TransactionFilters filters) → Stream<List<TransactionRow>>`
- `watchById(String id) → Stream<TransactionRow?>`
- `watchByAccount(String accountId) → Stream<List<TransactionRow>>`
- `create(TransactionCompanion tx) → Future<String>` — returns new row ID
  - Inside a SQLite `transaction`:
    1. INSERT transaction row
    2. UPDATE account balance (± amount based on direction)
    3. UPDATE account `sync_status` = `'pending_sync'`
    4. (if recurring_template_id set) UPDATE `next_occurrence_at` on template
- `update(TransactionCompanion tx) → Future<void>`
  - Reverse old balance impact, apply new balance impact
- `softDelete(String id) → Future<void>`
  - Set `deleted_at`, revert balance impact, flip sync_status

### 4.2 AccountRepo (`lib/data/repositories/account_repo.dart`)
- `watchAll({bool includeArchived = false}) → Stream<List<AccountRow>>`
- `watchById(String id) → Stream<AccountRow?>`
- `create(AccountCompanion a) → Future<String>`
- `update(AccountCompanion a) → Future<void>`
- `archive(String id) → Future<void>`
- `getBalance(String id) → Future<double>`
- `recalcBalance(String id) → Future<void>` — sums all non-deleted transactions for the account

### 4.3 BudgetRepo (`lib/data/repositories/budget_repo.dart`)
- `watchAll({int? month, int? year}) → Stream<List<BudgetRow>>`
- `watchById(String id) → Stream<BudgetRow?>`
- `watchSpentForBudget(String budgetId) → Stream<double>` — SUM of transactions matching budget's category + month/year
- `create(BudgetCompanion b) → Future<String>`
- `update(BudgetCompanion b) → Future<void>`
- `softDelete(String id) → Future<void>`

### 4.4 CategoryRepo (`lib/data/repositories/category_repo.dart`)
- `watchAll() → Stream<List<CategoryRow>>`
- `watchByGroup(String group) → Stream<List<CategoryRow>>` — expense/income/transfer
- `create(CategoryCompanion c) → Future<String>`
- `update(CategoryCompanion c) → Future<void>`

### 4.5 PayeeRepo (`lib/data/repositories/payee_repo.dart`)
- `watchAll() → Stream<List<PayeeRow>>`
- `watchById(String id) → Stream<PayeeRow?>`
- `findByNormalizedName(String name) → Future<PayeeRow?>`
- `createOrGet(String normalizedName) → Future<PayeeRow>`

### 4.6 TransferRepo (`lib/data/repositories/transfer_repo.dart`)
- `watchAll() → Stream<List<TransferRow>>`
- `watchByAccount(String accountId) → Stream<List<TransferRow>>`
- `create(TransferCompanion t) → Future<String>`
  - SQLite transaction: insert transfer, debit source account balance, credit destination account balance
- `softDelete(String id) → Future<void>`
  - Reverse both balance impacts

### 4.7 DebtRepo (`lib/data/repositories/debt_repo.dart`)
- `watchAll() → Stream<List<DebtRecordRow>>`
- `watchById(String id) → Stream<DebtRecordRow?>`
- `create(DebtRecordCompanion d) → Future<String>`
- `update(DebtRecordCompanion d) → Future<void>`
- `settle(String id) → Future<void>`

### 4.8 GoalRepo (`lib/data/repositories/goal_repo.dart`)
- `watchAll() → Stream<List<GoalRow>>`
- `watchById(String id) → Stream<GoalRow?>`
- `create(GoalCompanion g) → Future<String>`
- `update(GoalCompanion g) → Future<void>`
- `addContribution(String id, double amount) → Future<void>`

### 4.9 RecurringRepo (`lib/data/repositories/recurring_repo.dart`)
- `watchAll() → Stream<List<RecurringTemplateRow>>`
- `watchById(String id) → Stream<RecurringTemplateRow?>`
- `watchDue({DateTime? before}) → Stream<List<RecurringTemplateRow>>`
- `create(RecurringTemplateCompanion r) → Future<String>`
- `update(RecurringTemplateCompanion r) → Future<void>`
- `advanceNextOccurrence(String id) → Future<void>`

### 4.10 UserRepo (`lib/data/repositories/user_repo.dart`)
- `watchCurrentUser() → Stream<UserRow?>`
- `create(UserCompanion u) → Future<String>`
- `update(UserCompanion u) → Future<void>`
- `updateAiEnabled(bool enabled) → Future<void>`

### 4.11 HouseholdRepo (`lib/data/repositories/household_repo.dart`)
- `watchAll() → Stream<List<HouseholdRow>>`
- `watchById(String id) → Stream<HouseholdRow?>`
- `watchMembers(String householdId) → Stream<List<HouseholdMemberRow>>`
- `create(HouseholdCompanion h) → Future<String>`
- `addMember(HouseholdMemberCompanion m) → Future<void>`
- `updateMemberRole(String memberId, String role) → Future<void>`

### 4.12 SyncMetadataRepo (`lib/data/repositories/sync_metadata_repo.dart`)
- `get(String key) → Future<String?>`
- `set(String key, String value) → Future<void>`
- Keys: `last_synced_at`, `last_sync_attempt_at`, `last_sync_status`, `last_sync_error`, `sync_failed_count`

### 4.13 Repository provider registration
Add all 12 repos to `lib/application/providers/repo_providers.dart` as singletons.

## Acceptance Criteria

- [x] All repos compile and pass Dart analysis
- [x] Unit tests for each repo using `AppDatabase.inMemory()`
- [x] `TransactionRepo.create()` atomically updates both transaction table and account balance in one SQLite transaction
- [x] `TransactionRepo.softDelete()` reverts balance and sets `deleted_at`
- [x] `TransferRepo.create()` atomically debits source and credits destination
- [x] `BudgetRepo.watchSpentForBudget()` returns correct SUM for category+period
- [x] Reactive `watch*()` methods emit when underlying rows change
- [x] Repos do NOT import Flutter libraries (pure Dart dependency)
- [x] All repos are registered in `repo_providers.dart`

## Files Likely Affected

- `lib/data/repositories/transaction_repo.dart` (new)
- `lib/data/repositories/account_repo.dart` (new)
- `lib/data/repositories/budget_repo.dart` (new)
- `lib/data/repositories/category_repo.dart` (new)
- `lib/data/repositories/payee_repo.dart` (new)
- `lib/data/repositories/transfer_repo.dart` (new)
- `lib/data/repositories/debt_repo.dart` (new)
- `lib/data/repositories/goal_repo.dart` (new)
- `lib/data/repositories/recurring_repo.dart` (new)
- `lib/data/repositories/user_repo.dart` (new)
- `lib/data/repositories/household_repo.dart` (new)
- `lib/data/repositories/sync_metadata_repo.dart` (new)
- `lib/application/providers/repo_providers.dart` (new)
- `test/data/repositories/` (new)

# Task 05 — Domain Layer — Entities & Value Objects

**Status:** [ ]

---

## Objective

Define pure Dart domain entities and value objects that decouple the presentation and application layers from the Drift row types. Entities are immutable (Equatable/Freezed), serializable, and represent the domain model from `docs/domain-model.md`.

References: `docs/domain-model.md`, `docs/solutions-arch.md §7`

## Dependencies

- 03 — Data Layer — Drift Schema & Database (for column types, not imports)

## Deliverables

### 5.1 Entities (`lib/domain/entities/`)

Each entity is a pure Dart class with no Drift imports. Use `freezed` for immutability, `Equatable`-compatible equality, and `json_annotation` for serialization.

| Entity | Key Fields |
|---|---|
| `Transaction` | id, accountId, categoryId, payeeId, parentTransactionId, recurringTemplateId, amount, direction, mode, subtype, note, metadata, occurredAt, createdAt, updatedAt, deletedAt |
| `Account` | id, householdId, ownerUserId, name, accountType, balance, currencyCode, isArchived, isHidden |
| `Budget` | id, householdId, ownerUserId, categoryId, amount, month, year, spent (computed, not stored) |
| `Category` | id, parentCategoryId, name, icon, color, categoryGroup |
| `Payee` | id, normalizedName, displayName, logoUrl |
| `Transfer` | id, sourceAccountId, destinationAccountId, amount, feeAmount, note, occurredAt |
| `DebtRecord` | id, ownerUserId, counterpartyName, debtDirection, amount, remainingBalance, note, dueDate, status |
| `Goal` | id, ownerUserId, householdId, name, goalType, targetAmount, currentAmount, targetDate, progress (computed) |
| `RecurringTemplate` | id, accountId, categoryId, payeeId, amount, recurrenceRule, reminderEnabled, autoCreateDisabled, nextOccurrenceAt |
| `User` | id, email, displayName, currencyCode, locale, timezone, aiEnabled |
| `Household` | id, name, createdByUserId |
| `HouseholdMember` | id, householdId, userId, role |

### 5.2 Value Objects (`lib/domain/value_objects/`)

| Value Object | Purpose |
|---|---|
| `Money` | amount + currencyCode, `+`, `-`, `abs()`, `format()` using intl |
| `DateRange` | start + end, `contains(DateTime)`, `duration`, `monthsInRange()` |
| `TransactionFilters` | direction, mode, accountId, categoryId, minAmount, maxAmount, dateRange — with `isEmpty`, `apply(List<Transaction>)` |
| `SyncHealth` | lastSyncedAt, pendingCount, failedCount, lastStatus — read from sync_metadata |
| `UndoEntry` | transactionId, message, rollback (callback), createdAt |

### 5.3 Mappers

Each entity file includes a mapper extension or standalone function:
- `TransactionRow → Transaction` (from Drift row to entity)
- `Transaction → TransactionCompanion` (from entity to Drift companion for writes)

Mappers live alongside entities, not in the data layer, to keep the dependency rule intact.

## Acceptance Criteria

- [ ] All entities compile with no Drift or Flutter imports (pure Dart)
- [ ] `freezed` generates `==`, `hashCode`, `copyWith`, `toString` for all entities
- [ ] `json_annotation` generates `fromJson`/`toJson` for all entities
- [ ] `Money` arithmetic works correctly with same and different currencies (throws on mismatch)
- [ ] `DateRange.monthsInRange()` returns correct month-year pairs
- [ ] `TransactionFilters.isEmpty` returns true when all filters are null/default
- [ ] Row-to-entity mappers handle nullable fields correctly
- [ ] Entity-to-companion mappers produce valid Drift companions

## Files Likely Affected

- `lib/domain/entities/transaction.dart` (new)
- `lib/domain/entities/account.dart` (new)
- `lib/domain/entities/budget.dart` (new)
- `lib/domain/entities/category.dart` (new)
- `lib/domain/entities/payee.dart` (new)
- `lib/domain/entities/transfer.dart` (new)
- `lib/domain/entities/debt_record.dart` (new)
- `lib/domain/entities/goal.dart` (new)
- `lib/domain/entities/recurring_template.dart` (new)
- `lib/domain/entities/user.dart` (new)
- `lib/domain/entities/household.dart` (new)
- `lib/domain/entities/household_member.dart` (new)
- `lib/domain/value_objects/money.dart` (new)
- `lib/domain/value_objects/date_range.dart` (new)
- `lib/domain/value_objects/transaction_filters.dart` (new)
- `lib/domain/value_objects/sync_health.dart` (new)
- `lib/domain/value_objects/undo_entry.dart` (new)
- `test/domain/entities/` (new)
- `test/domain/value_objects/` (new)

# Task 03 — Data Layer — Drift Schema & Database

**Status:** [x]

---

## Objective

Implement all 16 database tables from `docs/database-schema.md` using Drift ORM. Configure database initialization, migrations, and the in-memory test database.

References: `docs/database-schema.md`, `docs/solutions-arch.md §6`, `docs/domain-model.md`

## Dependencies

- 01 — Project Setup & Scaffolding

## Deliverables

### 3.1 Table definitions — Syncable (12 tables)
Each table file lives in `lib/data/database/tables/` and defines a Drift table class + companion + row class.

All syncable tables share these columns:
- `id` — `TEXT`, UUID v4, primary key
- `created_at` — `TEXT`, ISO 8601 UTC
- `updated_at` — `TEXT`, ISO 8601 UTC
- `deleted_at` — `TEXT`, nullable (soft delete)
- `sync_status` — `TEXT`, NOT NULL, default `'local_only'`
- `last_synced_at` — `TEXT`, nullable

| # | Table | Type Converters / Enums |
|---|---|---|
| 1 | `users` | `email` nullable unique, `display_name`, `currency_code` default `'PHP'`, `locale`, `timezone`, `ai_enabled` bool |
| 2 | `households` | `name`, `created_by_user_id` FK→users |
| 3 | `household_members` | `household_id` FK, `user_id` FK, `role` (owner/member/viewer), UNIQUE(household_id, user_id) |
| 4 | `accounts` | `household_id` nullable FK, `owner_user_id` FK, `name`, `account_type` (cash/bank/ewallet/savings/investment/crypto/credit_card/loan/bnpl), `balance` REAL default 0, `currency_code`, `is_archived`, `is_hidden` |
| 5 | `transactions` | `account_id` FK, `category_id` nullable FK, `payee_id` nullable FK, `parent_transaction_id` nullable self-FK, `recurring_template_id` nullable FK, `amount` REAL (always positive), `transaction_direction` (expense/income), `transaction_mode` (one_time/recurring/installment/debt), `transaction_subtype` nullable (salary/refund/transfer_fee/subscription/loan_payment/debt_payment/opening_balance), `note` nullable, `metadata` nullable JSON, `occurred_at` |
| 6 | `transfers` | `source_account_id` FK, `destination_account_id` FK, `amount`, `fee_amount` nullable, `note`, `occurred_at` |
| 7 | `categories` | `parent_category_id` nullable self-FK, `name`, `icon`, `color`, `category_group` (expense/income/transfer) |
| 8 | `payees` | `normalized_name` UNIQUE, `display_name` nullable, `logo_url` nullable |
| 9 | `budgets` | `household_id` nullable FK, `owner_user_id` FK, `category_id` FK, `amount`, `month` (1-12), `year`, UNIQUE(owner_user_id, category_id, month, year) |
| 10 | `debt_records` | `owner_user_id` FK, `counterparty_name`, `debt_direction` (lent/borrowed), `amount`, `remaining_balance`, `note`, `due_date` nullable, `status` (active/partially_paid/settled) |
| 11 | `goals` | `owner_user_id` FK, `household_id` nullable FK, `name`, `goal_type` (emergency_fund/savings/travel/debt_payoff/custom), `target_amount`, `current_amount` default 0, `target_date` nullable |
| 12 | `recurring_templates` | `account_id` FK, `category_id` nullable FK, `payee_id` nullable FK, `amount`, `recurrence_rule` (ISO 8601 RRULE), `reminder_enabled` bool, `auto_create_disabled` bool, `next_occurrence_at` |

### 3.2 Table definitions — Local-only (4 tables)
No sync columns.

| # | Table | Columns |
|---|---|---|
| 13 | `account_balance_snapshots` | `id` PK, `account_id` FK, `balance`, `snapshot_at` |
| 14 | `notifications` | `id` PK, `notification_type` (recurring_reminder/bill_due/installment_due/debt_reminder/subscription_reminder), `related_entity_id`, `scheduled_at`, `is_completed` |
| 15 | `ai_processing_logs` | `id` PK, `source_type` (ocr/nlp/categorization), `source_reference_id`, `model_used`, `extracted_payload` JSON, `confidence_score` |
| 16 | `sync_metadata` | `key` TEXT PK, `value` TEXT |

### 3.3 Type converters (`lib/data/database/converters/`)
- `DateTimeConverter` — ISO 8601 ↔ DateTime
- `BoolConverter` — INTEGER 0/1 ↔ bool
- `JsonConverter` — JSON string ↔ Map<String, dynamic>
- All enum converters (sync status, direction, mode, account types, etc.)

### 3.4 AppDatabase class (`lib/data/database/app_database.dart`)
- `@DriftDatabase` annotation listing all 16 table includes
- Generated `$AppDatabase` superclass
- `constructor` with `QueryExecutor` parameter (supports in-memory for tests)
- Migration strategy: additive only, versioned migrations

### 3.5 Database provider (`lib/application/providers/database_provider.dart`)
- `databaseProvider` — singleton `Provider<AppDatabase>`
- Uses `path_provider` to resolve DB path in documents directory
- Constructor: pass `QueryExecutor` from `NativeDatabase` or `DatabaseConnection.inMemory`

### 3.6 Indexes
Create all 28 indexes from `database-schema.md §7` in the table definitions or via `schemaVersion` migrations.

### 3.7 Foreign key pragma
Enable `PRAGMA foreign_keys = ON` on every database connection.

## Key Constraints (from schema spec)

- UUID v4 as PK: never auto-increment
- Timestamps always ISO 8601 UTC strings
- Booleans always `INTEGER NOT NULL DEFAULT 0`
- Soft delete via `deleted_at TEXT`
- Amounts always positive REAL; direction is a separate column
- All syncable tables have the 6 sync columns
- Account type, direction, mode, role, etc. are CHECK-constrained or enum-backed

## Acceptance Criteria

- [x] `dart run build_runner build` generates all Drift code without errors
- [x] `AppDatabase` opens successfully with both `NativeDatabase` and `.inMemory()`
- [x] All 16 tables are accessible via `database.users`, `database.transactions`, etc.
- [x] All CHECK constraints enforce valid enum values (insert invalid → error)
- [x] UNIQUE constraints enforce correctly (duplicate household_members key → error)
- [x] All foreign keys resolve correctly
- [x] All 28 indexes exist on the generated schema
- [x] `PRAGMA foreign_keys` returns 1 after opening
- [x] In-memory database works for tests (no filesystem dependency)

## Files Likely Affected

- `lib/data/database/app_database.dart` (new)
- `lib/data/database/tables/users.dart` (new)
- `lib/data/database/tables/households.dart` (new)
- `lib/data/database/tables/household_members.dart` (new)
- `lib/data/database/tables/accounts.dart` (new)
- `lib/data/database/tables/transactions.dart` (new)
- `lib/data/database/tables/transfers.dart` (new)
- `lib/data/database/tables/categories.dart` (new)
- `lib/data/database/tables/payees.dart` (new)
- `lib/data/database/tables/budgets.dart` (new)
- `lib/data/database/tables/debt_records.dart` (new)
- `lib/data/database/tables/goals.dart` (new)
- `lib/data/database/tables/recurring_templates.dart` (new)
- `lib/data/database/tables/account_balance_snapshots.dart` (new)
- `lib/data/database/tables/notifications.dart` (new)
- `lib/data/database/tables/ai_processing_logs.dart` (new)
- `lib/data/database/tables/sync_metadata.dart` (new)
- `lib/data/database/converters/type_converters.dart` (new)
- `lib/application/providers/database_provider.dart` (new)
- `lib/core/constants/enums.dart` (update — all enum definitions)
- `test/data/database_test.dart` (new)

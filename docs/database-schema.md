# Database Schema — Personal Finance App

Source of truth for the local SQLite database used by the Drift ORM.

References: `domain-model.md` (entities), `product-strategy.md` (features/philosophy).

---

## 1. Design Decisions

### 1.1 Transfer Storage
Transfers stored in a dedicated `transfers` table (source → destination + amount). No transaction row is created for a transfer. The transfers table is not included in spending analytics. Transfer fees are a separate expense transaction.

### 1.2 Income Deductions
Self-referential `parent_transaction_id` column on `transactions`. A salary transaction is the parent; each deduction (tax, SSS, PhilHealth, Pag-IBIG, insurance) is a child row referencing it.

### 1.3 Opening Balance
Modeled as `transaction_subtype = 'opening_balance'` on an income transaction. A `metadata` TEXT (JSON) column provides extensible storage for OCR data, voice transcripts, AI metadata, and future special-purpose values without adding a column per flag.

### 1.4 Currency Amounts
Stored as REAL. Positive for all rows; `transaction_direction` indicates the financial sign. This keeps aggregation queries simple (SUM with CASE).

---

## 2. Conventions

| Convention | Rule |
|---|---|
| Naming | snake_case. Table aliases in queries use abbreviated form (e.g. `t` for transactions). |
| Primary key | Always `id` — TEXT, UUID v4, generated locally. |
| Foreign keys | Named `{referenced_table}_id`. |
| Timestamps | INTEGER (Unix seconds), UTC. Drift `dateTime()` default. |
| Booleans | INTEGER, 0 or 1. |
| Soft delete | `deleted_at` INTEGER, nullable. NULL = active. |
| Sync fields | `sync_status` TEXT + `last_synced_at` INTEGER on every syncable table. |
| Monetization | REAL, always positive. |
| JSON | TEXT column containing valid JSON. Read with `json_extract()`, validate with `json_valid()`. |
| Default timezone | UTC for all timestamps. Locale conversion in the application layer. |

---

## 3. Syncable Tables (12)

These tables carry `sync_status` and `last_synced_at` for future sync with the NestJS backend.

### sync_status Values

| Value | Meaning |
|---|---|
| `local_only` | Created offline. Not yet sent to server. |
| `pending_sync` | Modified locally after last sync. |
| `synced` | In sync with server. |
| `sync_failed` | Last sync attempt failed. |

---

### 3.1 `users`

Local-first. A user can operate without a `users` row (anonymous offline mode). A row is created when a user opts into cloud sync. `email` is nullable to support purely local usage.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | TEXT | PK | UUID v4 |
| email | TEXT | UNIQUE, nullable | NULL for local-only users |
| display_name | TEXT | nullable | |
| currency_code | TEXT | NOT NULL, default `'PHP'` | ISO 4217 |
| locale | TEXT | nullable | e.g. `en-PH` |
| timezone | TEXT | nullable | e.g. `Asia/Manila` |
| ai_enabled | INTEGER | NOT NULL, default 0 | Boolean |
| created_at | INTEGER | NOT NULL | |
| updated_at | INTEGER | NOT NULL | |
| deleted_at | INTEGER | nullable | Soft delete |
| sync_status | TEXT | NOT NULL, default `'local_only'` | |
| last_synced_at | INTEGER | nullable | |

**Indexes:** `idx_users_email` on `email`.

---

### 3.2 `households`

Shared financial space supporting shared accounts, budgets, goals, and debts.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | TEXT | PK | UUID v4 |
| name | TEXT | NOT NULL | |
| created_by_user_id | TEXT | NOT NULL, FK → users.id | |
| created_at | INTEGER | NOT NULL | |
| updated_at | INTEGER | NOT NULL | |
| deleted_at | INTEGER | nullable | |
| sync_status | TEXT | NOT NULL, default `'local_only'` | |
| last_synced_at | INTEGER | nullable | |

**Indexes:** `idx_households_created_by` on `created_by_user_id`.

---

### 3.3 `household_members`

Join table with role-based permissions.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | TEXT | PK | UUID v4 |
| household_id | TEXT | NOT NULL, FK → households.id | |
| user_id | TEXT | NOT NULL, FK → users.id | |
| role | TEXT | NOT NULL, CHECK (`'owner'`, `'member'`, `'viewer'`) | |
| created_at | INTEGER | NOT NULL | |
| sync_status | TEXT | NOT NULL, default `'local_only'` | |
| last_synced_at | INTEGER | nullable | |

**Unique constraint:** `(household_id, user_id)`.
**Indexes:** `idx_hh_members_household` on `household_id`, `idx_hh_members_user` on `user_id`.

---

### 3.4 `accounts`

Stored financial containers. Balance is stored directly (read optimisation) and updated when transactions are created, edited, or deleted. Recalculation from transaction history exists as a recovery tool.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | TEXT | PK | UUID v4 |
| household_id | TEXT | nullable, FK → households.id | NULL = personal account |
| owner_user_id | TEXT | NOT NULL, FK → users.id | |
| name | TEXT | NOT NULL | |
| account_type | TEXT | NOT NULL, CHECK | See enum below |
| balance | REAL | NOT NULL, default 0 | Stored balance (read optimisation) |
| currency_code | TEXT | NOT NULL, default `'PHP'` | |
| is_archived | INTEGER | NOT NULL, default 0 | |
| is_hidden | INTEGER | NOT NULL, default 0 | Hides from dashboard |
| created_at | INTEGER | NOT NULL | |
| updated_at | INTEGER | NOT NULL | |
| deleted_at | INTEGER | nullable | |
| sync_status | TEXT | NOT NULL, default `'local_only'` | |
| last_synced_at | INTEGER | nullable | |

**account_type CHECK values:**

| Group | Values |
|---|---|
| Asset | `cash`, `bank`, `ewallet`, `savings`, `investment`, `crypto` |
| Liability | `credit_card`, `loan`, `bnpl` |

**Indexes:** `idx_accounts_owner` on `owner_user_id`, `idx_accounts_household` on `household_id`, `idx_accounts_type` on `account_type`.

---

### 3.5 `transactions`

Core financial event. Every transaction belongs to one account. Transfers between accounts live in the separate `transfers` table.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | TEXT | PK | UUID v4 |
| account_id | TEXT | NOT NULL, FK → accounts.id | |
| category_id | TEXT | nullable, FK → categories.id | |
| payee_id | TEXT | nullable, FK → payees.id | |
| parent_transaction_id | TEXT | nullable, FK → transactions.id | For income deductions |
| recurring_template_id | TEXT | nullable, FK → recurring_templates.id | |
| amount | REAL | NOT NULL | Always positive |
| transaction_direction | TEXT | NOT NULL, CHECK | `'expense'` or `'income'` |
| transaction_mode | TEXT | NOT NULL, CHECK | `'one_time'`, `'recurring'`, `'installment'`, `'debt'` |
| transaction_subtype | TEXT | nullable | e.g. `'salary'`, `'refund'`, `'transfer_fee'`, `'subscription'`, `'loan_payment'`, `'debt_payment'`, `'opening_balance'` |
| note | TEXT | nullable | Human description or raw OCR text |
| metadata | TEXT | nullable | JSON — extensible (OCR data, voice transcripts, AI metadata) |
| occurred_at | INTEGER | NOT NULL | When the transaction happened |
| created_at | INTEGER | NOT NULL | |
| updated_at | INTEGER | NOT NULL | |
| deleted_at | INTEGER | nullable | |
| sync_status | TEXT | NOT NULL, default `'local_only'` | |
| last_synced_at | INTEGER | nullable | |

**Indexes:**
- `idx_transactions_account` on `account_id`
- `idx_transactions_category` on `category_id`
- `idx_transactions_payee` on `payee_id`
- `idx_transactions_parent` on `parent_transaction_id`
- `idx_transactions_occurred_at` on `occurred_at`
- `idx_transactions_direction` on `transaction_direction`

---

### 3.6 `transfers`

Dedicated transfer entity. Subtracts from source, adds to destination. Excluded from spending analytics and budget calculations.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | TEXT | PK | UUID v4 |
| source_account_id | TEXT | NOT NULL, FK → accounts.id | |
| destination_account_id | TEXT | NOT NULL, FK → accounts.id | |
| amount | REAL | NOT NULL | |
| fee_amount | REAL | nullable, default 0 | Informational; the actual fee should also be recorded as a separate expense transaction |
| note | TEXT | nullable | |
| occurred_at | INTEGER | NOT NULL | |
| created_at | INTEGER | NOT NULL | |
| updated_at | INTEGER | NOT NULL | |
| deleted_at | INTEGER | nullable | |
| sync_status | TEXT | NOT NULL, default `'local_only'` | |
| last_synced_at | INTEGER | nullable | |

**Indexes:** `idx_transfers_source` on `source_account_id`, `idx_transfers_dest` on `destination_account_id`, `idx_transfers_occurred_at` on `occurred_at`.

---

### 3.7 `categories`

Transaction categories. Seeded with defaults on first launch. Categories are syncable so user customisations can be backed up, but the initial seed data is bundled with the app.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | TEXT | PK | UUID v4 |
| parent_category_id | TEXT | nullable, FK → categories.id | Self-referential for subcategories |
| name | TEXT | NOT NULL | |
| icon | TEXT | nullable | Icon identifier string |
| color | TEXT | nullable | Hex colour |
| category_group | TEXT | NOT NULL, CHECK | `'expense'`, `'income'`, `'transfer'` |
| created_at | INTEGER | NOT NULL | |
| updated_at | INTEGER | NOT NULL | |
| sync_status | TEXT | NOT NULL, default `'synced'` | Seed data starts as synced |
| last_synced_at | INTEGER | nullable | |

**Indexes:** `idx_categories_parent` on `parent_category_id`.

---

### 3.8 `payees`

Normalised merchant or payee. Deduplicated by `normalized_name`.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | TEXT | PK | UUID v4 |
| normalized_name | TEXT | NOT NULL, UNIQUE | Lowercase, stripped for dedup |
| display_name | TEXT | nullable | Human-readable |
| logo_url | TEXT | nullable | |
| created_at | INTEGER | NOT NULL | |
| updated_at | INTEGER | NOT NULL | |
| sync_status | TEXT | NOT NULL, default `'local_only'` | |
| last_synced_at | INTEGER | nullable | |

**Indexes:** `idx_payees_normalized` on `normalized_name` (UNIQUE).

---

### 3.9 `budgets`

Monthly category spending target. Advisory only — budgets do not block or restrict transactions.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | TEXT | PK | UUID v4 |
| household_id | TEXT | nullable, FK → households.id | NULL = personal budget |
| owner_user_id | TEXT | NOT NULL, FK → users.id | |
| category_id | TEXT | NOT NULL, FK → categories.id | |
| amount | REAL | NOT NULL | Target amount |
| month | INTEGER | NOT NULL, CHECK 1–12 | |
| year | INTEGER | NOT NULL | |
| icon | TEXT | nullable | v2. Visual override; NULL = inherit category icon |
| color | TEXT | nullable | v2. Hex color override; NULL = inherit category color |
| created_at | INTEGER | NOT NULL | |
| updated_at | INTEGER | NOT NULL | |
| sync_status | TEXT | NOT NULL, default `'local_only'` | |
| last_synced_at | INTEGER | nullable | |

**Unique constraint:** `(owner_user_id, category_id, month, year)` — one budget per category per month.
**Indexes:** `idx_budgets_owner_period` on `(owner_user_id, month, year)`.

---

### 3.10 `debt_records`

Social debt tracking (lent/borrowed between people). Institutional debt (credit cards, loans) is tracked via liability accounts.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | TEXT | PK | UUID v4 |
| owner_user_id | TEXT | NOT NULL, FK → users.id | |
| counterparty_name | TEXT | NOT NULL | Person or entity name |
| debt_direction | TEXT | NOT NULL, CHECK | `'lent'` or `'borrowed'` |
| amount | REAL | NOT NULL | Original amount |
| remaining_balance | REAL | NOT NULL | |
| note | TEXT | nullable | |
| due_date | INTEGER | nullable | ISO 8601 date |
| status | TEXT | NOT NULL, CHECK | `'active'`, `'partially_paid'`, `'settled'` |
| created_at | INTEGER | NOT NULL | |
| updated_at | INTEGER | NOT NULL | |
| sync_status | TEXT | NOT NULL, default `'local_only'` | |
| last_synced_at | INTEGER | nullable | |

**Indexes:** `idx_debt_owner` on `owner_user_id`, `idx_debt_status` on `status`.

---

### 3.11 `goals`

Financial targets. Users manually contribute; no auto-transfer engine in V1.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | TEXT | PK | UUID v4 |
| owner_user_id | TEXT | NOT NULL, FK → users.id | |
| household_id | TEXT | nullable, FK → households.id | NULL = personal goal |
| name | TEXT | NOT NULL | |
| goal_type | TEXT | NOT NULL, CHECK | `'emergency_fund'`, `'savings'`, `'travel'`, `'debt_payoff'`, `'custom'` |
| target_amount | REAL | NOT NULL | |
| current_amount | REAL | NOT NULL, default 0 | |
| target_date | INTEGER | nullable | ISO 8601 date |
| created_at | INTEGER | NOT NULL | |
| updated_at | INTEGER | NOT NULL | |
| sync_status | TEXT | NOT NULL, default `'local_only'` | |
| last_synced_at | INTEGER | nullable | |

**Indexes:** `idx_goals_owner` on `owner_user_id`, `idx_goals_type` on `goal_type`.

---

### 3.12 `recurring_templates`

Recurring transaction templates. Templates create reminders and suggested entries — they do NOT auto-create finalized transactions.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | TEXT | PK | UUID v4 |
| account_id | TEXT | NOT NULL, FK → accounts.id | |
| category_id | TEXT | nullable, FK → categories.id | |
| payee_id | TEXT | nullable, FK → payees.id | |
| amount | REAL | NOT NULL | |
| recurrence_rule | TEXT | NOT NULL | ISO 8601 duration or RRULE string |
| reminder_enabled | INTEGER | NOT NULL, default 1 | Boolean |
| auto_create_disabled | INTEGER | NOT NULL, default 0 | Boolean — 1 = reminder only, no suggested entry |
| next_occurrence_at | INTEGER | nullable | Pre-computed next date |
| created_at | INTEGER | NOT NULL | |
| updated_at | INTEGER | NOT NULL | |
| sync_status | TEXT | NOT NULL, default `'local_only'` | |
| last_synced_at | INTEGER | nullable | |

**Indexes:** `idx_recurring_account` on `account_id`, `idx_recurring_next` on `next_occurrence_at`.

---

## 4. Local-Only Tables (4)

These tables do NOT carry sync fields. Their data is device-local and rebuilt or lost on reset.

---

### 4.1 `account_balance_snapshots`

Optional optimisation table for fast historical balance charts and net worth timelines. Data is derived from transactions and can be rebuilt.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | TEXT | PK | UUID v4 |
| account_id | TEXT | NOT NULL, FK → accounts.id | |
| balance | REAL | NOT NULL | Snapshot balance |
| snapshot_at | INTEGER | NOT NULL | ISO 8601 |

**Indexes:** `idx_snapshots_account_date` on `(account_id, snapshot_at)`.

---

### 4.2 `notifications`

Local-first reminder system. Notifications are scheduled locally on device. Future cloud push (FCM) will be an optional layer.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | TEXT | PK | UUID v4 |
| notification_type | TEXT | NOT NULL, CHECK | `'recurring_reminder'`, `'bill_due'`, `'installment_due'`, `'debt_reminder'`, `'subscription_reminder'` |
| related_entity_id | TEXT | nullable | UUID of the related entity (transaction, debt, etc.) |
| scheduled_at | INTEGER | NOT NULL | ISO 8601 |
| is_completed | INTEGER | NOT NULL, default 0 | Boolean |
| created_at | INTEGER | NOT NULL | |

**Indexes:** `idx_notifications_scheduled` on `scheduled_at`, `idx_notifications_type` on `notification_type`.

---

### 4.3 `ai_processing_logs`

Stores AI extraction and categorisation metadata for debugging, transparency, and auditability. Read-only for users; written by the AI module.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | TEXT | PK | UUID v4 |
| source_type | TEXT | NOT NULL | e.g. `'ocr'`, `'nlp'`, `'categorization'` |
| source_reference_id | TEXT | nullable | UUID of the related entity (transaction, receipt) |
| model_used | TEXT | nullable | Model name e.g. `'gemma-4-e4b-it'` |
| extracted_payload | TEXT | nullable | JSON — the raw AI output |
| confidence_score | REAL | nullable | 0.0–1.0 |
| created_at | INTEGER | NOT NULL | |

**Indexes:** `idx_ai_logs_source` on `source_type`, `idx_ai_logs_reference` on `source_reference_id`.

---

### 4.4 `sync_metadata`

Simple key-value table for sync bookkeeping. Stores sync timestamps, status, and error counts. NOT syncable — this data is device-local. Referenced by the sync engine (`sync-engine.md` §10) and exposed by the sync health provider (`state-management.md` §4.5).

| Column | Type | Constraints | Notes |
|---|---|---|---|
| key | TEXT | PK | e.g. `last_synced_at`, `sync_failed_count` |
| value | TEXT | NOT NULL | Serialized value (string, number, etc.) |

**Keys stored:**

| Key | Value format | Notes |
|---|---|---|
| `last_synced_at` | ISO 8601 | Last successful pull timestamp |
| `last_sync_attempt_at` | ISO 8601 | Last sync cycle start time |
| `last_sync_status` | string | `success` / `partial` / `failed` |
| `last_sync_error` | string | Error message if last sync failed |
| `sync_failed_count` | integer | Number of records in `sync_failed` |

---

## 5. Relationship Summary

```
users ──── household_members ──── households
  │                                  │
  ├── accounts                        ├── accounts (shared)
  ├── transactions                   ├── budgets (shared)
  ├── budgets                        ├── goals (shared)
  ├── debt_records
  ├── goals
  └── recurring_templates

accounts ──── transactions
accounts ──── transfers (source)
accounts ──── transfers (destination)
accounts ──── account_balance_snapshots

categories ──── transactions
categories ──── budgets

payees ──── transactions

transactions ──── transactions (parent_transaction_id, self-ref)
transactions ──── recurring_templates
```

---

## 6. Drift ORM Notes

### 6.1 Type Mappings

| SQLite Type | Dart Type | Drift Annotation |
|---|---|---|
| TEXT (UUID) | `String` | `TextColumn` |
| REAL | `double` | `RealColumn` |
| INTEGER (boolean) | `bool` | `IntColumn` with `@BoolConverter()` |
| TEXT (timestamp) | `DateTime` | `DateTimeColumn` — stored as INTEGER (Unix seconds) |
| TEXT (JSON) | `String` or custom type | `TextColumn` with custom `TypeConverter<Map<String, dynamic>, String>` |

### 6.2 Nullable FK Workaround

Drift requires foreign-key columns to be non-nullable for certain queries. Use `@Reference(mapTo: ...)` or handle nullable FKs with `?` on the Dart field and `IntColumn.nullable()` / `TextColumn.nullable()`.

### 6.3 Index Naming

Drift uses `indexName` on `@Index` annotations. Name indexes descriptively (e.g. `idx_transactions_account_id`).

### 6.4 Migration Strategy

| Approach | Recommendation |
|---|---|
| Schema versioning | Use `Migrations` with `onUpgrade` callbacks. Start at version 1. Current: v2 (adds `budgets.icon`, `budgets.color`). |
| Schema changes | Always add, never drop columns in V1. Soft deletes (`deleted_at`) handle removal. |
| Seed data | Categories are seeded in a post-migration callback via `batchInsert`. |
| Testing | In-memory `NativeDatabase` per test suite. Apply migrations in `setUp`. |

### 6.5 Generated Code

Drift generates data classes (`Users`, `Account`, etc.) and companion classes (`UsersCompanion`). The generated file is `database.drift.dart`. Never manually edit generated code.

---

## 7. Index Summary

| Table | Index | Columns |
|---|---|---|
| users | idx_users_email | email |
| households | idx_households_created_by | created_by_user_id |
| household_members | idx_hh_members_household | household_id |
| household_members | idx_hh_members_user | user_id |
| accounts | idx_accounts_owner | owner_user_id |
| accounts | idx_accounts_household | household_id |
| accounts | idx_accounts_type | account_type |
| transactions | idx_transactions_account | account_id |
| transactions | idx_transactions_category | category_id |
| transactions | idx_transactions_payee | payee_id |
| transactions | idx_transactions_parent | parent_transaction_id |
| transactions | idx_transactions_occurred_at | occurred_at |
| transactions | idx_transactions_direction | transaction_direction |
| transfers | idx_transfers_source | source_account_id |
| transfers | idx_transfers_dest | destination_account_id |
| transfers | idx_transfers_occurred_at | occurred_at |
| categories | idx_categories_parent | parent_category_id |
| payees | idx_payees_normalized | normalized_name |
| budgets | idx_budgets_owner_period | (owner_user_id, month, year) |
| debt_records | idx_debt_owner | owner_user_id |
| debt_records | idx_debt_status | status |
| goals | idx_goals_owner | owner_user_id |
| goals | idx_goals_type | goal_type |
| recurring_templates | idx_recurring_account | account_id |
| recurring_templates | idx_recurring_next | next_occurrence_at |
| account_balance_snapshots | idx_snapshots_account_date | (account_id, snapshot_at) |
| notifications | idx_notifications_scheduled | scheduled_at |
| notifications | idx_notifications_type | notification_type |
| ai_processing_logs | idx_ai_logs_source | source_type |
| ai_processing_logs | idx_ai_logs_reference | source_reference_id |

---

## 8. Cashew Migration V1 Schema Amendment

This section supersedes the `REAL` money, one-amount transfer, and one-category monthly budget shapes above for schema version 3 and later. References: `cashew-data-migration.md §8–15`.

### 8.1 Exact money representation

Every monetary field is stored as:

| **Column** | **Type** | **Rule** |
|---|---|---|
| `*_atoms` | TEXT | Canonical signed or magnitude `BigInt` coefficient; no leading zeroes except `0` |
| `*_scale` | INTEGER | Decimal places, 0–18; imported account precision is preserved |
| `*_currency` | TEXT | Opaque nonblank source/ISO identifier |

Dart calculation uses `BigInt`, aligns scales before same-currency arithmetic, and rejects cross-currency addition. Legacy `REAL` columns remain only for additive migration compatibility and are no longer authoritative after exact values are backfilled.

### 8.2 Financial table additions

- `accounts`: `balance_atoms`, `currency_scale`, `icon`, `emoji`, `color`, `sort_order`.
- `transactions`: `amount_atoms`, `amount_scale`, `currency_code_snapshot`, `source_title`.
- `transfers`: `source_amount_atoms`, `source_scale`, `source_currency`, `destination_amount_atoms`, `destination_scale`, `destination_currency`, plus exact source-currency fee fields. Same-currency legs must be equal after scale alignment.
- `budgets`, `goals`, `debt_records`, `recurring_templates`, and `account_balance_snapshots`: exact amount/currency fields matching §8.1.

### 8.3 Queryable behavior tables

| **Table** | **Purpose** | **Key fields** |
|---|---|---|
| `budget_account_memberships` | Include/exclude accounts, including unresolved imports | budget, account nullable, source locator, mode, review state |
| `budget_category_memberships` | Include/exclude categories | budget, category nullable, source locator, mode, review state |
| `budget_transaction_memberships` | Explicitly attach/exclude transactions | budget, transaction nullable, source locator, mode |
| `recurring_occurrences` | Due/resolution history | template, transaction nullable, status, due/resolved/original due, source series/occurrence |
| `goal_events` | Immutable contribution/adjustment ledger | goal, transaction nullable, exact amount/currency, event type/time |
| `debt_events` | Immutable payment/adjustment ledger | debt, transaction nullable, exact amount/currency, event type/time |
| `categorization_rules` | Durable title/payee suggestions | field, match kind, pattern, category, active/archive, priority |

Budgets store period type (`monthly` or `custom`), start/end/cycle fields, direction filter, explicit-only flag, currency, imported/read-only flag, and review state. The old owner/category/month uniqueness constraint no longer defines budget identity.

### 8.4 Local-only migration and recovery tables

`import_runs`, `import_source_entities`, `import_source_relations`, `import_mappings`, `import_discrepancies`, `import_preserved_payloads`, `import_checkpoints`, and `rollback_checkpoints` are local-only and excluded from sync. Disposition is constrained to `exact_import`, `transformed_import`, `preserved_only`, `review_required`, `ignored_safe`, or `invalid_blocking`.

Backups include every syncable and local-only table required to reproduce the ledger, provenance, preservation archive, and rollback state. Backup manifests record format/schema version, cipher/KDF metadata, created time, and payload hash without private row content.

### 8.5 Migration strategy

Schema v3 is additive: add exact columns/tables, backfill legacy values deterministically, verify exact reconstructed balances, then switch repositories/providers to exact columns. New databases create only authoritative exact behavior. Migration tests cover v1→v2→v3, foreign keys, wrong-key rejection, rollback, and backup restore.

# Cashew-to-Lootr Migration Research — Personal Finance App

Loss-minimizing migration assessment for moving an existing Cashew dataset into Lootr.

References: `database-schema.md` (Lootr target schema), `domain-model.md` (target semantics), `security-model.md` (data-at-rest requirements), Cashew source snapshot `9cfbe50c16d95429891d44faf5f2c77a3abdb93b` (app version `5.4.3+416`, database schema version `46`).

---

## 1. Executive Recommendation

Build the V1 migration around a **Cashew raw database export**, not Cashew CSV.

The recommended path is:

1. Export Cashew's data file immediately before switching apps.
2. Treat the exported `.sql` file as SQLite bytes; never parse it as SQL text.
3. Copy it into a private staging area, fingerprint it, and open it read-only.
4. Run a dry-run analysis that classifies every source row as:
   - exact first-class import;
   - transformed first-class import;
   - preserved-only because Lootr has no equivalent;
   - blocked or ambiguous and requiring review.
5. Show reconciliation totals and all lossy decisions before writing.
6. Apply the import and its provenance records in one target-database transaction.
7. Once Lootr's specified SQLCipher layer is active, keep a user-controlled encrypted import archive until the user explicitly purges it. Before then, do not retain unsupported payloads without a clear plaintext-at-rest disclosure.

Four requirements should be considered migration blockers rather than polish:

- a durable `import_provenance` mapping, so rerunning the same import cannot duplicate data;
- a preserved-payload store for source fields Lootr cannot represent;
- explicit handling for cross-currency transfers, which Lootr's current single-amount transfer shape cannot faithfully represent;
- a real export from the user's installed Cashew app to validate schema, timestamps, recurrence chains, transfer pairing, debt usage, and attachment links.

**Do not use Cashew CSV as the primary migration source.** Cashew's CSV export only selects rows where `paid = true`, and emits a projection without source IDs, recurrence state, transfer pairing, timestamps for modification, budget definitions, category hierarchy IDs, settings, or source relationships. Verified in Cashew `budget/lib/widgets/exportCSV.dart:77-151`.

---

## 2. Evidence Labels and Scope

This document uses three labels:

| Label | Meaning |
|---|---|
| **Verified** | Directly supported by the checked-in Cashew or Lootr source at the snapshots above. |
| **Inference** | A migration interpretation supported by source behavior but not guaranteed for every historical user database. |
| **Decision** | Recommended Lootr behavior; not a claim about either existing app. |

The Cashew repository describes the current schema, but a user's installed database may have passed through older migrations and contain historical edge cases. Source review cannot replace a real export audit.

---

## 3. Source Acquisition Options

### 3.1 Preferred: Cashew “Export data file”

**Verified.** Cashew calls `backupSettings()`, reads the current database file as bytes, and saves it with a `cashew-... .sql` filename. It is a binary database copy, not a SQL dump (`budget/lib/widgets/exportDB.dart:11-44`).

**Verified.** On native platforms the source file is `db.sqlite` in the application documents directory, opened by Drift through `NativeDatabase`; `getCurrentDBFileInfo()` reads that file directly (`budget/lib/database/platform/native.dart:10-36`).

**Decision.** The importer must:

- check for the SQLite header before doing anything else;
- copy the selected file into app-private temporary storage;
- open the copy read-only;
- never modify or migrate the source file in place;
- compute SHA-256 before reading any records.

### 3.2 Also acceptable: downloaded Cashew Google Drive backup

**Verified.** Cashew cloud backups upload the same database bytes into Google Drive `appDataFolder`, usually as `db-v{schema}-{device}.sqlite`; downloading one renames the bytes to a `.sql` file (`budget/lib/widgets/accountAndBackup.dart:390-440`, `1507-1532`).

**Decision.** Prefer the newest manual export over an older cloud backup. If the user selects a cloud backup, show its embedded `PRAGMA user_version`, row counts, and most recent transaction modification time before continuing.

### 3.3 Advanced recovery: direct `db.sqlite`

**Verified.** The native database path is the app documents directory plus `db.sqlite` (`budget/lib/database/platform/native.dart:13-21`, `26-36`).

**Decision.** Direct sandbox extraction is a recovery path only. It is platform-specific and easy to get wrong. The normal UI should not instruct users to root, jailbreak, or modify Cashew's sandbox.

### 3.4 Degraded fallback: Cashew CSV

**Verified.** Cashew CSV contains these columns:

`account`, `amount`, `currency`, `title`, `note`, `date`, `income`, `type`, `category name`, `subcategory name`, `color`, `icon`, `emoji`, `budget`, `objective`

(`budget/lib/widgets/exportCSV.dart:105-150`).

**Verified.** Only `paid = true` rows are exported (`budget/lib/widgets/exportCSV.dart:84-95`).

**Decision.** CSV fallback may import finalized transaction history, categories, account names, and inferred payees. It must display a permanent warning that it cannot preserve:

- source IDs or modification timestamps;
- transfer links;
- recurrence chains and future occurrences;
- unpaid/upcoming/skipped state;
- budget definitions and category limits;
- objectives as definitions;
- exact sharing metadata;
- associated-title rules, scanner templates, delete logs, or settings.

### 3.5 Live-copy consistency risk

**Verified.** Both local export and cloud backup read `db.sqlite` bytes directly; the export path does not explicitly close the database or issue a WAL checkpoint in the cited code (`budget/lib/database/platform/native.dart:26-36`; `budget/lib/widgets/exportDB.dart:11-36`; `budget/lib/widgets/accountAndBackup.dart:390-440`).

**Inference.** Depending on SQLite journal mode and outstanding writes, a live byte copy could theoretically omit uncheckpointed WAL content.

**Decision.** In migration instructions, ask the user to:

1. finish any Cashew edits;
2. wait for the save to complete;
3. restart Cashew once;
4. create a fresh manual export;
5. keep the original until Lootr reconciliation passes.

The importer must run `PRAGMA quick_check`, `PRAGMA integrity_check`, and relationship audits. A second export should be requested if the file is inconsistent.

---

## 4. Verified Cashew Storage Model

### 4.1 Database identity and enums

**Verified.** The reviewed Cashew code declares database schema version `46` (`budget/lib/database/tables.dart:29`, `696-699`).

**Verified.** Important enum ordinals at that snapshot are:

| Stored integer | Enum | Meaning |
|---:|---|---|
| 0 | `BudgetReoccurence.custom` | Custom period |
| 1 | `BudgetReoccurence.daily` | Every N days |
| 2 | `BudgetReoccurence.weekly` | Every N weeks |
| 3 | `BudgetReoccurence.monthly` | Every N months |
| 4 | `BudgetReoccurence.yearly` | Every N years |
| 0 | `TransactionSpecialType.upcoming` | One-time upcoming item |
| 1 | `TransactionSpecialType.subscription` | Repeating subscription |
| 2 | `TransactionSpecialType.repetitive` | Other repeating item |
| 3 | `TransactionSpecialType.credit` | Lent / receivable |
| 4 | `TransactionSpecialType.debt` | Borrowed / payable |
| 0 | `ObjectiveType.goal` | Savings/target objective |
| 1 | `ObjectiveType.loan` | Long-term social loan ledger |
| 0 | `PaidStatus.paid` | UI filter value |
| 1 | `PaidStatus.notPaid` | UI filter value |
| 2 | `PaidStatus.skipped` | UI filter value |

Source: `budget/lib/database/tables.dart:42-71`.

**Blocker.** These ordinal meanings must be selected by the exported database's `PRAGMA user_version`, not blindly assumed from the current source. A sample export is required to verify compatibility with the user's installed build.

### 4.2 Source tables and relationships

**Verified.** The current Cashew database registers ten tables (`budget/lib/database/tables.dart:679-691`):

| Cashew table | Primary role | Important relationships |
|---|---|---|
| `wallets` | Account-like containers | Referenced by transactions, budgets, limits, objectives, templates |
| `transactions` | Signed financial rows plus planned/recurring/debt state | Category, subcategory, wallet, paired transaction, goal/loan objective |
| `categories` | Income/expense hierarchy and visuals | `main_category_pk` self-reference |
| `category_budget_limits` | Per-category allocation inside a Cashew budget | Category, budget, wallet |
| `associated_titles` | Title-to-category categorization rules | Category |
| `budgets` | Flexible date-range/repeating budget definition | Lists of wallets/categories plus filters |
| `app_settings` | Serialized `userSettings` JSON | One effective settings row |
| `scanner_templates` | Email parsing rules | Default category and wallet |
| `delete_logs` | Sync deletion tombstones | Source table kind plus deleted source PK |
| `objectives` | Goals and long-term loan ledgers | Wallet; linked from transactions |

The generated SQLite names are confirmed in `budget/lib/database/tables.g.dart:109-110`, `688-689`, `1298-1299`, `2164-2165`, `3645-3646`, `4781-4782`, `5152-5153`, `5516-5517`, `5826-5827`, and `6386-6387`.

### 4.3 Wallets

**Verified.** A wallet stores UUID-like text PK, name, color, icon name, created/modified timestamps, order, currency, currency-format preference, decimal count, and dashboard-widget selection. It does **not** store an account type or balance (`budget/lib/database/tables.dart:250-271`).

**Verified.** Cashew derives a wallet total by summing `transactions.amount` where `paid = true` for the wallet (`budget/lib/database/tables.dart:6767-6786`).

### 4.4 Transactions

**Verified.** Cashew transactions contain:

- source PK and optional `paired_transaction_fk`;
- name/title, signed REAL amount, note;
- category, optional subcategory, and wallet;
- created and modified dates, plus original due date;
- redundant `income` flag;
- recurrence interval, end date, notification flag, and special type;
- `paid`, `created_another_future_transaction`, and `skip_paid`;
- import/share ownership fields;
- goal and loan-objective links;
- budget exclusions.

Source: `budget/lib/database/tables.dart:273-340`.

**Verified.** New normal transactions are signed from the direction: income is positive and expense is negative (`budget/lib/pages/addTransactionPage.dart:651-669`).

**Verified.** Transaction `name` is the title shown to the user; Cashew has no separate merchant/payee table.

### 4.5 Transfers and balance corrections

**Verified.** Cashew stores balance transfers as two ordinary transactions in category PK `"0"`. The destination and source rows have opposite signs, are normally one second apart, and one row points to the other through `paired_transaction_fk` (`budget/lib/pages/addWalletPage.dart:1181-1207`; `985-1018`).

**Verified.** Cross-currency transfer rows can have different absolute amounts because each side is converted into its wallet currency (`budget/lib/struct/currencyFunctions.dart:149-174`; `budget/lib/pages/addWalletPage.dart:1181-1200`).

**Verified.** Category PK `"0"` is the balance-correction category (`budget/lib/pages/addWalletPage.dart:958-981`; `budget/lib/database/tables.dart:6259-6265`).

### 4.6 Recurring, subscription, and upcoming rows

**Verified.** Subscription and repetitive rows generate the next row by copying the current transaction and advancing its date by `period_length × recurrence unit` (`budget/lib/struct/upcomingTransactionsFunctions.dart:21-47`, `98-107`).

**Verified.** Generated recurring IDs use:

`{base-source-id}::predict::{occurrence-number}`

This exists to prevent duplicates during Cashew sync (`budget/lib/struct/upcomingTransactionsFunctions.dart:192-211`).

**Verified.**

- paid occurrences have `paid = true`;
- the newly generated future occurrence has `paid = false`;
- `created_another_future_transaction` records whether the row spawned its successor;
- paying may move `date_created` to the payment time while `original_date_due` retains the old due time;
- skipped occurrences use `skip_paid = true`.

Source: `budget/lib/database/tables.dart:298-317`; `budget/lib/struct/upcomingTransactionsFunctions.dart:291-354`.

### 4.7 Social credit/debt

**Verified.** A standalone `credit` row means lent/receivable and is an expense-sign row; a `debt` row means borrowed/payable and is an income-sign row (`budget/lib/database/tables.dart:44-50`; `budget/lib/pages/addTransactionPage.dart:252-259`).

**Verified.** For these rows, `paid = true` means the amount is still counted; full collection/settlement changes `paid` to false so the net effect becomes zero (`budget/lib/database/tables.dart:310-313`; `budget/lib/struct/upcomingTransactionsFunctions.dart:357-407`).

**Verified.** Partial settlement converts a standalone credit/debt row into an `ObjectiveType.loan` and adds signed loan-ledger transactions through `objective_loan_fk` (`budget/lib/struct/upcomingTransactionsFunctions.dart:408-506`).

### 4.8 Goals and long-term loan objectives

**Verified.** Objectives store type, name, target/offset amount, order, visuals, dates, income polarity, pin/archive state, and wallet (`budget/lib/database/tables.dart:513-539`).

**Verified.** A goal's progress is computed by summing paid transactions linked with `objective_fk`; a loan objective uses `objective_loan_fk` (`budget/lib/database/tables.dart:5650-5671`).

### 4.9 Budgets

**Verified.** A Cashew budget can have:

- arbitrary start/end dates;
- custom, daily, weekly, monthly, or yearly recurrence;
- multiple wallets;
- included and excluded category lists;
- income or expense direction;
- archived, pinned, and “added transactions only” flags;
- transaction filters;
- sharing fields and member filters;
- absolute-spending-limit behavior.

Source: `budget/lib/database/tables.dart:422-475`.

**Verified.** Per-category allocations are separate `category_budget_limits` rows and carry their own wallet currency context (`budget/lib/database/tables.dart:375-388`).

### 4.10 Categories, rules, and icons

**Verified.** Categories store an income flag, optional parent, order, color, bundled asset filename, and optional emoji (`budget/lib/database/tables.dart:342-373`).

**Verified.** `associated_titles` map a title substring or exact title to a category and are used as smart categorization rules (`budget/lib/database/tables.dart:390-408`).

**Verified.** Active transaction labels/custom fields do not exist in the current table list; old label code is commented out (`budget/lib/database/tables.dart:290-291`, `410-420`, `679-691`).

### 4.11 Settings and non-database preferences

**Verified.** Before a raw export, Cashew serializes the `userSettings` shared-preference JSON into `app_settings.settings_json` (`budget/lib/struct/settings.dart:323-335`; `budget/lib/widgets/exportDB.dart:11-20`).

Relevant migration settings include:

- selected wallet;
- locale and 12/24-hour choice;
- notification behavior;
- cached USD-based exchange rates;
- custom currency keys and USD-based custom rates;
- number-format preferences;
- long-term-loan feature flag.

Source: `budget/lib/struct/defaultPreferences.dart:24-31`, `118-122`, `148-161`, `188-194`, `218-236`.

**Verified.** Bill-splitter draft people, items, and multiplier are stored in separate shared-preference keys, not in the FinanceDatabase tables (`budget/lib/pages/billSplitter.dart:443-550`).

**Blocker.** A normal Cashew raw export does not include those separate bill-splitter draft values. Already-generated loan transactions remain importable; unfinished bill-splitter drafts require a separate Cashew-side export feature or manual recreation.

### 4.12 Attachments

**Verified.** Cashew uploads photos/documents to a Google Drive folder named `Cashew` and receives a Drive `webViewLink` (`budget/lib/struct/uploadAttachment.dart:107-166`).

**Verified.** That URL is appended as plain text to the transaction note; there is no attachment table in the registered database (`budget/lib/pages/addTransactionPage.dart:4303-4311`, `4409-4517`; `budget/lib/database/tables.dart:679-691`).

**Consequence.** The raw database preserves attachment links, but not attachment bytes. Link access remains dependent on the user's Google account and the Drive file still existing.

---

## 5. Lootr Target Constraints and Readiness Gaps

### 5.1 Directly compatible target concepts

Lootr already has first-class tables for accounts, transactions, transfers, hierarchical categories, payees, monthly category budgets, social debt records, goals, and recurring templates (`database-schema.md §3.4-§3.12`; implementations in `lib/data/database/tables/`).

### 5.2 Important representational gaps

| Cashew concept | Lootr current limitation | Migration impact |
|---|---|---|
| Wallet appearance/order/decimals | `accounts` has no icon, color, display order, or decimal precision (`lib/data/database/tables/accounts.dart:9-32`) | Preserve fields; optionally extend account schema |
| Cross-currency transfer | `transfers` has one `amount` and no destination amount/rate (`lib/data/database/tables/transfers.dart:8-30`) | Cannot preserve both wallet balances exactly without schema change |
| Transaction title | Lootr has normalized payee plus note, but no free title (`lib/data/database/tables/transactions.dart:15-44`) | Map title to payee and retain exact title in provenance |
| One-off upcoming item | No planned-transaction entity | Preserve-only or add planned entry support |
| Recurring direction/type/end metadata | Template lacks explicit direction, subtype, title, end date, source series ID (`lib/data/database/tables/recurring_templates.dart:9-31`) | Encode what fits in category/payee/RRULE; preserve remainder |
| Goal contribution history | `goals` stores only `current_amount`; transaction has no `goal_id` (`lib/data/database/tables/goals.dart:8-30`) | Current amount can migrate, but contribution linkage cannot be first-class |
| Debt payment history | `debt_records` has aggregate balance; transaction has no `debt_record_id` (`lib/data/database/tables/debt_records.dart:7-31`) | Preserve ledger linkage or add relation |
| Flexible/repeating multi-category budget | Lootr budget is one category and one month/year (`lib/data/database/tables/budgets.dart:9-35`) | Requires expansion policy; filters/sharing cannot map exactly |
| Attachments | No local attachment table | Keep URLs in notes; bytes need later feature |
| Associated-title and scanner rules | No rule tables | Preserve-only in V1 |
| Sharing provenance | Lootr household model does not directly represent a Cashew shared-budget snapshot | Personalize with explicit warning or defer |
| Import idempotency/audit | No import-run or source-provenance tables | Must add before a safe importer |

### 5.3 Current encryption implementation gap

**Verified.** Lootr's security spec requires SQLCipher (`security-model.md §4.1-§4.2`), but the current default connection uses `driftDatabase(name: 'lootr')` without the specified key setup (`lib/data/database/app_database.dart:43-55`).

**Decision.** Do not market preserved import payloads as encrypted until SQLCipher is actually wired and tested. Until then, offer either:

- import without retaining source payloads after a verified migration; or
- explicit disclosure that the app-private database is not yet encrypted at rest.

---

## 6. Canonical Staging Representation

### 6.1 Why staging is mandatory

Cashew rows often fan out or collapse:

- two Cashew transfer rows become one Lootr transfer;
- many recurrence occurrences become one template plus historical transactions;
- a goal definition plus linked rows becomes a goal aggregate plus preserved contribution provenance;
- a flexible budget may become several monthly category budgets;
- unsupported rows still need durable preservation.

Direct source-to-target inserts would make review, retry, and rollback unreliable.

### 6.2 Recommended local-only staging tables

Use a separate temporary SQLite file during analysis and add durable provenance/archive tables to Lootr.

```text
migration_run
  run_id
  source_system                 "cashew"
  source_sha256
  source_filename
  source_schema_version
  source_app_version            nullable
  assumed_timezone
  state                         staged|reviewed|applying|complete|failed|rolled_back
  policy_json
  counts_json
  started_at / completed_at

staged_record
  run_id
  source_table
  source_pk
  raw_payload_json
  raw_payload_sha256
  canonical_kind
  canonical_payload_json
  disposition                   import|preserve|review|error
  issue_code                    nullable

staged_relation
  run_id
  source_from_table / source_from_pk
  relation_kind
  source_to_table / source_to_pk

staged_issue
  run_id
  severity                      info|warning|blocking
  issue_code
  source_locator
  message
  proposed_resolution_json
```

Durable target-side records:

```text
import_provenance
  id                            UUID v4
  run_id
  source_system
  source_fingerprint
  source_entity_type
  source_entity_id
  source_payload_sha256
  target_table
  target_id
  imported_target_sha256
  imported_at
  UNIQUE(source_system, source_fingerprint, source_entity_type, source_entity_id, target_table, target_id)

import_preserved_payload
  id                            UUID v4
  run_id
  source_locator
  payload_json
  reason_code
  related_target_table          nullable
  related_target_id             nullable
  created_at
```

### 6.3 Canonical transaction shape

Every staged financial row should preserve both interpreted and raw values:

```json
{
  "source": {
    "table": "transactions",
    "pk": "cashew-id",
    "rawAmount": "-123.45",
    "rawDateCreated": 0,
    "rawDateTimeModified": 0,
    "rawPayloadSha256": "..."
  },
  "money": {
    "magnitude": "123.45",
    "direction": "expense",
    "currency": "PHP",
    "walletDecimals": 2
  },
  "time": {
    "sourceWallTime": "2026-07-18T14:30:00",
    "assumedZone": "Asia/Manila",
    "utc": "2026-07-18T06:30:00Z"
  },
  "classification": {
    "kind": "transaction",
    "specialType": null,
    "paid": true,
    "skipped": false,
    "confidence": "exact"
  },
  "relationships": {
    "walletPk": "...",
    "categoryPk": "...",
    "subcategoryPk": null,
    "pairedTransactionPk": null,
    "objectivePk": null,
    "objectiveLoanPk": null
  }
}
```

Store decimal values as strings in staging. Convert to target REAL only at the final boundary.

---

## 7. Entity and Field Mapping

### 7.1 Core mapping matrix

| Cashew source | Lootr target | V1 mapping | Loss/preservation rule |
|---|---|---|---|
| `wallets.wallet_pk` | `accounts.id` | New UUID v4 recorded in provenance | Never reuse raw source PK as target ID |
| Wallet name | `accounts.name` | Exact text | — |
| Wallet currency | `accounts.currency_code` | Uppercase valid ISO 4217 | Custom/non-ISO key requires review and preserved raw value |
| Wallet balance | `accounts.balance` | Recalculate from imported transactions and transfers | Compare against Cashew paid-row sum |
| Wallet type | `accounts.account_type` | User-reviewed suggestion | No Cashew source field |
| Wallet color/icon/order/decimals | No current target | Preserve payload | Candidate V1 schema extension |
| `categories.category_pk` | `categories.id` | UUID v4 via provenance | — |
| `main_category_pk` | `parent_category_id` | Map after all categories stage | Orphan becomes root plus blocking warning |
| `income` | `category_group` | true → `income`, false → `expense`; PK `0` handled specially | Preserve raw |
| `icon_name` / `emoji_icon_name` | `categories.icon` | Prefer emoji when nonblank; otherwise asset identifier | Preserve both raw fields |
| Transaction title | `payees.display_name` | Exact display text; normalized for `normalized_name` | Preserve exact title because “payee” is an inference |
| Signed amount | `transactions.amount` + direction | `abs(amount)` plus sign/direction | Sign/`income` mismatch is review-blocking |
| `date_created` | `occurred_at` | Interpret as source wall time in chosen timezone, convert to UTC | Preserve raw encoding and wall time |
| `date_time_modified` | `updated_at` | Converted to UTC; fallback to occurred/import time with warning | — |
| Transaction note | `transactions.note` | Exact text, including attachment URLs | Do not strip Drive links |
| Category/subcategory | `category_id` | Prefer subcategory target when present; its parent remains queryable | Preserve both source links |
| Normal paid row | `transactions` | One-time finalized transaction | `sync_status = local_only` |
| Recurring paid occurrence | `transactions` | `mode = recurring`, link to imported template | Preserve due date and series source |
| Subscription occurrence | `transactions` | `mode = recurring`, subtype `subscription` | — |
| Paired category-0 rows | `transfers` | Collapse when pairing and currency rules pass | Preserve both source rows/provenance links |
| Unpaired category-0 row | `transactions` | Earliest qualifying row may be `opening_balance`; later row is one-time adjustment with metadata | Current subtype lacks balance-adjustment value |
| Standalone credit/debt row | `debt_records`, optionally history transaction | Map active/settled state from Cashew paid semantics | Preserve source transaction details |
| Goal objective | `goals` | target, current aggregate, target date, custom type | Visuals, archive, wallet association preserved only |
| Loan objective | `debt_records` | counterparty, direction, original/net remaining | Ledger rows preserved and optionally imported as debt-mode transactions |
| Budget | `budgets` | Only exact monthly/single-category cases map directly | Others expanded by approved policy or preserved-only |
| Category budget limit | `budgets` | Candidate monthly category amount | Must respect source wallet currency |
| Associated title | No target | Preserve; later categorization-rule import | Do not silently turn every rule into a payee |
| Scanner template | No target | Preserve | Contains parsing delimiters and default category/wallet |
| App settings | User/profile/import policy | Import safe subset only | Archive full JSON; exclude auth/sync/purchase flags |
| Delete logs | No business target | Preserve as source audit | Do not create Lootr soft deletes without mapped live rows |
| Sharing fields | Household models | Defer by default | Preserve emails, keys, members, owner/member status |

### 7.2 Transaction metadata envelope

For every imported transaction, use the existing `metadata` JSON field to retain non-sensitive migration context:

```json
{
  "import": {
    "source": "cashew",
    "runId": "...",
    "sourceTransactionPk": "...",
    "sourceType": "subscription",
    "sourcePaid": true,
    "sourceSkipped": false,
    "sourceOriginalDateDue": "...",
    "sourceTitle": "...",
    "sourceObjectivePk": null,
    "sourceObjectiveLoanPk": null
  }
}
```

Do not put full sharing emails, Google Drive OAuth data, or the full settings JSON into every transaction. Those belong in the protected preserved-payload store.

---

## 8. Deterministic Identity, Idempotency, and Duplicates

### 8.1 Target IDs

Lootr specifies UUID v4 primary keys (`database-schema.md §2`). Keep that rule.

**Decision.** Generate target UUID v4 values once during staging, then persist the source-to-target map in `import_provenance`. “Deterministic” means stable for a given staged run and source fingerprint, not a hash disguised as UUID v4.

### 8.2 Import identity

The canonical identity key is:

```text
(source_system, source_sha256, source_table, source_pk, target_table, mapping_role)
```

`mapping_role` distinguishes fan-out/collapse cases such as:

- `transfer`;
- `historical_transaction`;
- `recurring_template`;
- `goal`;
- `debt_record`.

### 8.3 Re-import policy

1. Same source fingerprint + same source row hash: skip.
2. Same source fingerprint + changed source row hash:
   - update only if target still matches `imported_target_sha256`;
   - otherwise show a conflict and keep the user's Lootr edit by default.
3. Different source fingerprint:
   - use embedded Cashew source PKs to propose continuation;
   - never auto-merge if a source PK maps to materially different content.
4. CSV fallback:
   - no stable source PK exists;
   - derive a candidate fingerprint from account, amount, currency, exact timestamp, title, category, note;
   - show possible duplicates and require review for collisions.

### 8.4 Payee/category deduplication

- Payees: normalize Unicode, trim, lowercase, collapse internal whitespace. Do not strip punctuation beyond Lootr's documented normalizer.
- Categories: source PK is authoritative. Do not merge same-name categories automatically; Cashew can distinguish income/expense and parent contexts.
- Accounts: source PK is authoritative. Never merge by name alone.
- Transactions: provenance is authoritative. Similarity matching is advisory only.

---

## 9. Transformation Rules for Difficult Domains

### 9.1 Direction and amount precision

**Verified.** Cashew stores signed REAL amounts; Lootr stores positive REAL amounts with an explicit direction (`budget/lib/database/tables.dart:280-303`; `lib/data/database/tables/transactions.dart:22-24`).

Rules:

1. Read the SQLite REAL and serialize with enough significant digits for round-trip comparison.
2. Require:
   - positive amount ↔ `income = true`;
   - negative amount ↔ `income = false`;
   - zero may use `income` for direction.
3. If sign and flag disagree, quarantine the row. Do not silently “fix” financial history.
4. Target amount is the absolute source value.
5. Do not round stored values to wallet display decimals during import.
6. Use wallet `decimals` only for UI and reconciliation tolerance.
7. Compare totals using decimal arithmetic in the importer, then compare target REAL within:

```text
max(0.5 × 10^-wallet_decimals, 1e-9 × max(1, absolute_total))
```

**Future recommendation.** Consider integer minor units or decimal strings before widening currency support. Both current apps use REAL, so migration cannot recover precision already lost in the source.

### 9.2 Currency and exchange rates

**Verified.** Each Cashew wallet has currency and decimal fields (`budget/lib/database/tables.dart:261-267`).

**Verified.** Cached/custom exchange rates live in settings and are USD-referenced (`budget/lib/struct/currencyFunctions.dart:14-39`, `110-129`; `budget/lib/pages/exchangeRatesPage.dart:379-425`).

Rules:

- Never convert ordinary transaction history into the user's primary currency. Preserve amounts in the source wallet's currency.
- Import a wallet currency only if it is a valid Lootr-supported code.
- Preserve custom currency keys, custom USD rates, cached-rate snapshot, and import timestamp.
- Never recompute historical transaction amounts using today's exchange rate.
- Cross-currency transfer reconciliation uses the two source row amounts, not the cached rate.

### 9.3 Timezone and timestamps

**Verified.** Lootr requires UTC storage and application-layer locale conversion (`database-schema.md §2`).

**Verified.** Cashew has no separate timezone/offset column on transactions or wallets in the reviewed schema; application code constructs local `DateTime` values from user input (`budget/lib/database/tables.dart:250-340`; `budget/lib/pages/addTransactionPage.dart:651-669`; `budget/lib/widgets/importCSV.dart:1026-1069`).

Rules:

1. Inspect `typeof(date_created)` and the source schema/version before decoding.
2. If the value is a Unix epoch written by that Drift version, decode it as an instant with the correct seconds/milliseconds unit. Do **not** reinterpret its displayed calendar fields in another zone.
3. If the value is ISO text with `Z` or an explicit offset, parse that instant directly.
4. Only for offset-free text or a version-specific wall-time encoding, ask for the timezone in which the Cashew history was recorded; default to the device timezone and show it.
5. Preserve the source scalar/text, decoded instant, displayed source wall time, chosen zone, and offset.
6. Detect DST gaps/ambiguities when a naive wall time requires a zone. Require review when it maps to zero or two instants.
7. Verify at least one known transaction timestamp from the user's Cashew UI before applying the import.
8. `date_created` becomes `occurred_at` for finalized rows.
9. For a paid scheduled row, preserve `original_date_due` in metadata and use current `date_created` as occurrence time, matching Cashew's behavior.
10. Use `date_time_modified` for target `updated_at` when valid.

### 9.4 Transfer pairing

Pair in this order:

1. explicit `paired_transaction_fk`;
2. reciprocal relationship if both sides point;
3. predictable recurring suffix relationship;
4. conservative fallback only for category `"0"`:
   - different wallets;
   - opposite signs;
   - timestamps within two seconds;
   - compatible note/title;
   - amounts equal in same currency.

Every fallback match is reviewable and records a confidence score.

For a same-currency paid pair:

- negative row → source account;
- positive row → destination account;
- one Lootr transfer;
- target `occurred_at` is the earlier source timestamp;
- note combines exact source note plus preserved per-leg details.

For a cross-currency pair:

- **block first-class mapping under the current schema**;
- preserve both source amounts and currencies;
- offer one of:
  1. recommended schema upgrade with `source_amount`, `destination_amount`, source/destination currency snapshot, and exchange rate;
  2. preserved-only transfer, excluded from live balances until user resolves it;
  3. explicitly lossy one-amount mapping after showing the resulting balance delta.

Do not convert the pair into ordinary income/expense rows merely to make totals match; that would corrupt spending analytics and violate Lootr's dedicated-transfer decision.

### 9.5 Opening balances and later balance corrections

An unpaired category-`"0"` row is a correction, but Cashew does not explicitly distinguish “opening” from later manual correction.

**Inference.** Classify as `opening_balance` only when it is the earliest paid row for the wallet and is close to wallet creation time. Otherwise import as a normal one-time row with migration metadata `sourceKind = balance_correction`.

The dry run must show both classes because a misclassified correction changes account history presentation even if the balance is unchanged.

### 9.6 Recurrence and subscriptions

1. Derive series base from the source PK before `::predict::`.
2. Group compatible subscription/repetitive rows by:
   - base source ID;
   - wallet, category/subcategory, title;
   - amount and income direction;
   - recurrence unit/length.
3. Import paid, non-skipped occurrences as historical transactions.
4. Preserve skipped occurrences but do not finalize them.
5. Use the latest unpaid, non-skipped occurrence as `next_occurrence_at`.
6. Create one Lootr template:
   - interval → RRULE `FREQ` + `INTERVAL`;
   - Cashew end date → RRULE `UNTIL`;
   - reminder flag → `reminder_enabled`;
   - subscription → historical subtype `subscription`.
7. Link historical imported rows with `recurring_template_id`.
8. Preserve `created_another_future_transaction`, original due dates, notification flag, and source series IDs.
9. Keep Lootr's no-auto-finalization rule. Set the template to produce its normal reminder/suggestion behavior, and preserve Cashew's automatic-payment preference as source metadata rather than enabling silent financial writes.

If IDs do not contain the predictable suffix, signature grouping is an **inference** and requires user review. Never merge two recurring series only because their titles and amounts match.

One-time `upcoming` rows have no faithful target. Preserve them and either:

- add a planned-transaction entity before migration; or
- let the user explicitly convert each to a finalized transaction or reminder.

### 9.7 Debt and credit

Standalone rows:

- type `credit` → `debt_direction = lent`;
- type `debt` → `debt_direction = borrowed`;
- `paid = true` → active;
- `paid = false` → settled;
- title → counterparty candidate;
- `abs(amount)` → original amount;
- active remaining balance initially equals original amount.

Loan objectives:

1. Group all `objective_loan_fk` rows.
2. Determine direction from objective `income` and verify against ledger polarity.
3. Derive original principal from initial record(s).
4. Derive remaining balance from the signed paid ledger using the source wallet currencies and preserved conversion context.
5. Set status:
   - zero within tolerance → settled;
   - remaining smaller than principal → partially paid;
   - otherwise active.
6. Preserve every ledger row and its wallet.

**Blocker.** Lootr currently cannot link payment transactions to a debt record. To keep history first-class, add `debt_record_id` to transactions or a `debt_payments` table. Without that change, V1 can preserve the ledger and import the aggregate debt record, but its detail screen cannot reproduce Cashew's payment history exactly.

### 9.8 Goals

For `ObjectiveType.goal`:

- name → goal name;
- amount → target amount;
- end date → target date;
- use goal type `custom` unless the user chooses a more specific Lootr type;
- current amount → absolute magnitude of the signed paid-row sum, after verifying it agrees with the objective's income polarity and using the same wallet/currency policy as Cashew reconciliation;
- archive/pin/icon/color/wallet → preserved payload.

**Blocker.** Lootr has no goal-contribution relation. Add `goal_id` to transactions or a contribution table if the goal detail must preserve transaction history. Otherwise import the aggregate `current_amount` and preserve source links for a later upgrade.

### 9.9 Budgets

Exact direct mapping is allowed only when all are true:

- expense budget;
- monthly recurrence with period length 1;
- one source category or one category-limit row;
- one unambiguous wallet currency;
- no added-only, include/exclude, member, sharing, or absolute-limit semantics that change calculation.

For other budgets, offer:

- **expand current period only** into monthly category budgets;
- **expand a user-selected bounded date range**;
- **preserve definition only** for later support.

Never generate an unbounded number of monthly rows from a repeating Cashew budget.

For a budget with category limits, those limits are stronger per-category mapping evidence than dividing the overall budget equally. If category limits do not sum to the total, preserve the difference and show it.

Lootr's unique `(owner, category, month, year)` constraint means overlapping Cashew budgets can collide. Show the collision and require merge/keep-existing/replace choices.

### 9.10 Payees and transaction titles

**Inference.** The least-lossy default is to create a payee for each distinct nonblank Cashew transaction title because Lootr has no independent transaction-title field.

However, Cashew titles may be descriptions such as “Lunch,” not merchants. The review UI should offer:

- use titles as payees;
- preserve titles in note/metadata only;
- edit/merge suggested payees.

Always preserve the exact source title, even after payee normalization.

### 9.11 Attachments

V1:

- keep the Drive URL exactly where it appears in the note;
- detect and inventory likely Cashew Drive links;
- test link accessibility only after explicit user action;
- report inaccessible links without failing the financial import.

Later:

- add a local attachment entity;
- download with user-authorized Google access;
- hash bytes and store app-owned encrypted copies;
- retain the original URL and file ID as provenance;
- never make Drive files public.

---

## 10. Unsupported Data Preservation

“Unsupported” must not mean “discarded.”

Preserve exact JSON payloads for:

- all source rows before transformation;
- wallet visual/order/decimal preferences;
- budget filters, sharing data, member lists, and recurrence definitions;
- associated-title categorization rules;
- scanner/email parsing templates;
- delete logs;
- objective visuals/archive/pin/wallet fields;
- transaction sharing fields and budget exclusions;
- custom/cached exchange rates;
- app UI preferences relevant to interpreting data;
- skipped and upcoming planned rows;
- ambiguous transfer candidates;
- inaccessible attachment URLs.

The archive should be:

- local-only and excluded from V2 sync by default;
- encrypted once SQLCipher is implemented;
- exportable by the user as a documented JSON package;
- purgeable separately from imported financial records;
- versioned so a future Lootr release can “upgrade” preserved data into new first-class entities.

Do not preserve Google access tokens, purchase IDs, auth flags, logging queues, or device sync state as reusable credentials. Store only data needed to explain or reconstruct the financial import.

---

## 11. Validation and Reconciliation

### 11.1 Source preflight

Run:

```sql
PRAGMA query_only = ON;
PRAGMA quick_check;
PRAGMA integrity_check;
PRAGMA foreign_key_check;
PRAGMA user_version;
SELECT name, sql FROM sqlite_master WHERE type = 'table' ORDER BY name;
```

Then validate:

- required tables/columns exist for the detected schema version;
- primary keys are unique and nonblank;
- every transaction wallet/category exists;
- every subcategory's parent exists;
- every paired FK resolves or is reported;
- every objective/budget relationship resolves or is reported;
- settings JSON parses;
- enum integers fall within the version-specific mapping;
- all nonzero amounts are finite;
- timestamp values decode into plausible dates.

### 11.2 Dry-run report

Show counts for:

- source rows per table;
- finalized transactions;
- recurring historical rows;
- active future recurrence rows;
- skipped/upcoming rows;
- exact and inferred transfer pairs;
- unpaired category-0 corrections;
- cross-currency transfer pairs;
- standalone and objective-based debts;
- exact and expanded/preserved budgets;
- goals and linked contribution rows;
- attachment links;
- warnings and blockers.

### 11.3 Financial invariants

Per wallet and currency, calculate:

```text
Cashew closing balance
  = SUM(source transaction.amount WHERE paid = true)

Lootr reconstructed balance
  = opening/adjustment income
  - opening/adjustment expense
  + normal income
  - normal expense
  + inbound transfers
  - outbound transfers
```

Require the difference to be within the precision tolerance in §9.1.

Also compare:

- paid transaction count by wallet;
- income and expense totals by wallet and calendar month;
- category totals by wallet and month;
- transfer leg totals and pair counts;
- debt principal, payments, and remaining balance;
- goal linked-row total and imported current amount;
- earliest/latest occurrence per wallet;
- count and total of source rows intentionally excluded from balances.

### 11.4 Referential checks after apply

Run target `PRAGMA foreign_key_check` and confirm:

- every imported target record has provenance;
- every “import” source record has at least one target;
- every “preserve” source record has an archive payload;
- no source row is left without a disposition;
- account stored balances equal the reconstructed ledger;
- rerunning the same source produces zero inserts and zero financial delta.

### 11.5 User acceptance

The final screen should present:

- account-by-account Cashew vs Lootr balance;
- total imported records by kind;
- preserved-only record counts;
- every nonzero reconciliation difference;
- a downloadable local report;
- “keep Cashew export” guidance until the user confirms.

Completion requires explicit acknowledgement if any record is preserved-only or any balance delta is nonzero.

---

## 12. Resumability, Rollback, and Failure Recovery

### 12.1 Resumability

- Staging is checkpointed by source table and source PK.
- Canonical hashes make repeated staging idempotent.
- A crash during analysis resumes from the last completed checkpoint.
- A changed source hash starts a new run; it never mutates an earlier staged run.

### 12.2 Atomic apply

After staging and review, apply all target writes plus provenance in one database transaction. For a normal personal-finance dataset, this is preferable to partially visible imports.

If batching becomes necessary:

- keep imported rows hidden behind `migration_run.state != complete`;
- checkpoint only at referentially closed boundaries;
- publish by setting the run complete in a final transaction.

### 12.3 Rollback

Before apply:

- create a verified Lootr database backup;
- record the pre-import target hashes and row counts.

Rollback options:

1. transaction failure → automatic rollback;
2. completed import with no user edits → delete/soft-delete all provenance-linked targets in reverse dependency order;
3. completed import with user edits → show conflicts and restore the pre-import backup by default, rather than deleting selectively;
4. preserve the source archive and run report after rollback unless the user chooses purge.

Never roll back by deleting records based on name, timestamp, or similarity.

---

## 13. Privacy and Security

**Verified.** Cashew native storage uses ordinary `NativeDatabase` in the reviewed code, and its exported backup is a raw byte copy (`budget/lib/database/platform/native.dart:10-36`). There is no encryption key setup in that path.

Treat every Cashew `.sql`/`.sqlite` export as sensitive plaintext:

- use the platform file picker;
- copy only into app-private storage;
- never upload it for parsing;
- never log row contents, notes, emails, or URLs;
- redact values in error reports;
- disable sync while the migration transaction runs;
- delete temporary plaintext after success or rollback;
- explain that filesystem “secure deletion” is best-effort on flash storage;
- keep the user-selected original untouched so the user controls its deletion.

For attachment link checks or downloads:

- require explicit Google authorization;
- request the narrowest scope;
- do not change Drive permissions;
- do not send links to third parties;
- make attachment migration separately cancelable from financial import.

---

## 14. Recommended UX Flow

### 14.1 Import entry point

Settings → Data → Import from Cashew.

Copy should acknowledge familiarity:

> Bring over your Cashew history. Lootr will analyze a backup on this device, show what maps cleanly, and let you review anything it cannot represent yet.

### 14.2 Steps

1. **Prepare**
   - short instructions for a fresh Cashew data-file export;
   - timezone selection;
   - privacy notice.
2. **Choose file**
   - identify raw SQLite vs degraded CSV;
   - show fingerprint, schema version, date range, and counts.
3. **Analyze**
   - progress by domain;
   - no target writes yet.
4. **Review accounts**
   - choose account types;
   - confirm currency/custom-currency handling.
5. **Review ambiguous mappings**
   - inferred payees;
   - transfer candidates;
   - recurring grouping;
   - budget expansion;
   - upcoming rows;
   - sharing behavior.
6. **Reconciliation preview**
   - per-account balances and deltas;
   - exact/transformed/preserved counts.
7. **Import**
   - atomic local apply;
   - device should stay awake;
   - safe retry after interruption.
8. **Verify**
   - same reconciliation after write;
   - links to imported accounts and transactions.
9. **Keep or purge archive**
   - recommend retaining until the user has used Lootr for several days.

Use neutral language. “Needs review” and “preserved for later” are better than “failed” for valid Cashew concepts Lootr does not yet support.

---

## 15. V1 Scope Versus Later

### 15.1 V1 hard scope

- raw Cashew SQLite file selection and validation;
- schema-version adapter framework, initially tested against the user's actual version;
- wallets → accounts with explicit account-type review;
- categories/subcategories and visuals;
- finalized ordinary transaction history;
- title → payee policy with exact-title preservation;
- same-currency transfer collapse;
- balance corrections/opening-balance classification;
- subscriptions/repetitive history plus template reconstruction where confidence is exact;
- standalone debt/credit records;
- goal aggregates;
- exact monthly category budgets;
- settings subset needed for currency/time interpretation;
- attachment URL retention;
- provenance, preserved payloads, dry run, reconciliation, idempotency, resumability, and rollback.

### 15.2 V1 preserved-only or opt-in lossy scope

- cross-currency transfers until the transfer schema is extended;
- one-off upcoming rows;
- inferred recurrence groups without predictable IDs;
- flexible/multi-wallet/multi-category/filtered/shared budgets;
- goal contribution and debt payment linkage without target relations;
- shared-budget ownership/member semantics;
- associated-title and scanner rules;
- delete-log replay;
- bill-splitter drafts outside the database;
- custom non-ISO currency operation.

### 15.3 Later scope

- dual-amount cross-currency transfers;
- planned one-off transactions;
- first-class goal contributions and debt payment history;
- flexible/repeating budget definitions;
- categorization-rule migration;
- local attachment download/storage;
- shared household migration with identity confirmation;
- Cashew-side helper export for non-database preferences;
- incremental “import newer Cashew changes” after an initial migration.

---

## 16. Blockers Requiring a Real Export

Before implementation is considered ready, obtain one fresh raw export and answer:

1. What are `PRAGMA user_version`, table DDL, and actual column names?
2. Does the file pass `quick_check`, `integrity_check`, and `foreign_key_check`?
3. How are Drift `DateTime` values encoded in that file, and what wall timezone should be assumed?
4. Do enum integers match schema-46 source ordinals?
5. What percentage of category-0 rows have valid explicit pairs?
6. Are cross-currency transfer pairs present, and do their two absolute amounts differ?
7. Do recurring source PKs consistently use `::predict::N`?
8. Are there recurring rows predating the predictable-key scheme?
9. Are debts primarily standalone credit/debt rows, loan objectives, or both?
10. Are loan objectives single-currency or multi-wallet/multi-currency?
11. Which budget shapes are actually used: simple monthly, flexible, filtered, shared, or custom?
12. Are transaction titles merchant names, descriptions, or a mix?
13. How many notes contain Drive links, and are those links accessible?
14. Are custom currencies used?
15. Are there orphaned category, wallet, objective, paired, or budget references?
16. Do `delete_logs` reference entities no longer present?
17. Does the latest export contain an `app_settings` row with valid JSON?
18. Is any unfinished bill-splitter draft important enough to require separate extraction?

No implementation should claim “complete Cashew migration” until these are tested against the user's file.

---

## 17. Schema Changes Recommended Before Building the Importer

Minimum:

1. Add local-only `import_runs`.
2. Add local-only `import_provenance`.
3. Add local-only `import_preserved_payloads`.
4. Implement SQLCipher or explicitly defer encrypted archive retention.

Strongly recommended:

5. Extend transfers with source and destination amounts/currency snapshots, or add transfer legs.
6. Add a goal-contribution relation.
7. Add a debt-payment relation.
8. Add a planned-transaction entity for one-off upcoming items.
9. Add account visual/order/decimal fields if preserving the familiar Cashew account presentation matters.
10. Add a first-class attachment entity before downloading files.

These are not migration-only abstractions. They close real target-model gaps exposed by the user's actual source data.

---

## 18. Acceptance Criteria

The Cashew migration is acceptable for V1 when:

- the same source can be imported twice with zero duplicate financial rows;
- every source row has an `import`, `preserve`, or explicitly acknowledged `ignore` disposition;
- all imported accounts reconcile within currency precision;
- same-currency transfers do not affect spending analytics;
- cross-currency pairs are never silently flattened;
- recurrence history does not double-count future/unpaid rows;
- settled Cashew debt is not mistaken for an unpaid transaction;
- source titles, notes, attachment links, IDs, and raw timestamps remain recoverable;
- user edits made after import are not overwritten by re-import;
- interruption cannot expose a partial dataset;
- rollback restores the exact pre-import Lootr state;
- all parsing and staging occurs on device;
- the final report clearly distinguishes verified exact mappings from inferred or preserved-only mappings.

---

## 19. Primary Source Index

### Cashew

- `budget/lib/database/tables.dart` — enums, table declarations, schema registration, balance/objective queries.
- `budget/lib/database/tables.g.dart` — generated physical SQLite table and column names.
- `budget/lib/database/platform/native.dart` — native DB location and raw byte export/overwrite.
- `budget/lib/widgets/exportDB.dart` — local raw export behavior and `.sql` filename.
- `budget/lib/widgets/importDB.dart` — raw restore behavior.
- `budget/lib/widgets/exportCSV.dart` — CSV filter and exact output columns.
- `budget/lib/widgets/importCSV.dart` — CSV parsing, sign/date/category/wallet behavior.
- `budget/lib/struct/settings.dart` — settings serialization into the database.
- `budget/lib/struct/defaultPreferences.dart` — settings keys and defaults.
- `budget/lib/struct/currencyFunctions.dart` — USD-based exchange-rate behavior.
- `budget/lib/pages/exchangeRatesPage.dart` — custom currency-rate semantics.
- `budget/lib/pages/addWalletPage.dart` — correction category and paired transfer creation.
- `budget/lib/pages/addTransactionPage.dart` — transaction sign, title, special type, note links.
- `budget/lib/struct/upcomingTransactionsFunctions.dart` — recurrence IDs, payment, skip, debt settlement.
- `budget/lib/struct/uploadAttachment.dart` — Google Drive attachment storage.
- `budget/lib/pages/billSplitter.dart` — separate shared-preference storage and generated loan rows.
- `budget/lib/widgets/accountAndBackup.dart` — Google Drive raw backups/downloads.

### Lootr

- `docs/database-schema.md` — target table semantics, UUID/timestamp/currency conventions.
- `docs/domain-model.md` — balance recalculation, transfer, debt, goal, recurring semantics.
- `docs/security-model.md` — intended SQLCipher and privacy boundaries.
- `lib/data/database/app_database.dart` — current connection and schema version.
- `lib/data/database/tables/accounts.dart`
- `lib/data/database/tables/transactions.dart`
- `lib/data/database/tables/transfers.dart`
- `lib/data/database/tables/categories.dart`
- `lib/data/database/tables/payees.dart`
- `lib/data/database/tables/budgets.dart`
- `lib/data/database/tables/debt_records.dart`
- `lib/data/database/tables/goals.dart`
- `lib/data/database/tables/recurring_templates.dart`

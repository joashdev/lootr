# Cashew Data Migration — Personal Finance App
References: `cashew-product-benchmark.md` (V1 adoption decisions), `database-schema.md` (Lootr target tables), `domain-model.md` (financial semantics), `security-model.md` (local data protection), `sync-engine.md` (future row-sync rules), `research/cashew-schema-48-delta.md` (current source schema), `research/cashew-real-export-audit.md` (redacted real-data validation).

Loss-minimizing, local-only migration from an existing Cashew history into Lootr.

---

## 1. Outcome and Recommendation

Use Cashew's **Export data file** as the primary source. The resulting `.sql` file is a raw SQLite database copy, not SQL text (`Cashew/budget/lib/widgets/exportDB.dart:11-44`). Cashew's CSV is a degraded fallback because it contains only paid transactions and omits source IDs, relationships, recurring state, budget definitions, settings, and modification history (`Cashew/budget/lib/widgets/exportCSV.dart:84-151`).

The migration must:

1. analyze the source without modifying it;
2. classify every source row as exact import, transformed import, preserved-only, review-required, or invalid;
3. reconcile counts and balances before any target write;
4. apply the approved import atomically;
5. retain source-to-target provenance;
6. preserve unsupported source semantics rather than discard them;
7. support safe re-import and rollback;
8. run entirely on device;
9. keep the original Cashew export untouched.

> **Definition of intact:** every source row and relationship is either represented as a first-class Lootr record or retained in a versioned, user-exportable preserved payload with a documented reason. “Imported without errors” is not sufficient if unsupported data was silently dropped.

---

## 2. Non-Negotiable Invariants

- The source file is opened read-only and never migrated in place.
- No source row is left without a disposition.
- Same source + same policy can be applied twice with zero duplicate financial records.
- Imported account balances reconcile to Cashew's paid-row sums within currency precision.
- Same-currency transfers remain excluded from spending analytics.
- Cross-currency transfers are never silently flattened into one amount.
- Unpaid future and skipped recurring rows never become finalized spending.
- Goal and debt history is not reduced to an unexplained scalar without retaining the linked source rows.
- User edits made after import are not overwritten automatically by a later import.
- A crash cannot expose a partially published dataset.
- Rollback restores the exact pre-import Lootr state.
- Parsing, staging, diagnostics, and reconciliation never upload financial data.
- Temporary plaintext is deleted after completion or rollback.

---

## 3. Source Snapshot and Evidence Labels

This specification was initially derived from the local Cashew repository at commit `9cfbe50c16d95429891d44faf5f2c77a3abdb93b`, app version `5.4.3+416`, declared schema version `46`, and Lootr `main` as inspected on 2026-07-18. It has since been validated against the user's fresh schema-48 export and Cashew's official deployed `6.6.11+510` build. The exact installed Android patch is not encoded in the export.

| **Label** | **Meaning** |
|---|---|
| `Verified` | Directly supported by the inspected source. |
| `Inferred` | A defensible interpretation that must be checked against the user's real database. |
| `Decision` | Required Lootr behavior. |
| `Blocker` | Must be resolved before “complete migration” can be claimed. |

Schema 48 is the primary V1 adapter target; schema 46 and 47 remain compatibility targets. Historical databases may contain data produced by older versions. Enum ordinals and timestamp encoding must be selected from the exported file's schema version and physical DDL, not assumed from the public source snapshot.

---

## 4. Source Acquisition

### 4.1 Preferred: fresh manual data-file export

Cashew serializes settings into `app_settings`, reads the current database bytes, and saves them with a `.sql` extension. On native platforms the underlying file is `db.sqlite` (`Cashew/budget/lib/widgets/exportDB.dart:11-44`; `Cashew/budget/lib/database/platform/native.dart:10-36`).

User preparation:

1. finish pending Cashew edits;
2. wait for the save to complete;
3. restart Cashew once;
4. export a new data file;
5. keep that original until Lootr reconciliation has passed and the user has used Lootr successfully.

Importer preflight:

- verify the `SQLite format 3\0` header;
- copy into app-private staging;
- compute SHA-256 before reading records;
- enable query-only/read-only mode;
- run SQLite integrity checks;
- record `PRAGMA user_version`, DDL, row counts, and latest modification time.

Cashew's export code does not explicitly checkpoint a WAL before copying the database. A failed integrity or relationship audit must request a fresh export rather than attempting repair.

### 4.2 Acceptable: downloaded Cashew Drive backup

Cashew's Google Drive backup stores the same database bytes. A downloaded backup may be older than the current device state; show source schema, date range, row counts, and last modification before continuing.

### 4.3 Recovery-only: direct `db.sqlite`

Direct sandbox extraction is platform-specific. The normal product flow must not instruct users to root, jailbreak, or alter Cashew's private storage.

### 4.4 Degraded fallback: CSV

CSV may recover finalized transactions, account names, categories, title, note, date, direction, currency label, budget name, and objective name.

It cannot reliably recover:

- source IDs;
- modification timestamps;
- transfer pairs;
- recurrence chains;
- unpaid/upcoming/skipped state;
- budget definitions and category limits;
- goal/debt definitions and linked history;
- category hierarchy identity;
- associated-title rules;
- scanner templates;
- settings or delete logs.

The UI must label this mode **transaction-history only** and preserve the CSV file hash and import warnings.

---

## 5. Verified Cashew Data Inventory

The public schema-46 source registers ten tables (`Cashew/budget/lib/database/tables.dart:679-691`). Schema 48 retains them and adds first-class tags plus a transaction-tag junction.

| **Source table** | **Role** | **Important data** |
|---|---|---|
| `wallets` | Account containers | Name, currency, decimals, color, icon, ordering, home scope |
| `transactions` | Final, planned, recurring, debt, correction, and transfer legs | Signed amount, title, note, wallet/category, dates, type/state, pair/objective links |
| `categories` | Income/expense hierarchy | Parent, order, color, asset icon, emoji |
| `category_budget_limits` | Nested budget allocations | Budget, category, amount, wallet |
| `associated_titles` | Categorization memory | Exact/contains title → category |
| `budgets` | Flexible budget definitions | Period, category/account scope, filters, sharing, limits |
| `app_settings` | Serialized preferences | Currency rates, locale, notifications, display settings |
| `scanner_templates` | Email parsing rules | Match delimiters, default category/account |
| `delete_logs` | Cashew sync tombstones | Deleted source PK and entity type |
| `objectives` | Goals and long-term loans | Type, target/offset, dates, visuals, wallet |
| `tags` | Orthogonal transaction labels | Name, color, icon, order, archive state |
| `transaction_to_tag_links` | Many-to-many tag membership | Transaction and tag source keys |

Schema 47 adds archive state to wallets and categories. Schema 48 adds wallet emoji, archived associated-title rules, scanner default title, and the two tag tables. `DeleteLogType` ordinals `6–8` were reassigned without rewriting old rows, so V1 must not interpret tombstones as authoritative entity types.

Data not fully contained in the raw export:

- attachment bytes remain in Google Drive; only URLs in notes are preserved;
- unfinished bill-splitter draft state is stored in separate shared preferences;
- cloud credentials/tokens are neither needed nor eligible for migration.

---

## 6. Cashew Semantics That Affect Mapping

### 6.1 Wallet balances

Cashew wallets do not store a balance. Balance is the sum of `transactions.amount` where `paid = true` (`Cashew/budget/lib/database/tables.dart:6767-6786`).

Lootr must recalculate each imported account from the imported ledger and compare it with this source sum.

### 6.2 Signed transactions

Cashew stores signed REAL amounts plus an `income` flag. Normal income is positive and expense is negative. Lootr stores positive magnitude plus explicit direction.

A sign/flag disagreement is blocking; it must not be silently corrected.

### 6.3 Transfers and corrections

Cashew transfers are paired category-`"0"` rows with opposite signs and usually one side referencing the other. Cross-currency pairs may have different absolute values (`Cashew/budget/lib/pages/addWalletPage.dart:985-1018,1181-1207`).

An unpaired category-`"0"` row is a balance correction. Only the earliest qualifying correction near wallet creation may be classified as opening balance; later corrections remain explicit adjustments.

### 6.4 Recurring rows

Subscriptions and repetitive rows create successor rows. Predictable IDs use `{base-id}::predict::{occurrence}`. Paid, skipped, original due date, successor creation, period, end date, and notification state all affect interpretation (`Cashew/budget/lib/struct/upcomingTransactionsFunctions.dart:21-47,98-107,192-354`).

### 6.5 Debt and credit

Standalone `credit` means lent/receivable; `debt` means borrowed/payable. Their `paid` semantics are unusual: active amounts remain counted while settlement removes their balance effect. Partial settlement can convert them into loan objectives.

### 6.6 Goals and loan objectives

Objective progress is derived from linked paid transactions, not just the objective row. Goal links use `objective_fk`; loan links use `objective_loan_fk`.

### 6.7 Budgets

Cashew budgets can be custom/daily/weekly/monthly/yearly, span multiple wallets and categories, include or exclude categories, include only explicitly attached transactions, carry nested category limits, and contain sharing/filter behavior.

Most cannot map directly to Lootr's one-category calendar-month budget.

---

## 7. Lootr Readiness Gaps

| **Source concept** | **Current Lootr gap** | **Required response** |
|---|---|---|
| Import audit/idempotency | No run or provenance model | Add import tables before importer |
| Unsupported source fields | No preserved-payload store | Add encrypted, versioned archive |
| Wallet visuals/precision | Account lacks icon/color/order/decimals | Preserve; optionally extend account |
| Cross-currency transfer | One transfer amount only | Add two-leg/dual-amount model or preserve-only |
| Free transaction title | Payee + note only | Infer payee; retain exact title |
| One-off upcoming item | No planned-entry entity | Add model or preserve-only |
| Recurring end/type/due history | Template is narrower | Add occurrence lifecycle and source series |
| Goal contribution history | Scalar goal amount; no enforced relation | Add contribution events/FK |
| Debt payment history | Aggregate balance; no enforced relation | Add payment events/FK |
| Flexible budget | Month + category only | Direct-map exact cases; preserve others |
| Categorization rules | No durable rule table | Add local rule model or preserve |
| Attachment bytes | No local attachment entity | Keep URLs; defer authorized download |
| At-rest encryption | Security spec not implemented | Implement before retaining real import archive |

These are target-model gaps, not parser details. A parser cannot make an unrepresentable concept lossless.

---

## 8. Schema Additions Before Implementation

### 8.1 Minimum local-only tables

```text
import_runs
  id
  source_system
  source_sha256
  source_filename
  source_schema_version
  source_app_version
  assumed_timezone
  state
  policy_json
  counts_json
  started_at
  completed_at

import_provenance
  id
  import_run_id
  source_system
  source_fingerprint
  source_entity_type
  source_entity_id
  source_payload_sha256
  target_table
  target_id
  mapping_role
  imported_target_sha256
  imported_at

import_preserved_payloads
  id
  import_run_id
  source_locator
  payload_json
  reason_code
  related_target_table
  related_target_id
  created_at
```

Required uniqueness:

```text
(source_system, source_fingerprint, source_entity_type,
 source_entity_id, target_table, target_id, mapping_role)
```

### 8.2 Required V1 model changes

Implement in this order for the user's migration:

1. Exact decimal money values backed by a signed `BigInt` coefficient and explicit scale. SQLite persists the coefficient as canonical decimal text so values are not limited by 64-bit integer range.
2. Per-account currency identifier, configured scale, exact stored balance coefficient, visual metadata, order, and archive state.
3. Dual-leg transfers with distinct source and destination coefficients, scales, and currency snapshots. Same-currency transfers use equal values at the same scale; cross-currency transfers never become expense plus income.
4. Goal contribution and debt payment relations.
5. Recurring occurrence relation with due, paid, unpaid, skipped, dismissed, resolved, original-due, and source-series state.
6. Durable payee/title categorization rules, including inactive imported rules and exact-before-contains precedence.
7. Composite budgets with multi-account and multi-category include/exclude membership, explicit transaction membership, income/expense filtering, monthly and custom date-range periods, deterministic overlap behavior, and historical drill-down.
8. First-class transaction tags in the source adapter and lossless preserved tag links; tag-management UI may remain deferred when no rows exist.
9. Local attachment metadata that preserves URL text without claiming attachment-byte migration.

Items 1–7 are V1 launch requirements even where a shape is not exercised by this export. They prevent the importer from baking known loss or false financial semantics into the target model. Items 8–9 must be structurally supported and recoverable; the audited export has no tag rows, tag links, or scanner templates.

All additions must remain compatible with additive migrations and the future sync model. Migration archive tables are local-only and excluded from V2 sync by default.

---

## 9. Staging Architecture

Use a separate temporary SQLite staging database. Direct source-to-target inserts are prohibited because source rows may collapse, fan out, or remain preserved-only.

```text
Cashew backup (read-only)
          │
          ▼
  source adapter by schema version
          │
          ▼
  canonical staged records + relations
          │
          ├── exact import
          ├── transformed import
          ├── preserved-only
          ├── review required
          └── blocking error
          │
          ▼
  dry-run reconciliation and user policy
          │
          ▼
  one atomic Lootr apply transaction
          │
          ▼
  post-write reconciliation + publish
```

Temporary tables:

```text
staged_records
  run_id
  source_table
  source_pk
  raw_payload_json
  raw_payload_sha256
  canonical_kind
  canonical_payload_json
  disposition
  issue_code

staged_relations
  run_id
  source_from
  relation_kind
  source_to

staged_issues
  run_id
  severity
  issue_code
  source_locator
  message
  proposed_resolution_json
```

Money remains exact decimal text in staging and is converted to a normalized `(coefficient_text, scale, currency_identifier)` tuple at the final boundary. No migration or ledger path converts imported money to binary floating point.

---

## 10. Core Entity Mapping

| **Cashew** | **Lootr** | **Mapping** | **Preservation rule** |
|---|---|---|---|
| Wallet | Account | New target UUID; exact name/currency; reviewed account type | Keep visuals/order/decimals |
| Wallet balance | Account balance | Recalculate from imported financial events | Compare to source paid sum |
| Category | Category | New UUID; parent after all categories stage | Keep both icon fields and source order |
| Title | Payee candidate | Exact display, normalized key | Keep exact source title |
| Signed transaction | Transaction | Absolute amount + direction | Quarantine sign/flag mismatch |
| Category/subcategory | Category FK | Prefer mapped subcategory; retain parent | Keep both source links |
| Note | Note | Exact text | Never strip Drive URLs |
| Paid normal row | Final transaction | One-time ledger entry | Source provenance in metadata |
| Paid recurring row | Final transaction | Recurring mode + template link | Keep due and series data |
| Paired same-currency rows | Transfer | Collapse to one dedicated dual-leg transfer with equal source/destination values | Two provenance links |
| Paired cross-currency rows | Transfer | One dedicated dual-leg transfer with distinct exact source/destination values and currencies | Two provenance links; never infer a rate |
| Unpaired category-0 row | Opening/adjustment transaction | Conservative classification | Show review class |
| Standalone credit/debt | Debt record + optional event | Map direction/status/principal | Keep source financial row |
| Goal objective | Goal | Target/date/current linked sum | Keep wallet/visual/archive fields |
| Loan objective | Debt record | Derive direction/principal/balance | Keep all loan ledger rows |
| Monthly or custom budget | Composite budget | Map scopes, filters, memberships, and period exactly | Keep source definition and membership provenance |
| Unsafe legacy budget | Read-only imported budget | Queryable preserved definition and drill-down | Never flatten or hide |
| Associated title | Categorization rule or preserved record | Import only after rule model exists | Never auto-create payee |
| Scanner template | Preserved record | No V1 execution | Keep parser delimiters/defaults |
| Settings | Safe preference subset + archive | Currency/time interpretation only | Exclude auth/purchase/sync credentials |
| Delete log | Preserved audit | Do not replay blindly | Keep entity type and source PK |

For every transformed record, store the exact source row hash and source-to-target mapping.

---

## 11. Difficult Transformation Rules

### 11.1 Amount precision

1. Read the source SQLite numeric value through its shortest round-tripping decimal representation.
2. Require sign and `income` flag agreement.
3. Quantize once to the source wallet's configured scale using deterministic half-even rounding and record whether quantization changed the source representation.
4. Store magnitude as a canonical non-negative `BigInt` coefficient string plus scale and currency identifier.
5. Store account balances, budget limits, goal/debt amounts, transfer legs, CSV values, and backup values using the same representation.
6. Add, subtract, compare, aggregate, and reconcile only values with matching currency identifiers after aligning scales exactly.
7. Reconciliation is coefficient equality at the source scale. A nonzero coefficient delta is blocking.

The original Cashew `REAL` may already contain binary representation error; Lootr cannot recover precision Cashew discarded. The adapter therefore retains the raw SQLite numeric text in the encrypted preserved payload, records any source-scale quantization as a transformed disposition, and never introduces further floating-point aggregation.

### 11.2 Currency

- Preserve each transaction in its wallet currency.
- Preserve the wallet-configured scale, including 2, 4, and 12 decimals.
- Do not rewrite history using today's rate.
- Preserve cached/custom rate snapshots and their source timestamp.
- Invalid/custom currency identifiers require review.
- Ledgers, budgets, balances, reports, filters, drill-downs, CSV, and backup summaries group by currency by default.
- Never sum unrelated currencies or label their raw sum as a base currency.
- Optional conversion requires an explicit rate, source, effective timestamp, source/destination currencies, and half-even rounding policy. Missing rate data means no converted total.
- A monetary source row whose wallet is missing keeps its exact coefficient and scale with the explicit `UNKNOWN` currency marker. It is review-required, remains read-only, and is never aggregated with a real currency.

### 11.3 Time

Cashew has no separate transaction timezone field. The adapter must inspect the physical value and schema version before decoding.

- Explicit UTC/offset values remain instants.
- Epoch values use the correct seconds/milliseconds unit for that Drift version.
- Only offset-free wall times use the user-confirmed source timezone.
- Preserve raw value, decoded instant, displayed wall time, zone, and offset.
- Require the user to verify at least one known transaction timestamp before apply.

### 11.4 Transfer pairing

Pair candidates in this order:

1. explicit `paired_transaction_fk`;
2. reciprocal pair;
3. predictable recurrence relationship;
4. conservative category-0 fallback: different wallets, opposite signs, within two seconds, compatible text, equal amounts for same currency.

Fallback pairs are always reviewable.

Cross-currency pairs map to a dedicated transfer with distinct source and destination exact amounts and currency snapshots. If either leg or currency is missing, the relationship is review-required or blocking; it is never converted into income and expense. The importer does not infer an exchange rate.

### 11.5 Recurring series

Group only when source series identity is exact or user-approved. Import paid non-skipped occurrences as history, preserve skipped occurrences, use the latest valid unpaid occurrence as next due, and create one reminder/template with an RRULE. For schema 48, only structurally complete prediction chains become editable templates; loose recurring history remains queryable with source provenance and a visible preserved disposition.

Keep Lootr confirm-before-finalize. Cashew auto-pay preference may be preserved as metadata but must not enable silent writes.

One-off upcoming rows remain preserved-only unless a planned-entry model is added.

### 11.6 Goals and debt

Goal `current_amount` is derived from linked paid rows. Debt remaining balance is derived from its source ledger. If explicit goal/debt event relations are not added, import the aggregate record and preserve every linked source row, but label history as not yet first-class.

### 11.7 Budgets

V1 budgets are reusable, queryable definitions rather than one-category month rows. Each budget stores:

- an exact limit amount and currency;
- monthly or bounded custom date-range/cycle period;
- zero or more included/excluded account memberships;
- zero or more included/excluded category memberships;
- zero or more explicit transaction memberships;
- expense, income, or both direction filter;
- an explicit-membership-only flag;
- imported source provenance and review state for missing/deleted references.

Membership evaluation is deterministic:

1. Reject records outside the evaluated historical period.
2. Apply the direction filter.
3. If explicit-membership-only, include only attached transactions.
4. Otherwise apply account and category includes; an empty include set means all.
5. Apply excludes after includes; exclude wins.
6. Explicitly attached transactions are added after normal includes but cannot override period, direction, or an explicit exclusion.
7. Each budget calculates independently. A transaction may contribute to overlapping budgets; UI totals never add overlapping budgets together as if they were disjoint.

Every budget detail exposes the exact matching transaction list and a human-readable reason per record. Deleted or missing source account/category references create a review state and remain visible in an imported-budget view. If a future source shape cannot be edited without semantic loss, retain the queryable source definition as read-only; no valid budget may disappear or be flattened into false one-category rows.

### 11.8 Titles and payees

Cashew titles may be merchants, descriptions, or a mixture. Offer:

- create/merge payees from titles;
- preserve titles only;
- review ambiguous/high-frequency names.

The exact source title is always recoverable.

### 11.9 Attachments

V1 preserves Drive URLs in notes and inventories likely attachment links. Link checking is explicit and non-blocking. Downloading attachment bytes requires a later user-authorized Google flow and a local encrypted attachment model.

---

## 12. Unsupported Data Preservation

Preserve exact source payloads for:

- every source row before transformation;
- wallet appearance/order/precision;
- complex budget rules, limits, sharing, and member filters;
- associated-title and scanner rules;
- delete logs;
- objective visuals/archive/pin/wallet;
- transaction sharing fields and budget exclusions;
- custom/cached exchange rates;
- skipped and upcoming rows;
- ambiguous transfer candidates;
- source settings needed to interpret data;
- inaccessible attachment URLs.

The archive must be:

- local-only;
- encrypted once SQLCipher is active;
- versioned;
- user-exportable as documented JSON;
- separately purgeable;
- upgradeable into new first-class entities in later Lootr releases.

Never preserve OAuth tokens, reusable credentials, purchase identifiers, logging queues, or device sync state.

---

## 13. Identity, Idempotency, and Re-Import

Target records keep UUID v4 IDs. Generate them once during staging and persist the mapping.

Canonical import identity:

```text
(source_system, source_sha256, source_table,
 source_pk, target_table, mapping_role)
```

Re-import rules:

1. Same source fingerprint and source row hash → skip.
2. Same source fingerprint, changed source row, untouched target → offer mapped update.
3. Same source fingerprint, changed source row, user-edited target → preserve Lootr edit and show conflict.
4. Different source fingerprint with same embedded Cashew PK → propose continuation, never auto-merge materially different content.
5. CSV without stable IDs → similarity match is advisory and collisions require review.

Never merge accounts or categories by name alone. Source PK and hierarchy are authoritative.

---

## 14. Import State Machine and Failure Recovery

```text
selected
   → validating
   → validated
   → staged
   → needs_review ─────┐
   → ready             │ user resolves
   → applying          ◀──────┘
   → verifying
   → complete

selected through ready → cancel_requested → cancelled
validating through staged → interrupted → resume from checkpoint
applying/verifying interruption → transaction rollback → interrupted
Any state → failed
complete → rolled_back
```

Staging checkpoints by source table and PK. A changed file hash starts a new run.

Cancellation remains available until atomic publication begins. During `applying` and `verifying`, back/cancel is disabled with a calm explanation because the database transaction must finish or roll back as one unit. Each run persists cleanup status and attempt count. Startup recovery scans nonterminal runs, verifies the private staging copy and fingerprint, and resumes from the last checkpoint; if staging is missing, the user is asked to reselect the same source without losing the redacted review report. Recovery and orphan cleanup must finish before a new staging directory is created, so a newly selected source can never be mistaken for an abandoned run.

Apply target records, provenance, dispositions, and an encrypted canonical source-row archive in one database transaction. Every source row receives an archive entry even when it also becomes an editable Lootr record; unsupported semantics additionally receive a preserved-payload entry with a visible reason. If very large datasets require batching, keep all imported rows unpublished until the final run-complete transaction.

Before apply:

- create a verified Lootr backup;
- record pre-import row counts and hashes.

Rollback:

- failed apply → automatic transaction rollback;
- completed import with no edits → remove provenance-linked targets in reverse dependency order;
- completed import with user edits → restore the verified pre-import backup by default;
- keep the source archive and report unless the user explicitly purges them.

Never identify rollback rows by name, time, or similarity.

Encrypted Lootr backups contain a versioned manifest for validation. Restore verifies that manifest, integrity, foreign keys, and schema before replacing the live database, then removes the backup-only manifest so it cannot become application state.

---

## 15. Validation and Reconciliation

### 15.1 Source checks

```sql
PRAGMA query_only = ON;
PRAGMA quick_check;
PRAGMA integrity_check;
PRAGMA foreign_key_check;
PRAGMA user_version;
SELECT name, sql
FROM sqlite_master
WHERE type = 'table'
ORDER BY name;
```

Validate required tables/columns, unique/nonblank PKs, relationships, parseable settings, known enum values, finite amounts, and plausible timestamps.

### 15.2 Dry-run inventory

Show:

- rows per source table;
- finalized transactions;
- recurring history and next occurrences;
- skipped/upcoming rows;
- exact/inferred transfer pairs;
- cross-currency transfers;
- corrections/opening candidates;
- standalone and objective debts;
- goals and contribution rows;
- exact/complex budgets;
- attachment links;
- exact/transformed/preserved/review/error counts.

### 15.3 Financial reconciliation

Per account and currency:

```text
Cashew closing balance
  = SUM(source amount WHERE paid = true)

Lootr reconstructed balance
  = income
  - expense
  + inbound transfers
  - outbound transfers
```

Also compare:

- paid row count by wallet;
- income/expense totals by wallet and month;
- category totals by wallet and month;
- pair counts and transfer-leg totals;
- debt principal, payments, and remaining balance;
- goal linked-row total and current amount;
- earliest/latest timestamp;
- count/amount excluded from live balances.

All monetary comparisons use exact coefficients at the account or budget currency scale. Summary reports may expose counts and pass/fail state without exposing amounts. Cross-currency totals remain partitioned unless an explicit conversion record is selected.

### 15.4 Post-apply checks

- target `PRAGMA foreign_key_check` passes;
- every imported target has provenance;
- every source row has target or preserved payload;
- imported-account stored balances equal reconstructed ledgers at each account's source scale;
- every budget membership can explain each included transaction;
- goal contribution and debt payment event counts and per-currency/scale totals match their valid source links;
- every transfer preserves both account/currency legs and is excluded from spending;
- same source rerun produces zero inserts and zero financial delta.

Any nonzero balance delta is blocking by default.

---

## 16. User Experience

Entry point: **Settings → Data → Import from Cashew**.

Suggested copy:

> Bring over your Cashew history. Lootr analyzes the backup on this device, shows what maps cleanly, and preserves anything it cannot represent yet.

Flow:

1. **Prepare** — fresh-export instructions, timezone, local-processing notice.
2. **Choose file** — detect SQLite or degraded CSV; show fingerprint, schema, dates, counts.
3. **Analyze** — domain progress; no target writes.
4. **Review accounts** — account types, currencies, custom identifiers.
5. **Review mappings** — payees, transfers, recurrence, budgets, upcoming rows, sharing.
6. **Reconcile** — account-by-account totals, exact/transformed/preserved counts.
7. **Import** — atomic local apply; safe retry after interruption.
8. **Verify** — repeat reconciliation and deep-link to imported records.
9. **Retain or purge archive** — recommend retention until the user has validated normal use.

Use neutral language: **Needs review** and **Preserved for later**, not **Failed**, when the source is valid but Lootr lacks an equivalent.

Timezone and title/payee handling are explicit reversible confirmations in the review step, not hidden defaults. The post-import landing view opens the most recent imported month with the imported account and currency filters visible. Composite imported budgets remain visible in Budgets, Dashboard, and currency-grouped reports; unsafe source shapes use a read-only detail and exact transaction drill-down instead of being flattened.

---

## 17. Privacy and Security

Treat the selected Cashew database as sensitive plaintext.

- Use the platform file picker.
- Copy only into app-private storage.
- Never upload for parsing.
- Never log notes, titles, emails, URLs, or row contents.
- Redact financial values in diagnostics by default.
- Disable sync while apply runs.
- Exclude migration/provenance tables and provenance-linked imported rows from future sync until the user deliberately adopts or edits them.
- Delete temporary plaintext after success/rollback.
- Explain that secure deletion is best-effort on flash storage.
- Leave the user-selected original untouched.

The preserved archive should not be retained until Lootr's SQLCipher implementation is working, or the user must receive an explicit plaintext-at-rest disclosure.

Attachment checks require separate explicit authorization and must not change Drive sharing permissions.

---

## 18. V1 Scope

### 18.1 Hard scope

- Raw Cashew SQLite selection and validation.
- Explicit schema-46/47/48 adapters, with schema 48 tested against the user's actual export.
- Wallets/accounts, reviewed account types, archive state, and source precision up to 12 decimals.
- Exact coefficient-and-scale money storage across all financial domains and reports.
- Categories/subcategories and visuals.
- Finalized ordinary transaction history.
- Exact-title preservation and payee policy.
- Same-currency transfer collapse.
- Cross-currency dual-leg transfers with explicit source and destination amounts/currencies.
- Review of same-account, unequal-value, non-transfer-category, and tombstoned transfer exceptions.
- Corrections/opening classification.
- Exact recurring history, occurrence state, and template reconstruction.
- Standalone credit/debt.
- First-class goal contribution and debt payment relations.
- Composite monthly/custom-cycle budgets with multi-account/category include/exclude membership, explicit transaction membership, historical drill-down, deterministic overlap behavior, and deleted-wallet review.
- Imported associated-title categorization rules.
- Currency/time interpretation settings.
- Attachment URL retention.
- Provenance, preserved payload, dry run, reconciliation, idempotency, resumability, and rollback.

### 18.2 Preserved-only until model support exists

- one-off upcoming rows;
- ambiguous recurrence groups;
- sharing/member semantics;
- scanner rules and tag-management UI state not represented by first-class tables;
- delete-log payloads and ambiguous tombstone type codes;
- custom-currency conversion when no explicit rate/source/timestamp exists;
- bill-splitter drafts outside the database.

### 18.3 Later upgrades

- planned one-off transactions;
- first-class tags and scanner automation;
- local encrypted attachments;
- confirmed household identity migration;
- incremental import of newer Cashew changes.

---

## 19. Real-Export Audit and Decisions

The fresh 2026-07-18 export has been audited read-only. The source remains outside the repository; `research/cashew-real-export-audit.md` contains only redacted structure, counts, aliases, and pass/fail results.

| **Area** | **Verified result** | **Migration decision** |
|---|---|---|
| Health | SQLite integrity and quick checks pass | Suitable as the primary development oracle |
| Source format | Schema 48; 12 application tables | Implement explicit schema-48 adapter first |
| Ledger | 19 accounts, 2,065 transactions, 3 currencies; projected direction transform reconciles with zero delta | Preserve wallet precision and reconcile per account/currency |
| Precision | 2-, 4-, and 12-decimal wallets are present | Never assume two decimals or round before reconciliation |
| Transfers | 269 resolved pairs; all same-currency; eight structural exceptions | Collapse exact pairs; require review for exceptions |
| Corrections | 65 paid unpaired category-0 rows across 16 accounts | Classify opening candidates conservatively; keep later adjustments explicit |
| Scheduled history | 31 prediction series, long chains, 18 unpaid rows, and future occurrences | Add recurring occurrence lifecycle before import |
| Goals and loans | All eight objectives have linked history; 235 linked financial rows | Add contribution/payment relations in V1 |
| Budgets | Five monthly definitions; four use explicitly added transactions; three reference a deleted wallet | Add membership semantics and a deleted-wallet review policy |
| Learned rules | 277 active contains-title rules | Import into a durable inactive-capable local rule model |
| Attachments | 36 Drive-link occurrences across 35 notes | Preserve URL text; do not claim byte migration |
| Orphans | 15 FK findings, all explained by three deleted parent identities in Cashew's logs | Preserve survivor plus tombstone evidence; never recreate parent silently |
| Tags/automation | Tag, tag-link, and scanner-template tables are empty | Support in adapter/preservation; defer first-class UI |
| Archive state | No live wallets, categories, or rules are archived | Preserve the field, but no archived-user-data UI blocker exists |
| Settings | Valid JSON; three source currencies and custom-currency settings exist | Import only interpretation-safe settings; keep sensitive values encrypted |

Core schema-48 transaction, recurrence, budget, objective, and sharing ordinals match schema 46. Cashew reassigned delete-log type ordinals `6–8`; therefore live tables are authoritative and V1 must not replay or semantically decode tombstones.

Two questions remain private apply-time confirmations rather than research blockers:

1. compare one known date in Cashew and Lootr to confirm the intended timezone;
2. review how exact titles should map to payees without exposing them in logs or fixtures.

Build only anonymized synthetic fixtures from these shapes. Never copy source rows, names, IDs, URLs, settings values, or monetary values into source control.

---

## 20. Test Strategy

Required fixtures:

- clean schema-46 SQLite export;
- schema-47 archive-state export;
- schema-48 export with empty and populated tag-link tables;
- same-currency transfer pair;
- cross-currency transfer pair;
- same-account, unequal-value, non-category-0, and tombstoned pair exceptions;
- unpaired opening and later correction;
- paid/skipped/future recurring chain;
- standalone and objective-based debt;
- goal with linked contributions;
- simple, explicit-membership, deleted-wallet, and complex budgets;
- custom category hierarchy and duplicate names;
- malformed/orphaned references;
- 2-, 4-, and 12-decimal currencies;
- Drive link in note;
- CSV fallback;
- rerun after user edits;
- interruption at every state transition.

Required test layers:

| **Layer** | **Coverage** |
|---|---|
| Adapter unit | Schema detection, enums, timestamp decoding, decimal serialization |
| Mapping unit | Every entity/field rule and issue code |
| Property | No source row lacks a disposition; idempotency; totals preserved |
| Database integration | Read-only source, atomic apply, FK checks, rollback |
| Golden report | Stable dry-run and reconciliation summaries |
| Widget | Review, conflicts, warnings, cancellation, accessibility |
| Device | Large file, app backgrounding, storage pressure, biometric/lock |
| Security | Plaintext lifecycle, log redaction, archive encryption |

Migration release requires a restore drill: import into a clean Lootr database, export a Lootr backup, restore it into another clean database, and reproduce counts, relationships, and balances.

---

## 21. Acceptance Criteria

The migration is acceptable when:

- the same source imports twice with no duplicates;
- every source row is imported, preserved, or explicitly ignored;
- every account reconciles within currency precision;
- same-currency transfers do not affect spending;
- cross-currency pairs are never silently flattened;
- unpaid/skipped rows do not inflate balances;
- settled debt is not treated as active spending;
- source titles, notes, IDs, timestamps, and attachment URLs remain recoverable;
- post-import Lootr edits survive re-import by default;
- interruption never publishes partial data;
- rollback restores the pre-import database exactly;
- all processing is local and logs are redacted;
- the report distinguishes exact, inferred, preserved-only, and ignored mappings;
- a Lootr backup/restore round trip reproduces the imported state;
- the importer has been validated against the user's real export;
- schema-48 archive/tag fields and tombstone ordinal ambiguity are handled explicitly.

---

## 22. Bottom Line

The migration is feasible, and the real export is healthy enough to serve as the primary development oracle. It is not a CSV-parser task and the current Lootr target model needs additions. The correct design is a schema-48-aware, read-only Cashew adapter feeding a canonical staging model, followed by user-reviewed transformation, atomic apply, and ledger reconciliation.

The implementation order is SQLCipher and temporary-plaintext verification, import/provenance foundation, exact decimal target migration, and a schema-48 dry run. Then add dual-leg transfers, recurring occurrences, goal/debt events, composite budget membership, learned-title rules, atomic publication, rollback, and backup/restore. Tags, scanner automation, and attachment bytes are not exercised by this export and may remain losslessly preserved with visible reasons, but their source rows and relationships must still receive dispositions.

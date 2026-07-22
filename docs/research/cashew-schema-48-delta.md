# Cashew Schema 48 Delta — Migration Research

Metadata-only analysis of the user's 2026-07-18 Cashew data-file export, the public Cashew source snapshot, and Cashew's currently deployed first-party web build.

**Privacy boundary:** no application-table row, financial value, title, note, account name, category name, settings JSON, or other user content was queried. The local export was opened read-only and inspected only through SQLite header/pragma metadata and `sqlite_schema`.

**Assessment date:** 2026-07-18 (Asia/Manila).

---

## 1. Conclusion

The export is a valid Cashew SQLite database with `PRAGMA user_version = 48`. The difference from the locally cloned Cashew repository is not a corrupt or prematurely bumped database:

- Cashew's public GitHub `main` still ends at commit [`9cfbe50`](https://github.com/jameskokoska/Cashew/commit/9cfbe50c16d95429891d44faf5f2c77a3abdb93b), where `pubspec.yaml` declares app `5.4.3+416` and `tables.dart` declares schema 46 ([app version](https://github.com/jameskokoska/Cashew/blob/9cfbe50c16d95429891d44faf5f2c77a3abdb93b/budget/pubspec.yaml#L18), [schema version](https://github.com/jameskokoska/Cashew/blob/9cfbe50c16d95429891d44faf5f2c77a3abdb93b/budget/lib/database/tables.dart#L29)).
- The official deployed Cashew web application reports app `6.6.11+510` in [`version.json`](https://budget-track.web.app/version.json). Its first-party compiled bundle declares schema 48, contains migrations `46 → 47 → 48`, and defines the same schema-48 tables and columns found in the user's export ([deployed bundle](https://budget-track.web.app/main.dart.js)).
- The public repository's own commit history shows that the latest public commit is the same March 2026 snapshot, so `git pull` cannot supply the distributed schema-48 source ([official commit history](https://github.com/jameskokoska/Cashew/commits/main/)).

Therefore, the installed/distributed Cashew application is ahead of the public source tree. Lootr must treat schema 48 as a supported source format rather than forcing or downgrading it to schema 46.

The user's exact Android app version cannot be derived from schema metadata alone. What can be established without reading an application row is:

| Evidence | App version | DB schema |
|---|---:|---:|
| Public GitHub snapshot `9cfbe50` | `5.4.3+416` | `46` |
| Official hosted build, deployed 2026-07-10 | `6.6.11+510` | `48` |
| User export, created 2026-07-18 | not encoded in schema metadata | `48` |

Schema 48 was introduced after `5.4.3+416` and no later than `6.6.11+510`. Cashew's deployed changelog places “Ability to archive accounts,” the user-facing capability behind schema 47, in the `< 6.0.0` release family. The deployed changelog does not name the schema-48 bump or custom tags explicitly, so assigning schema 48 to an exact patch release would be speculation.

## 2. Sources and Reproducibility

### 2.1 First-party sources

1. Cashew public source at immutable commit [`9cfbe50c16d95429891d44faf5f2c77a3abdb93b`](https://github.com/jameskokoska/Cashew/tree/9cfbe50c16d95429891d44faf5f2c77a3abdb93b).
2. Cashew's official deployed [`version.json`](https://budget-track.web.app/version.json).
3. Cashew's official deployed [`main.dart.js`](https://budget-track.web.app/main.dart.js).
4. The user's Cashew export, inspected locally in SQLite read-only mode.

The hosted bundle inspected for this report had:

```text
version.json: 6.6.11+510
main.dart.js SHA-256: 749b8bc97c7f2c32b977e170e6601e30e165ad724ee1d2e9fb1c0e494a6b70cb
main.dart.js Last-Modified: 2026-07-10T03:14:14Z
```

The bundle exposes schema 48 in two generated database implementations, registers migration cases for source versions 46 and 47, and contains the schema/migration definitions described below. The hash is recorded because compiled symbol names are minified and may change on Cashew's next deployment.

### 2.2 Metadata-only local commands

The local audit used the equivalent of:

```sql
PRAGMA user_version;
PRAGMA application_id;
PRAGMA schema_version;
SELECT name, type, rootpage, sql
FROM sqlite_schema
WHERE type IN ('table', 'index', 'trigger', 'view')
ORDER BY type, name;
```

No `SELECT` was issued against a Cashew application table.

## 3. Exact Schema Changes

The public schema-46 source registers ten application tables ([registration](https://github.com/jameskokoska/Cashew/blob/9cfbe50c16d95429891d44faf5f2c77a3abdb93b/budget/lib/database/tables.dart#L679-L691)). The schema-48 export has the same ten plus `tags` and `transaction_to_tag_links`.

### 3.1 Migration `46 → 47`

The deployed migration adds one archive flag to each of two existing entities:

| Table | Added column | Physical SQLite definition |
|---|---|---|
| `wallets` | `archived` | `INTEGER NOT NULL DEFAULT (0) CHECK ("archived" IN (0, 1))` |
| `categories` | `archived` | `INTEGER NOT NULL DEFAULT (0) CHECK ("archived" IN (0, 1))` |

This is consistent with the schema-46 source, where neither `Wallets` nor `Categories` has an archive column ([wallet definition](https://github.com/jameskokoska/Cashew/blob/9cfbe50c16d95429891d44faf5f2c77a3abdb93b/budget/lib/database/tables.dart#L250-L271), [category definition](https://github.com/jameskokoska/Cashew/blob/9cfbe50c16d95429891d44faf5f2c77a3abdb93b/budget/lib/database/tables.dart#L342-L373)).

### 3.2 Migration `47 → 48`

The deployed migration adds three columns and two tables:

| Table | Added column | Physical SQLite definition |
|---|---|---|
| `wallets` | `emoji_icon_name` | `TEXT NULL` |
| `associated_titles` | `archived` | `INTEGER NOT NULL DEFAULT (0) CHECK ("archived" IN (0, 1))` |
| `scanner_templates` | `default_title` | `TEXT NULL DEFAULT (NULL)` |

The schema-46 source lacks all three fields ([wallet](https://github.com/jameskokoska/Cashew/blob/9cfbe50c16d95429891d44faf5f2c77a3abdb93b/budget/lib/database/tables.dart#L250-L271), [associated title](https://github.com/jameskokoska/Cashew/blob/9cfbe50c16d95429891d44faf5f2c77a3abdb93b/budget/lib/database/tables.dart#L394-L408), [scanner template](https://github.com/jameskokoska/Cashew/blob/9cfbe50c16d95429891d44faf5f2c77a3abdb93b/budget/lib/database/tables.dart#L487-L511)).

The new tag table is:

```sql
CREATE TABLE "tags" (
  "date_created" INTEGER NOT NULL,
  "date_time_modified" INTEGER NULL,
  "order" INTEGER NOT NULL,
  "archived" INTEGER NOT NULL DEFAULT 0
    CHECK ("archived" IN (0, 1)),
  "name" TEXT NOT NULL,
  "colour" TEXT NULL,
  "icon_name" TEXT NULL,
  "emoji_icon_name" TEXT NULL,
  "tag_pk" TEXT NOT NULL,
  PRIMARY KEY ("tag_pk")
);
```

The new many-to-many junction is:

```sql
CREATE TABLE "transaction_to_tag_links" (
  "transaction_pk" TEXT NULL
    REFERENCES transactions ("transaction_pk"),
  "tag_pk" TEXT NULL
    REFERENCES tags ("tag_pk"),
  PRIMARY KEY ("transaction_pk", "tag_pk")
);
```

Important physical details:

- Tags are independent of categories; there is no category foreign key on `tags`.
- A transaction can have multiple tags and a tag can belong to multiple transactions.
- The junction contains no timestamps, order, archive flag, or source metadata.
- Both junction foreign-key columns are physically nullable.
- Neither foreign key declares `ON DELETE CASCADE`.
- The composite primary key prevents duplicate non-null pairs, but SQLite rowid tables can still admit problematic null-key rows. An importer must validate links rather than assuming the DDL guarantees a complete pair.

### 3.3 No other physical changes from schema 46

After accounting for the five added columns and two added tables above, the names, types, nullability, defaults, primary keys, and declared foreign keys of the schema-46 columns match the user's schema-48 export.

In particular, schema 48 does **not** add a tag-list column to `transactions`; tag membership exists only through `transaction_to_tag_links`.

## 4. Enum Changes

Cashew persists several Dart enum ordinals as SQLite integers or JSON integer lists. The public schema-46 declarations are visible in `tables.dart` ([core enums](https://github.com/jameskokoska/Cashew/blob/9cfbe50c16d95429891d44faf5f2c77a3abdb93b/budget/lib/database/tables.dart#L42-L97), [delete/update log enums](https://github.com/jameskokoska/Cashew/blob/9cfbe50c16d95429891d44faf5f2c77a3abdb93b/budget/lib/database/tables.dart#L214-L242)). The deployed schema-48 bundle exposes the following deltas.

### 4.1 Persisted and migration-relevant

| Enum | Schema 46 | Deployed schema 48 | Impact |
|---|---|---|---|
| `DeleteLogType` | `0 Wallet`, `1 Category`, `2 Budget`, `3 CategoryLimit`, `4 Transaction`, `5 AssociatedTitle`, `6 ScannerTemplate`, `7 Objective`, `8 Unused` | ordinals `0–5` unchanged; `6 Objective`, `7 Unused`, `8 Tag` | **Unsafe ordinal reuse.** Old values `6–8` do not retain their schema-46 meanings. |
| `HomePageWidgetDisplay` | `0 WalletSwitcher`, `1 WalletList`, `2 NetWorth`, `3 AllSpendingSummary`, `4 PieChart` | appends `5 StackedBarGraph`, `6 LineGraph` | Existing ordinals are stable. New values may occur in `wallets.home_page_widget_display` JSON. |

`DeleteLogType` is stored in `delete_logs.type`, so its reassignment is the critical incompatibility. Neither `46 → 47` nor `47 → 48` rewrites existing delete-log integers in the deployed migration. A schema-48 database can therefore contain tombstones created under more than one ordinal interpretation.

**Lootr rule:** do not use `delete_logs` to infer historical deleted financial records during the one-time import. It is Cashew sync state, not ledger data. If a future incremental importer needs tombstones, it must identify the originating app/schema semantics more precisely than `PRAGMA user_version = 48`, or reject ambiguous types `6–8`.

### 4.2 Changed but not directly stored as one ordinal column

| Enum | Schema 46 | Deployed schema 48 | Impact |
|---|---|---|---|
| `UpdateLogType` | same `0–8` layout as schema-46 `DeleteLogType` | same reassignment as schema-48 `DeleteLogType` | Affects Cashew sync/update protocol, not a dedicated SQLite enum column. |
| `PaidStatus` | `0 paid`, `1 notPaid`, `2 skipped` | `0 paid`, `1 notPaid`, `2 markedPaid`, `3 markedSkipped` | UI/computed status changed. Stored payment state remains the `paid` and `skip_paid` booleans. |

### 4.3 Stable ordinals

The deployed schema-48 bundle retains the schema-46 ordering for:

- `BudgetReoccurence`: `custom`, `daily`, `weekly`, `monthly`, `yearly`;
- `TransactionSpecialType`: `upcoming`, `subscription`, `repetitive`, `credit`, `debt`;
- `ObjectiveType`: `goal`, `loan`;
- `BudgetTransactionFilters`;
- `MethodAdded`;
- `SharedStatus`;
- `SharedOwnerMember`;
- `ExpenseIncome`.

The existing schema-46 transaction, objective, recurrence, and sharing mappings therefore remain valid for live rows in schema 48. The enum hazard is concentrated in sync logs, not the core transaction ledger.

## 5. Lootr Migration Implications

### 5.1 Add explicit source adapters

The Cashew importer should recognize at least:

| Source schema | Required structural behavior |
|---:|---|
| `46` | Existing ten-table adapter. No account/category archive state or first-class tags. |
| `47` | Schema 46 plus archived accounts and categories. |
| `48` | Schema 47 plus wallet emoji, archived associated titles, scanner default title, tags, and transaction-tag links. |

Detection must combine `PRAGMA user_version` with required-table/column checks. Do not silently treat an unknown future schema as 48 merely because its first ten tables look familiar.

### 5.2 Preserve archive state

- `wallets.archived` should map to a Lootr account archive/hidden state when that target capability exists.
- `categories.archived` should map to a category archive/hidden state.
- `associated_titles.archived` means an old Cashew categorization rule is intentionally inactive. Do not reactivate it during import.
- If Lootr cannot represent one of these states at import time, preserve the flag in source provenance and default the entity/rule to inactive rather than deleting it.

### 5.3 Preserve account visuals without conflating identity

Schema 48 adds `wallets.emoji_icon_name`; it is presentation metadata, not an account identifier. Preserve it alongside the already known color/icon/order/decimal fields. A missing or unsupported visual must never prevent financial import.

### 5.4 Add tags to the staging model

The prior schema-46 migration assessment did not include Cashew's new tag model. Schema-48 staging now needs:

```text
source_tag
  source_tag_pk
  name
  colour
  icon_name
  emoji_icon_name
  order
  archived
  created_at
  modified_at

source_transaction_tag_link
  source_transaction_pk
  source_tag_pk
  validation_state
```

Lootr currently has no first-class transaction-tag table. V1 must choose one of two loss-aware paths:

1. add Lootr `tags` and `transaction_tag_links` tables; or
2. preserve tag definitions and exact source transaction associations in the encrypted migration archive until first-class tags ship.

Do not flatten a Cashew tag into a category, payee, or note. Tags are orthogonal, many-to-many classification and may coexist with all three.

### 5.5 Validate the junction defensively

During dry run:

1. reject or preserve-with-warning any link with a null transaction or tag key;
2. report dangling transaction/tag references;
3. deduplicate exact pairs in staging;
4. import archived tags without showing them as active choices;
5. reconcile the number of accepted, preserved, and rejected associations.

The source database should remain untouched even if link defects are found.

### 5.6 Treat scanner templates as preserved automation data

`scanner_templates.default_title` is not a normal transaction title. It is a default used by Cashew's message-scanning automation. Lootr should preserve the template and field in legacy data; it should not enable automatic transaction creation or silently convert the value into a payee.

### 5.7 Keep sync tombstones out of the ledger import

Because of the `DeleteLogType` ordinal reassignment, `delete_logs` must not drive:

- deletion of imported accounts, categories, objectives, or tags;
- inferred “missing transaction” records;
- reconciliation of live balances.

For the one-time migration, live application tables are authoritative. Preserve delete-log metadata only if needed for auditability, clearly marked as uninterpreted Cashew sync state.

## 6. Remaining Limits

This note resolves the schema-version mismatch and the structural/enum delta. Because it intentionally did not inspect application rows, it does not establish:

- whether this particular export contains any tag definitions or tag links;
- whether archived accounts, categories, or associated titles are present;
- whether nullable or dangling tag links exist;
- which values appear in `delete_logs.type`;
- the exact installed Android app version.

Those questions can be answered by a separate privacy-preserving aggregate audit using counts, value domains, relationship checks, and redacted samples where the user explicitly permits them. None is required to recognize schema 48 or implement its adapter safely.

## 7. Decision

**Adopt schema 48 as the primary Cashew V1 import target.** Retain schema 46/47 compatibility for other backups, add tags and archive state to canonical staging, and prohibit delete-log ordinal interpretation in the initial one-time import.

The public Cashew repository remains useful for stable schema-46 semantics, but it is no longer a sufficient source of truth for current exported databases. Until newer Dart source is published, pin the official deployed bundle hash used here in importer fixtures and validate the adapter against the user's physical schema-48 DDL.

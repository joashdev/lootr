# Cashew Real Export Audit

Redacted, read-only forensic audit of the user's fresh Cashew database export.

References: `cashew-data-migration.md` (migration rules and acceptance criteria), `database-schema.md` (Lootr target model), local Cashew source commit `9cfbe50c16d95429891d44faf5f2c77a3abdb93b` (schema 46 reference).

---

## 1. Scope and Privacy Boundary

This audit inspected `/Users/joashdev/Downloads/cashew-2026-07-18-22-06-43-812839.sql` without modifying it. Despite the extension, the file is a SQLite database, not SQL text.

The report intentionally excludes transaction titles, notes, account/category/objective names, counterparties, emails, source IDs, URLs, row contents, exact individual amounts, exact aggregate balances, and settings values. Account and currency labels (`A1`, `C1`, and so on) are report-local aliases with no exported identity meaning.

The database was opened with `sqlite3 -readonly`; every audit session enabled `PRAGMA query_only=ON`. The source hash was recorded before the audit, and no write-capable database connection was used.

## 2. File Identity

| **Property** | **Observed** |
|---|---|
| File type | SQLite 3 database |
| Size | 1,114,112 bytes |
| SHA-256 | `ab03aff4be270fc66dd92d2374f236f23bf894bea0e3d7927daaa67def1ffdbb` |
| File modification time | 2026-07-18T14:09:11Z / 2026-07-18T22:09:11+08:00 |
| `user_version` | 48 |
| File header writer version | SQLite 3.52.0 |
| Audit CLI version | SQLite 3.43.2 |
| Page size / page count | 4,096 bytes / 272 pages |
| Journal mode / encoding | `delete` / UTF-8 |

## 3. Database Health

| **Check** | **Result** |
|---|---|
| `PRAGMA integrity_check` | `ok` |
| `PRAGMA quick_check` | `ok` |
| `PRAGMA foreign_key_check` | 15 historical reference violations |

The 15 foreign-key findings are explainable by Cashew deletion history rather than unreadable database structure:

| **Child relation** | **Count** | **Finding** |
|---|---:|---|
| `budgets.wallet_fk` | 3 | All point to one deleted wallet identity; every row has a matching wallet deletion log. |
| `objectives.wallet_fk` | 1 | Points to a deleted wallet identity and has a matching wallet deletion log. |
| `transactions.paired_transaction_fk` | 11 | All point to one deleted transaction identity; every row has a matching transaction deletion log. |

No other declared foreign-key relation has an orphan. The importer must not discard these rows or recreate deleted parents silently. It should classify them as preserved/review-required with the matching tombstone evidence.

## 4. Schema 48 Inventory

### 4.1 Table counts

| **Table** | **Rows** |
|---|---:|
| `app_settings` | 1 |
| `associated_titles` | 277 |
| `budgets` | 5 |
| `categories` | 23 |
| `category_budget_limits` | 0 |
| `delete_logs` | 1,971 |
| `objectives` | 8 |
| `scanner_templates` | 0 |
| `tags` | 0 |
| `transaction_to_tag_links` | 0 |
| `transactions` | 2,065 |
| `wallets` | 19 |

### 4.2 Differences from the local schema-46 source

The export is two schema revisions ahead of the inspected local Cashew checkout. Compared with the schema-46 Drift definitions, schema 48 adds:

| **Area** | **Schema-48 addition** | **Data present here?** |
|---|---|---|
| Tags | New `tags` table with identity, display, order, archive, and timestamp columns | No rows |
| Transaction tags | New `transaction_to_tag_links` composite-key link table | No rows |
| Wallets | `archived`, `emoji_icon_name` | All wallets are unarchived; physical emoji values were not inspected. |
| Categories | `archived` | All categories are unarchived. |
| Associated titles | `archived` | All rules are unarchived. |
| Scanner templates | `default_title` | Table is empty. |

Existing schema-46 tables otherwise retain the expected physical column names and types used by `cashew-data-migration.md`. The importer still needs an explicit schema-48 adapter. It must not merely accept `user_version >= 46`.

The companion `cashew-schema-48-delta.md` recovered the exact v47/v48 migrations and enum declarations from Cashew's official deployed build. Core transaction, recurrence, budget, objective, and sharing ordinals remain stable. `DeleteLogType` ordinals `6–8` were reassigned without rewriting old rows, so tombstone types must not drive the one-time import.

## 5. Date Encoding and Bounds

Dates are stored physically as Unix-second integers. Bounds below are rendered in UTC; this audit did not infer the user's intended local calendar date from raw transaction content.

| **Field** | **Minimum UTC** | **Maximum UTC** |
|---|---|---|
| `wallets.date_created` | 2024-11-14 08:01:54 | 2025-10-15 12:15:09 |
| `transactions.date_created` | 2024-05-31 16:00:01 | 2027-05-16 02:29:07 |
| `transactions.original_date_due` | 2024-04-18 01:29:07 | 2026-07-17 04:00:31 |
| `transactions.date_time_modified` | 2024-11-15 10:40:28 | 2026-07-17 04:25:38 |
| `categories.date_created` | 2024-03-27 14:29:32 | 2025-09-25 10:40:58 |
| `budgets.start_date` | 2024-10-31 16:00:00 | 2025-08-31 16:00:00 |
| `budgets.end_date` | 2024-11-15 10:45:23 | 2025-09-29 03:22:34 |
| `objectives.date_created` | 2023-12-31 16:00:00 | 2025-11-18 02:27:30 |
| `delete_logs.date_time_modified` | 2024-11-15 10:12:54 | 2026-07-16 14:08:02 |

Twelve transactions are dated after the export time, and all twelve are unpaid. These are planned/recurring future records, not ledger balance rows.

`original_date_due` is physically populated on every transaction, but 1,815 normal transactions contain the schema migration default timestamp `1713403747`. The adapter must treat that value as “not applicable” for those rows rather than as a real due date. The remaining special-type rows require the original-due field to be preserved.

Timezone remains unresolved. Cashew does not persist a per-transaction timezone, and the settings object has no verified timezone field. Before import sign-off, a local-date sample must be compared in Cashew and Lootr without recording the sampled private content in logs or fixtures.

## 6. Numeric Enum Distributions

These are physical codes only. Names inferred from schema 46 must remain adapter-versioned.

### 6.1 Transactions

| **Field** | **Code** | **Rows** |
|---|---:|---:|
| `income` | 0 | 1,650 |
| `income` | 1 | 415 |
| `paid` | 0 | 18 |
| `paid` | 1 | 2,047 |
| `skip_paid` | 0 | 808 |
| `skip_paid` | 1 | 1,257 |
| `type` | NULL | 1,815 |
| `type` | 0 | 6 |
| `type` | 1 | 10 |
| `type` | 2 | 233 |
| `type` | 3 | 1 |
| `reoccurrence` | NULL | 375 |
| `reoccurrence` | 1 | 123 |
| `reoccurrence` | 2 | 18 |
| `reoccurrence` | 3 | 1,547 |
| `reoccurrence` | 4 | 2 |
| `method_added` | NULL | 1,972 |
| `method_added` | 2 | 93 |
| `created_another_future_transaction` | 0 | 1,830 |
| `created_another_future_transaction` | 1 | 235 |
| `upcoming_transaction_notification` | 1 | 2,065 |
| `shared_status` | NULL | 2,065 |

All 2,065 transaction signs agree with the `income` flag, and there are no zero-amount rows. No exact amounts were retained in this report.

### 6.2 Other tables

| **Field** | **Code** | **Rows** |
|---|---:|---:|
| `budgets.reoccurrence` | 3 | 5 |
| `budgets.added_transactions_only` | 0 | 1 |
| `budgets.added_transactions_only` | 1 | 4 |
| `objectives.type` | 0 | 5 |
| `objectives.type` | 1 | 3 |
| `delete_logs.type` | 0 | 3 |
| `delete_logs.type` | 1 | 1 |
| `delete_logs.type` | 2 | 2 |
| `delete_logs.type` | 4 | 47 |
| `delete_logs.type` | 5 | 1,915 |
| `delete_logs.type` | 6 | 3 |
| `wallets.decimals` | 2 | 15 |
| `wallets.decimals` | 4 | 1 |
| `wallets.decimals` | 12 | 3 |

All budgets, objectives, wallets, categories, associated-title rules, and tags are unarchived. All eight objectives are pinned. Category `method_added` is NULL for every category.

## 7. Account and Currency Reconciliation

Cashew stores no independent wallet balance scalar. Therefore, this audit can verify that the proposed Lootr transformation—signed amount to positive magnitude plus direction—reconstructs Cashew's paid ledger exactly at each account's configured precision. It cannot compare against a separately stored closing balance.

There are 19 accounts across 3 currencies, with no missing currency value.

| **Account** | **Currency** | **Decimals** | **All rows** | **Paid rows** | **Sign mismatches** | **Projected ledger** |
|---|---|---:|---:|---:|---:|---|
| A1 | C2 | 2 | 992 | 992 | 0 | PASS — zero delta |
| A2 | C2 | 2 | 45 | 44 | 0 | PASS — zero delta |
| A3 | C2 | 4 | 63 | 63 | 0 | PASS — zero delta |
| A4 | C3 | 12 | 1 | 1 | 0 | PASS — zero delta |
| A5 | C2 | 2 | 2 | 2 | 0 | PASS — zero delta |
| A6 | C2 | 2 | 45 | 45 | 0 | PASS — zero delta |
| A7 | C2 | 2 | 208 | 207 | 0 | PASS — zero delta |
| A8 | C1 | 12 | 1 | 1 | 0 | PASS — zero delta |
| A9 | C2 | 2 | 10 | 10 | 0 | PASS — zero delta |
| A10 | C2 | 2 | 5 | 5 | 0 | PASS — zero delta |
| A11 | C2 | 2 | 23 | 22 | 0 | PASS — zero delta |
| A12 | C2 | 2 | 533 | 521 | 0 | PASS — zero delta |
| A13 | C2 | 2 | 47 | 47 | 0 | PASS — zero delta |
| A14 | C2 | 2 | 1 | 1 | 0 | PASS — zero delta |
| A15 | C2 | 2 | 31 | 30 | 0 | PASS — zero delta |
| A16 | C2 | 2 | 29 | 29 | 0 | PASS — zero delta |
| A17 | C2 | 2 | 26 | 24 | 0 | PASS — zero delta |
| A18 | C2 | 2 | 2 | 2 | 0 | PASS — zero delta |
| A19 | C2 | 12 | 1 | 1 | 0 | PASS — zero delta |

Currency-level reconstruction also passes with zero delta:

| **Currency** | **Accounts** | **All rows** | **Paid rows** | **Result** |
|---|---:|---:|---:|---|
| C1 | 1 | 1 | 1 | PASS — zero delta |
| C2 | 17 | 2,063 | 2,045 | PASS — zero delta |
| C3 | 1 | 1 | 1 | PASS — zero delta |

The presence of 4- and 12-decimal accounts is a real V1 requirement. Lootr must not assume two-decimal currency precision or round source amounts before final reconciliation.

## 8. Transfers and Balance Corrections

Cashew uses one-way pair references: one leg points at the other, and the target leg does not point back.

| **Measure** | **Count** |
|---|---:|
| Category-0 transaction rows | 591 |
| Resolved undirected pairs | 269 |
| Same-currency pairs | 269 |
| Cross-currency pairs | 0 |
| Different-account pairs | 264 |
| Same-account pairs | 5 |
| Equal absolute-magnitude pairs | 266 |
| Unequal absolute-magnitude pairs | 3 |
| Both-paid pairs | 264 |
| Both-unpaid pairs | 5 |
| Opposite-direction pairs | 269 |
| Dangling pair references | 11 |

The five same-account pairs and three unequal-magnitude pairs are disjoint, producing eight structural exception pairs requiring review. All resolved pairs have matching paid state. Cross-currency transfer handling remains required by the general migration specification, but it is not exercised by this export.

Of the 269 resolved pairs, 267 have category 0 on both legs. Two paired relationships have non-zero categories on both legs and should not be auto-converted to Lootr transfers without review.

There are 65 paid category-0 rows with neither incoming nor outgoing pair references, spanning 16 accounts. They are balance corrections/opening-balance candidates. The importer must not classify all 65 as opening balances; it should apply the opening-balance policy from `cashew-data-migration.md §6.3` and preserve later corrections as explicit adjustments.

The 11 dangling references all target the same deleted transaction identity and have matching transaction tombstones. They are historical pair fragments, not random missing keys.

## 9. Recurring, Scheduled, and Future Rows

| **Measure** | **Count** |
|---|---:|
| Rows with recurrence metadata | 1,690 |
| Rows with only one of period/recurrence populated | 0 |
| IDs containing `::predict::` | 206 |
| IDs with a numeric prediction suffix | 206 |
| Malformed prediction suffixes | 0 |
| Distinct prediction bases | 31 |
| Smallest / largest observed prediction chain | 1 / 21 predicted rows |
| `created_another_future_transaction = 1` | 235 |
| Rows with a non-null recurrence end date | 85 |
| Unpaid rows | 18 |
| Unpaid and skip-flagged rows | 3 |
| Unpaid and not skip-flagged rows | 15 |
| Rows dated after export | 12 |

Prediction chains of lengths 1, 2, 4, 6, 7, 8, 12, 13, 18, and 21 are present, so the history is not limited to recent single successors. A source-series/occurrence model is required; reducing these rows to one Lootr recurring template would lose paid/skip/due history.

The misleading physical `skip_paid` flag is set on many already-paid normal rows. It must be interpreted using the matching schema-version behavior rather than mapped directly to a Lootr “skipped occurrence” boolean.

## 10. Goals, Loans, Debts, and Budgets

### 10.1 Objectives and debt shapes

| **Shape** | **Count** |
|---|---:|
| Objective code 0 | 5 |
| Objective code 1 | 3 |
| Objectives with an end date | 4 |
| Objective rows with a deleted wallet reference | 1 |
| Transactions linked through `objective_fk` | 127 paid / 0 unpaid |
| Distinct linked code-0 objectives | 5 |
| Transactions linked through `objective_loan_fk` | 108 paid / 0 unpaid |
| Distinct linked code-1 objectives | 3 |
| Standalone transaction type code 3 | 1 paid / 0 unpaid |
| Standalone transaction type code 4 | 0 |

This export uses both objective-linked loan history and a standalone credit/debt-style transaction. Lootr needs contribution/payment event relations; importing only objective scalar amounts would not keep the history intact.

### 10.2 Budget shapes

| **Shape** | **Count** |
|---|---:|
| Total budgets | 5 |
| Monthly recurrence code 3 | 5 |
| Added-transactions-only | 4 |
| Conventional non-added-only | 1 |
| Category scope/exclusion lists | 0 |
| Wallet scope lists | 0 |
| Category limit rows | 0 |
| Budget transaction filter payloads | 1 |
| Shared budgets | 0 |
| Absolute spending limits | 0 |
| Budgets with a deleted wallet reference | 3 |

All five budgets are monthly, but four depend on explicit transaction attachment and three reference one deleted wallet. They are not direct matches for Lootr's current one-category monthly budget table. The safe V1 policy is review plus preserved payload unless the target budget model is extended.

## 11. Categories, Rules, Tags, and Attachments

- All 23 categories are top-level; no category has a parent relation.
- There are 277 associated-title rules: 277 contains-match, 0 exact-match, 0 archived, and 0 orphaned.
- Tags and transaction-tag links are structurally available in schema 48 but empty in this export.
- There are 36 Google Drive link occurrences across 35 transaction notes. No URL was printed, stored in this report, or accessed over the network.
- Link accessibility was not tested. Doing so would require reading and opening private URLs and possibly an authenticated Drive session. The importer should preserve the URL text locally and label attachment bytes as not yet migrated.

The semantic question “merchant name versus free-form description” was deliberately not answered by reading private titles. Lootr must preserve the exact Cashew title and avoid irreversible automatic payee normalization during import.

## 12. Settings JSON

`app_settings.settings_j_s_o_n` is valid JSON, is a top-level object, and contains 404 top-level keys. Values were not reported.

Migration-relevant, non-sensitive key names confirmed present include:

- `cachedCurrencyExchange`, `customCurrencies`, `customCurrencyAmounts`;
- `dateFormat`, `dateOrder`, `firstDayOfWeek`, `use24HourFormat`;
- `numberFormatCurrencyFirst`, `numberFormatDecimal`, `numberFormatDelimiter`, `percentagePrecision`;
- `automaticallyPayRepetitive`, `automaticallyPaySubscriptions`, `automaticallyPayUpcoming`, `markAsPaidOnOriginalDay`;
- `autoBackups`, `autoBackupsLocal`, `backupSync`;
- `selectedWalletPk`, `pinnedTransactionPks`, `watchedCategoriesOnBudget`.

The object also contains privacy-sensitive identity/authentication/integration settings. Their key names and values are intentionally omitted from this report. The import staging archive must be encrypted before retaining the settings payload.

Custom-currency semantics cannot be determined from key presence alone without reading settings values. The source adapter must treat all three observed currency identifiers and each wallet's decimal precision as opaque source data until the user approves a mapping.

## 13. Lootr Blockers Confirmed by This Export

The real export converts several previously theoretical gaps in `cashew-data-migration.md §7–8` into V1 requirements:

1. **Schema-48 source adapter.** Add explicit detection for the two new tables and five new archive/tag-related column areas; do not assume schema 46.
2. **Encrypted import run, provenance, and preserved-payload tables.** Required before any real financial content is staged.
3. **Arbitrary account precision.** Three accounts use 12 decimals and one uses 4; two-decimal storage or early rounding is unsafe.
4. **One-way transfer pairing plus exception review.** Handle 269 resolved pairs, eight structural exceptions, two non-category-0 relationships, 11 tombstoned fragments, and 65 unpaired corrections.
5. **Recurring occurrence history.** Preserve 31 prediction series, long historical chains, paid/unpaid/skip state, original due dates, and future rows.
6. **Goal and loan event relations.** The export contains 235 linked contribution/payment rows across all eight objectives.
7. **Flexible/imported budget preservation.** Four added-only budgets and deleted-wallet references do not fit Lootr's current budget table.
8. **Deleted-parent policy.** Budget, objective, and pair fragments must retain deletion-log provenance rather than being silently dropped or rebound.
9. **Durable categorization rules.** The 277 contains-match title rules are valuable learned behavior and need a local rule table or preserved payload.
10. **Attachment metadata.** Preserve 36 Drive links without claiming attachment-byte migration.
11. **Timezone confirmation.** Unix seconds are verified, but intended local calendar interpretation still needs a private on-device comparison.
12. **Title/payee review.** Exact titles must survive import; automatic conversion to normalized Lootr payees must be reversible or user-reviewed.

## 14. Recommended Next Implementation Slice

Do not build the final mapper first. The next safe slice is:

1. implement and verify SQLCipher plus the temporary-plaintext lifecycle;
2. add the local-only import-run, provenance, and preserved-payload schema;
3. implement a read-only schema-48 Cashew adapter and a redacted dry-run report;
4. create synthetic fixtures matching this audit's counts and edge shapes, never copied row values;
5. implement account/category/rule staging with opaque source IDs and precision preservation;
6. implement transfer/correction classification and review issue codes;
7. implement recurring occurrence staging;
8. add goal/loan contribution events and explicit-membership budget handling;
9. run an import into a disposable Lootr database and require zero-delta reconciliation for all 19 anonymized account partitions before publishing any data.

The export is healthy enough to support migration development. It is not safe to claim complete compatibility until schema 48, tombstoned references, recurrence history, and target-model gaps are implemented.

## 15. Remaining Uncertainties

- The public schema-46 checkout does not contain the newer migration code; the official deployed-build evidence pinned in `cashew-schema-48-delta.md` must remain part of the adapter fixture.
- The user's intended local dates have not yet been compared against Cashew's visible UI.
- Currency identifiers and custom currency definitions were not disclosed in this redacted audit.
- Drive attachment accessibility was not tested.
- Transaction titles were not semantically classified as merchants versus descriptions.
- Bill-splitter draft state is not stored in this database export and therefore was not audited.
- No independent stored wallet balance exists, so reconciliation proves transform equivalence, not agreement with a second source balance scalar.

## Appendix A. Redacted Audit Queries

Every query below returns only schema metadata, counts, dates, codes, aliases, or pass/fail results. None selects user text, IDs, URLs, or monetary values.

```sql
PRAGMA query_only=ON;
PRAGMA user_version;
PRAGMA integrity_check;
PRAGMA quick_check;
PRAGMA foreign_key_check;
```

```sql
SELECT type, name, tbl_name
FROM sqlite_master
WHERE name NOT LIKE 'sqlite_%'
ORDER BY type, name;

SELECT m.name AS table_name,
       p.cid,
       p.name AS column_name,
       p.type,
       p.[notnull] AS not_null,
       p.pk,
       COALESCE(p.dflt_value, '') AS default_value
FROM sqlite_master AS m
JOIN pragma_table_info(m.name) AS p
WHERE m.type = 'table' AND m.name NOT LIKE 'sqlite_%'
ORDER BY m.name, p.cid;
```

```sql
SELECT [table], parent, fkid, COUNT(*) AS violation_count
FROM pragma_foreign_key_check
GROUP BY [table], parent, fkid
ORDER BY [table], fkid;
```

```sql
WITH labeled_wallets AS (
  SELECT wallet_pk,
         currency,
         decimals,
         'A' || ROW_NUMBER() OVER (ORDER BY wallet_pk) AS account_label
  FROM wallets
), currencies AS (
  SELECT currency,
         'C' || DENSE_RANK() OVER (ORDER BY currency) AS currency_label
  FROM (SELECT DISTINCT currency FROM labeled_wallets)
), ledger AS (
  SELECT w.account_label,
         c.currency_label,
         w.decimals,
         COUNT(t.transaction_pk) AS all_rows,
         SUM(CASE WHEN t.paid = 1 THEN 1 ELSE 0 END) AS paid_rows,
         SUM(CASE WHEN t.paid = 1 AND
                       ((t.income = 1 AND t.amount < 0) OR
                        (t.income = 0 AND t.amount > 0))
                  THEN 1 ELSE 0 END) AS sign_flag_mismatches,
         SUM(CASE WHEN t.paid = 1 THEN t.amount ELSE 0 END) AS source_sum,
         SUM(CASE WHEN t.paid = 1
                  THEN CASE WHEN t.income = 1
                            THEN ABS(t.amount) ELSE -ABS(t.amount) END
                  ELSE 0 END) AS projected_sum
  FROM labeled_wallets AS w
  JOIN currencies AS c ON c.currency = w.currency
  LEFT JOIN transactions AS t ON t.wallet_fk = w.wallet_pk
  GROUP BY w.account_label, c.currency_label, w.decimals
)
SELECT account_label,
       currency_label,
       decimals,
       all_rows,
       paid_rows,
       sign_flag_mismatches,
       CASE WHEN ROUND(source_sum - projected_sum, decimals) = 0
            THEN 'PASS_ZERO_DELTA' ELSE 'FAIL_NONZERO_DELTA' END AS reconciliation
FROM ledger
ORDER BY CAST(SUBSTR(account_label, 2) AS INTEGER);
```

```sql
WITH refs AS (
  SELECT t.transaction_pk AS src_pk,
         p.transaction_pk AS dst_pk,
         t.wallet_fk AS src_wallet,
         p.wallet_fk AS dst_wallet,
         ws.currency AS src_currency,
         wd.currency AS dst_currency,
         t.amount AS src_amount,
         p.amount AS dst_amount,
         t.paid AS src_paid,
         p.paid AS dst_paid
  FROM transactions AS t
  JOIN transactions AS p ON p.transaction_pk = t.paired_transaction_fk
  JOIN wallets AS ws ON ws.wallet_pk = t.wallet_fk
  JOIN wallets AS wd ON wd.wallet_pk = p.wallet_fk
), pairs AS (
  SELECT CASE WHEN src_pk < dst_pk THEN src_pk ELSE dst_pk END AS p1,
         CASE WHEN src_pk < dst_pk THEN dst_pk ELSE src_pk END AS p2,
         MAX(src_wallet = dst_wallet) AS same_wallet,
         MAX(COALESCE(src_currency, '') = COALESCE(dst_currency, '')) AS same_currency,
         MAX(ABS(ABS(src_amount) - ABS(dst_amount)) < 0.000000001) AS same_magnitude,
         MAX(src_paid = 1 AND dst_paid = 1) AS both_paid,
         MAX(src_paid = 0 AND dst_paid = 0) AS both_unpaid
  FROM refs
  GROUP BY 1, 2
)
SELECT COUNT(*) AS pair_count,
       SUM(same_wallet) AS same_wallet,
       SUM(NOT same_wallet) AS different_wallet,
       SUM(same_currency) AS same_currency,
       SUM(NOT same_currency) AS cross_currency,
       SUM(same_magnitude) AS equal_magnitude,
       SUM(NOT same_magnitude) AS unequal_magnitude,
       SUM(both_paid) AS both_paid,
       SUM(both_unpaid) AS both_unpaid
FROM pairs;
```

```sql
WITH predicted AS (
  SELECT SUBSTR(transaction_pk, 1, INSTR(transaction_pk, '::predict::') - 1) AS base_id,
         SUBSTR(transaction_pk, INSTR(transaction_pk, '::predict::') + 11) AS suffix
  FROM transactions
  WHERE INSTR(transaction_pk, '::predict::') > 0
), chains AS (
  SELECT base_id, COUNT(*) AS predicted_rows
  FROM predicted
  GROUP BY base_id
)
SELECT (SELECT COUNT(*) FROM predicted) AS marker_rows,
       (SELECT SUM(suffix <> '' AND suffix NOT GLOB '*[^0-9]*') FROM predicted) AS numeric_suffix_rows,
       (SELECT COUNT(*) FROM chains) AS base_count,
       (SELECT MIN(predicted_rows) FROM chains) AS min_chain_rows,
       (SELECT MAX(predicted_rows) FROM chains) AS max_chain_rows;
```

```sql
SELECT json_valid(settings_j_s_o_n) AS json_valid,
       json_type(settings_j_s_o_n) AS json_type,
       COUNT(*) AS rows
FROM app_settings
GROUP BY 1, 2;

SELECT COUNT(*) AS top_level_key_count
FROM app_settings, json_each(app_settings.settings_j_s_o_n);

SELECT SUM(CASE WHEN INSTR(LOWER(note), 'drive.google.com') > 0 THEN 1 ELSE 0 END)
         AS transactions_with_drive_links,
       SUM((LENGTH(LOWER(note)) -
            LENGTH(REPLACE(LOWER(note), 'drive.google.com', ''))) /
           LENGTH('drive.google.com')) AS drive_link_occurrences
FROM transactions;
```

# Cashew Migration Operator Guide — Personal Finance App
References: `cashew-data-migration.md` (migration contract), `security-model.md` (local protection), `database-schema.md` (target and import storage).

Safe operating instructions for moving a Cashew data-file export into Lootr.

---

## 1. Safety Before Starting

- Keep the original Cashew export outside the Lootr repository and retain an untouched copy.
- Select Cashew's **Export data file** output. It has a `.sql` extension but is a SQLite database, not a text script.
- Do not open, rename, edit, or run database migrations against the source.
- Make a current Lootr backup before importing into a database that already contains data.
- Keep the device powered and Lootr in the foreground during publication. Analysis can be cancelled safely before publication.

Lootr copies the selected file into app-private staging, opens it read-only with SQLite query-only mode, and fingerprints it before analysis. Staging is removed after completion, cancellation, rollback, or a recoverable failure. Flash storage may retain historical blocks despite best-effort overwrite and deletion, so device encryption remains part of the protection model.

## 2. Run a Privacy-Preserving Dry Run

1. Open **More → Settings → Data & Backup → Import from Cashew**.
2. Choose the Cashew data file.
3. Select **Analyze on this device**.
4. Confirm that the detected schema is supported and the source integrity check passes.
5. Review only the redacted structural summary: accounts, date range, currencies, source-row dispositions, warnings, review groups, and blocking issues.

Analysis does not write financial records to Lootr. Unknown future schemas, failed integrity checks, invalid enum domains, malformed dates, and broken required relationships block publication. Valid information without a safe editable equivalent is labeled **Preserved for later**.

## 3. Review Discrepancies and Policies

Resolve every **Needs review** group or explicitly accept its conservative disposition. Pay particular attention to:

- transfer exceptions, including unequal, dangling, same-account, or non-transfer pairs;
- missing or deleted account references in budgets and objectives;
- future, unpaid, skipped, and ambiguous recurring occurrences;
- attachment links, scanner settings, tags, and source-only metadata;
- budget inclusion and exclusion memberships.

Confirm the timezone used to interpret source timestamps. Then choose the reversible title/payee policy and confirm the Lootr account type for every imported account. Exact learned-title rules take precedence over contains rules; archived or inactive rules do not apply.

Lootr never infers a currency conversion rate. Missing-wallet monetary metadata remains exact, uses an explicit unknown-currency review state, and is preserved for correction.

## 4. Publish and Reconcile

Choose **Import** only after the review groups and policies are acceptable. Lootr creates a pre-import checkpoint, applies the approved canonical data in one database transaction, verifies foreign keys and exact per-account/per-currency balances, and then publishes the completed run.

No partially imported dataset becomes visible. Exact transfer pairs are stored as transfers and excluded from spending. Cross-currency transfers retain separate source and destination amounts. Reports remain grouped by currency unless the user supplies an explicit conversion rate, source, timestamp, and rounding policy.

After completion, Lootr opens the latest imported month. The import summary provides redacted counts, provenance, preserved records, and rollback.

## 5. Resume, Cancel, or Recover

- **Before publication:** cancel removes private staging and leaves Lootr financial data unchanged.
- **Interrupted analysis:** reopen the run and analyze again.
- **Interrupted publication or verification:** select **Reconcile**. Lootr verifies a complete atomic publication; if no publication occurred, it returns the run to review; a partial or invalid result restores the checkpoint. If Lootr detects an unrelated local write after publication, it preserves both that write and the checkpoint and leaves the run interrupted for explicit recovery instead of restoring automatically. Startup also completes any interrupted rollback before repositories regain access.
- **Completed import:** use **Roll back import** to restore the exact pre-import database state.

Do not delete app data while a recovery or rollback is running.

## 6. Re-Import Safely

Re-importing the same source with the same policy is idempotent and creates no duplicate financial records. Lootr matches source fingerprint, stable source identity, and payload fingerprint.

For a newer Cashew export, Lootr does not silently overwrite a mapped record that was edited after import. The conflicting record remains review-required until the user resolves it.

## 7. Lootr Backup, Restore, and CSV

From **Data & Backup**:

- **Create encrypted backup** writes a versioned encrypted Lootr database package with a verified manifest.
- **Restore backup** validates the package version, key, integrity, foreign keys, and schema before replacing the live database.
- **Export transaction CSV** creates a readable, currency-aware transaction export. Treat it as plaintext and store or share it accordingly.

A backup includes imported relationships, provenance, review records, and preserved payloads. Restoring a backup reopens the database before repositories resume access. The backup-only manifest is not retained as live application data. If secure key storage is unavailable or an encrypted database loses its key, Lootr fails closed instead of creating a replacement database.

## 8. Verification Checklist

| **Check** | **Expected result** | **Action if different** |
|---|---|---|
| Source fingerprint | Same before and after use | Stop and restore the untouched source copy |
| Source integrity | Pass | Do not import |
| Source-row dispositions | Every row classified | Do not import |
| Blocking issues | Zero | Correct the source or use a supported export |
| Reconciliation | Zero delta at each source precision | Review the named structural group |
| Repeat import | Zero new financial records | Roll back and retain the diagnostic run |
| Rollback | Pre-import state restored | Restore the pre-import Lootr backup |
| Backup restore | Counts, relations, currencies, and balances match | Keep the original backup and stop |

## 9. Current Deliberate Limitations

- Attachment URLs are preserved without downloading or claiming migration of attachment bytes.
- Tags and tag links are adapted and preserved; dedicated tag-management UI remains deferred.
- Scanner defaults and other source-only settings are preserved but not executed.
- Ambiguous or missing-reference budgets/objectives remain visible in a useful read-only review state.
- Only structurally exact Cashew prediction chains become editable recurring templates; other valid history remains queryable and preserved.
- CSV is an export format, not a lossless Cashew import substitute.

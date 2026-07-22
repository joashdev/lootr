# Cashew Product Benchmark — Personal Finance App
References: `product-strategy.md` (Lootr principles and V1 scope), `database-schema.md` (current domain capacity), `navigation-arch.md` (interaction model), `design.md` (visual and accessibility rules), `security-model.md` (target privacy controls), `cashew-data-migration.md` (continuity plan).

What Lootr should preserve, adopt, improve, defer, and deliberately avoid after comparing the current app with Cashew.

---

## 1. Decision Summary

Lootr should not attempt Cashew feature parity in V1. Cashew is a mature general-purpose tracker whose main strength is **progressive power**: fast daily entry backed by flexible budgets, persistent filters, rich recurrence, detailed reports, broad personalization, multi-currency controls, bulk tools, and proven data escape hatches.

Lootr's stronger product direction is **opinionated clarity**: one-tap assisted capture, dedicated transfer semantics, normalized payees, salary-deduction support, explicit debt domains, a no-login local runtime, confirm-before-save assistance, and a calmer information hierarchy.

The V1 strategy is therefore:

1. **Remove switching risk** — lossless Cashew import, reconciliation, rollback, and a versioned Lootr backup/export.
2. **Finish the privacy promise** — encrypted local storage and a real device lock before importing the user's financial history.
3. **Protect familiar daily habits** — persistent filters, month/cycle review, learned payee/category suggestions, richer recurring states, report drill-down, and a small amount of dashboard customization.
4. **Keep Lootr's model cleaner** — do not copy Cashew's overloaded transaction record, file-level sync, hidden-gesture dependence, or configuration sprawl.
5. **Preserve unsupported Cashew semantics** — complex budgets, settings, and relationships must remain recoverable even when Lootr cannot make them editable in V1.

> **Replacement-readiness verdict:** Lootr has a credible implemented core, but it is not yet a safe replacement for the user's Cashew installation. Import/export, backup/restore, SQLCipher, biometric/PIN lock, and mixed-currency correctness are launch gates for this migration.

---

## 2. Scope, Evidence, and Truth Model

The comparison uses the local Cashew repository at commit `9cfbe50c16d95429891d44faf5f2c77a3abdb93b` and the current Lootr `main` branch as inspected on 2026-07-18.

Cashew claims are based on its first-party README, Drift schema, Flutter pages/widgets, settings defaults, import/export code, and promotional screenshots. Lootr claims are checked against both specs and current Flutter source.

| **Label** | **Meaning** |
|---|---|
| `Implemented` | Connected source-level UI/domain/persistence path exists. It was not necessarily device-tested for this assessment. |
| `Partial` | A real path exists, but an important behavior is stubbed, internally inconsistent, or disabled. |
| `Spec-only` | Documented as a target but absent from the running implementation. |
| `Deferred` | Explicitly outside the initial V1 boundary. |
| `Recommendation` | A product decision derived from the evidence, not a statement about current behavior. |

This distinction matters because Cashew is a shipped, mature app while several Lootr advantages are currently architectural intent rather than completed runtime behavior.

---

## 3. Comparative Capability Matrix

| **Capability** | **Cashew today** | **Lootr today** | **V1 decision** |
|---|---|---|---|
| Core ledger | Mature expense/income ledger with deep transaction attributes | Implemented accounts, categories, payees, transactions, and transfers | Preserve Lootr model |
| Fast capture | Calculator amount input, remembered titles, contextual defaults | Implemented NL quick add, voice dictation, OCR, manual form, preview, Undo | Combine strengths |
| Transfers | Paired transaction rows via `pairedTransactionFk` | Dedicated transfer entity excluded from spend analytics | Keep Lootr |
| Payees/titles | Free-text titles plus exact/contains category rules | Normalized payees; durable learned rules absent | Add local rules |
| Search/filter | Broad, persistent, visible, month-aware filters and bulk selection | Search/filter UI exists, but narrower and less persistent/visible | Expand in V1 |
| Month review | Infinite month paging and synchronized selector | Date-grouped list; no equivalent month-first review surface | Add in V1 |
| Budget periods | Daily, weekly, monthly, yearly, and custom | Calendar-month category targets only | Preserve on import; limited V1 expansion |
| Budget composition | Multi-account/category include/exclude rules, added-only mode, nested category limits | One category per budget | Defer full parity |
| Budget history | Historical cycles and comparisons | Month navigation and report calculation exist | Strengthen history/drill-down |
| Recurring lifecycle | Upcoming/subscription/repetitive, pay, skip, due-date provenance, optional auto-pay | Templates and local reminders exist; finalization is confirm-first | Add pay/skip/due history |
| Goals | Transaction-linked objective progress | Goal CRUD works; contribution history is only partially wired | Fix audit trail before import |
| Debts/loans | Credit/debt transaction types plus loan objectives | Separate social debt and liability-account domains; payment history partial | Keep model, fix events |
| Reports | Interactive line/pie/net-worth/budget views with ledger drill-down | Real category, income/expense, net-worth, and budget reports | Standardize drill-down |
| Dashboard | Deep module visibility/order and account scope controls | Curated safe-to-spend dashboard | Add bounded customization |
| Multi-currency | Account currency, precision, cached/custom rates, converted views | Currency labels exist; aggregates do not convert correctly | Gate mixed-currency reports |
| Bulk operations | Multi-select, total, delete, duplicate, reassign, attach | Primarily row-level actions | Add cleanup-focused subset |
| Import | Mature generic CSV mapping and Google Sheets import | No import path | Cashew importer is V1-critical |
| Export/backup | Paid-transaction CSV plus full SQLite file export/restore | No implemented export or restore | Versioned export is V1-critical |
| Cloud continuity | Google Drive backup/file-level device sync | V1 sync/auth disabled | Local backup first; keep V2 sync model |
| Device security | Biometric/device-credential lock available | Security screen is placeholder; DB is plain SQLite | Implement before real-data import |
| Privacy posture | Local-first core with optional Google/Drive/Gmail/sharing surfaces | No-login local runtime; on-device assistance; hardening incomplete | Lootr advantage after hardening |
| Household model | Feature-specific shared-budget machinery | Systematic user/household/role model, but V2-gated | Keep Lootr, defer activation |
| Automation | App links, quick actions, Sheets, Gmail/notification templates | Manual-first; NL/OCR/voice capture | Defer broad automation |
| Responsive UI | Mobile, web/PWA, side rail, double-column layouts | Mobile-first; responsive design specified | Tablet adaptation, not PWA parity |
| Personalization | Accent, fonts, icons, home, nav, number pad, formats, motion | Theme mode and curated design system | Bounded options only |
| Accessibility | Some semantics, tooltips, keyboard, contrast/motion controls; forced text scaling in places | Stronger documented rules; implementation needs runtime audit | Preserve Lootr rules |

Primary Cashew evidence: `Cashew/budget/lib/database/tables.dart:42-115,250-539`, `Cashew/budget/lib/pages/transactionFilters.dart:26-469`, `Cashew/budget/lib/pages/homePage/homePage.dart:178-219`, `Cashew/budget/lib/widgets/importCSV.dart`, `Cashew/budget/lib/widgets/exportDB.dart:11-64`.

Primary Lootr evidence: `lib/data/database/app_database.dart:25-73`, `lib/core/router/app_router.dart:85-376`, `lib/ai/nl_parser.dart:135-209`, `lib/ai/ocr_pipeline.dart:47-168`, `lib/application/providers/reports_provider.dart:163-433`.

---

## 4. Important Features Cashew Has That Lootr Lacks

### 4.1 Data ownership and switching safety

Cashew can export and restore its full SQLite database. Its normal CSV is useful for human inspection but exports only paid transactions and omits recurrence, transfer relationships, unpaid/skipped states, budget rules, and settings (`Cashew/budget/lib/widgets/exportCSV.dart:84-140`; `Cashew/budget/lib/widgets/exportDB.dart:11-64`).

Lootr currently has no import, versioned export, or backup/restore path. This is the largest practical gap because a local-first app without an escape hatch can lose the user's entire history on uninstall or device loss.

**Required response:** make a lossless Cashew importer and a versioned Lootr backup/export part of V1 acceptance, not a post-launch tool.

### 4.2 Flexible budgets

Cashew budgets are reusable queries with limits. They can span arbitrary periods, selected accounts, selected or excluded categories, explicitly added transactions, income or expense polarity, and per-category limits (`Cashew/budget/lib/database/tables.dart:375-388,422-475`).

Lootr currently models one advisory target for one category in one calendar month (`database-schema.md §3.9`). This is simpler and more teachable, but it cannot represent trip budgets, pay-cycle budgets, annual envelopes, broad category sets, or historical Cashew rules.

**Required response:** do not force complex imported budgets into incorrect monthly rows. Preserve the source rule losslessly and expose an imported read-only view; add flexible date-range/event budgets only if the user's real backup proves they are needed.

### 4.3 Recurring state and due-date history

Cashew treats scheduled money as a lifecycle: upcoming, subscription, repetitive, paid, skipped, original due date, next occurrence, optional end date, and notification (`Cashew/budget/lib/database/tables.dart:298-317`; `Cashew/budget/lib/struct/upcomingTransactionsFunctions.dart:192-323`).

Lootr has recurring templates and notifications, but not the same pay/skip state machine or original-due-date record.

**Required response:** add `due_at`, `resolved_at`, `resolution` (`paid`, `skipped`, `dismissed`), and occurrence provenance while retaining Lootr's rule that a reminder does not silently finalize a ledger entry.

### 4.4 Durable categorization memory

Cashew stores title-to-category rules with exact or partial matching (`Cashew/budget/lib/database/tables.dart:390-408`). Lootr normalizes payees and has deterministic categorization heuristics, but it lacks a durable user-correction rule model.

**Required response:** add an on-device rule table keyed by normalized payee/title, with visible suggestion, confidence/source, one-tap override, exact-before-contains precedence, and no silent retroactive mutation.

### 4.5 Persistent filters and bulk cleanup

Cashew persists filter state, shows active filters as selected controls/chips, supports month paging, interprets amount/month searches, and provides a selection mode for high-volume cleanup (`Cashew/budget/lib/pages/transactionFilters.dart:185-469`; `Cashew/budget/lib/widgets/selectedTransactionsAppBar.dart:76-805`).

Lootr's unified list and filter sheet are a sound base, but migration will expose the need for bulk recategorization, account movement, and deletion.

**Required response:** ship persistent visible filters and a narrow bulk-action set. Do not copy every Cashew batch operation into V1.

### 4.6 Correct multi-currency aggregation

Lootr accounts store a currency code, but current reports sum raw values across accounts and label the result using the selected user currency. This can misstate totals (`lib/application/providers/reports_provider.dart:191-219,317-365`).

Cashew has account precision, exchange-rate settings, cached/custom rates, and converted views (`Cashew/budget/lib/database/tables.dart:250-271`; `Cashew/budget/lib/pages/exchangeRatesPage.dart:240-320`).

**Required response:** until a rate model exists, separate aggregate reports by currency or block mixed-currency totals. Never display an unconverted sum as if it were a valid base-currency amount.

### 4.7 Actual local security controls

Lootr's security spec promises SQLCipher and device lock, but the current production database opens ordinary Drift SQLite and the biometric/PIN controls are placeholders (`lib/data/database/app_database.dart:50-73`; `lib/presentation/screens/more/settings/security_screen.dart:25-80`).

Cashew already exposes biometric/device-credential locking.

**Required response:** implement and verify encryption and lock migration before real Cashew data is imported. Until then, “encrypted at rest” must not be used as a current product claim.

---

## 5. Lootr Advantages Worth Protecting

### 5.1 Assisted entry is cohesive and user-controlled

Lootr's global Add island combines natural language, voice, OCR, manual entry, preview, confirmation, and Undo. Cashew has excellent calculator entry and automation, but Lootr's single “type, speak, scan, or fill” model is more coherent.

Keep deterministic parsing first. Model AI remains optional, on-device, explainable, and unable to mutate the ledger without confirmation.

### 5.2 Transfers are a real domain object

Cashew represents a transfer as paired transaction rows. Lootr stores a dedicated transfer with source, destination, amount, fee, time, and note (`database-schema.md §3.6`). This prevents transfers from leaking into spending and budget totals and makes edit/delete behavior easier to audit.

The importer should recognize Cashew pairs and produce Lootr transfers rather than preserving the overloaded source representation.

### 5.3 Payees are normalized

Lootr separates payee identity from transaction notes and categories. This creates a better foundation for deduplication, recurring detection, merchant history, and local categorization rules than free-text titles alone.

The importer must still retain Cashew's exact title in provenance so a normalized mapping never destroys user-entered wording.

### 5.4 Salary deductions fit the intended user

Parent income plus child deduction entries can represent Philippine salary realities such as tax, SSS, PhilHealth, Pag-IBIG, insurance, and custom deductions without becoming payroll software (`product-strategy.md §Income Deductions`).

This is more personally relevant than copying another generic analytics widget.

### 5.5 Debt semantics are clearer

Lootr distinguishes social debt from institutional liability accounts. Cashew's debt, credit, and loan behaviors are powerful but spread across transaction types and objectives.

Keep Lootr's clearer model, then fix its missing immutable contribution/payment history before importing linked Cashew data.

### 5.6 The local runtime has a stronger boundary

Lootr V1 requires no login and no network in the UI read/write path. Cashew is locally capable, but optional Drive, Gmail, attachments, sharing, and cross-device file sync widen its privacy surface.

This is a real Lootr advantage only after encryption, backup, and device lock are implemented.

### 5.7 Calm defaults beat configuration debt

Lootr uses a fixed primary navigation, a canonical transaction list, restrained semantic color, whitespace, and no streaks or guilt-based engagement. Cashew's flexibility is useful, but its deep settings and long-press conventions increase learning and QA cost.

Adopt meaningful customization without turning the settings screen into a second product.

### 5.8 Household ownership is systematic

Lootr's planned owner/member/viewer roles and personal/shared ownership are modeled across the domain and authorization boundary. Cashew's current sharing is more available, but more feature-specific.

Keep Lootr's model and V2 gate; do not pull live collaboration into V1 merely for parity.

---

## 6. V1 Adoption Portfolio

### 6.1 P0 — replacement gates

| **Adoption** | **Concrete V1 outcome** | **Why P0** |
|---|---|---|
| Cashew SQLite importer | Dry run, source detection, entity mapping, warnings, atomic commit, reconciliation, rollback | The user cannot switch safely without it |
| Lootr backup/restore | Versioned, encrypted, full-fidelity local backup plus readable transaction CSV | Local-first must not mean device-bound |
| SQLCipher migration | Existing and imported databases encrypted with keystore-managed key | Required for the privacy claim |
| Device lock | Biometric/device credential with working fallback and auto-lock | Cashew already protects sensitive data |
| Currency guardrails | Per-currency totals until conversion is correctly modeled | Prevents false financial reporting |
| Goal/debt event integrity | Contributions/payments create immutable linked events and reconcile scalars | Required to preserve Cashew history |

### 6.2 P1 — familiar daily-use leverage

| **Adoption** | **Lootr interpretation** |
|---|---|
| Remembered title/category behavior | Local payee/title rules learned from explicit correction |
| Persistent filters | Restore list filters, show active chips, and keep a clear “Reset” |
| Month/cycle review | Shared period selector across ledger, budgets, and reports |
| Report drill-down | Every aggregate opens the exact filtered records behind it |
| Recurring pay/skip | Occurrence lifecycle with original due date and confirm-before-post |
| Calculator fallback | Deterministic amount calculator beside NL/voice/OCR |
| Bounded dashboard customization | Hide/show/reorder 4–6 secondary cards below a fixed safe-to-spend hero |
| Cleanup bulk actions | Recategorize, move account, and delete in one atomic operation |

### 6.3 P2 — adopt only if the real backup demands it

- flexible one-time or date-range budgets;
- imported historical budget-cycle browser;
- custom per-account decimal precision;
- manually managed exchange rates;
- transaction duplication and “duplicate for today”;
- local receipt attachment lifecycle;
- More-section favorites on tablet;
- app/OS quick actions.

### 6.4 Defer

- composite budgets with every Cashew include/exclude/filter rule;
- Google Drive merge sync;
- Gmail or notification scraping;
- Google Sheets import;
- shared budgets in V1;
- arbitrary bottom-navigation replacement;
- configurable fonts, icon families, number-pad layouts, animation speeds, and dozens of formatting switches;
- heat maps, bill splitting, and elaborate loan subproducts;
- PWA/desktop parity;
- AI coaching or automatic financial mutation.

### 6.5 Deliberately reject

- representing transfers, debts, subscriptions, and goals only as flags on one transaction table;
- file-level database replacement as the normal sync protocol;
- hidden long press as the only way to discover a consequential action;
- forced text scaling in charts or category visuals;
- automatic recurring posting without an explicit opt-in and auditable state transition;
- copied Cashew source code, branding, icons, illustrations, or translation text.

---

## 7. UI/UX Principles to Carry Forward

### 7.1 Progressive power

The default path should remain short, but advanced attributes should stay nearby.

```text
Quick Add
  → inferred amount / account / category / payee
  → visible preview and one-tap correction
  → Save

Need more?
  → date, recurrence, note, goal/debt link, source metadata
  → same transaction context, progressively disclosed
```

Do not force a user into a separate administration screen to correct the transaction they are already entering.

### 7.2 Remember intent, not authority

Remember last-used account, list filters, report period, and explicit payee/category corrections. Use them as visible defaults or suggestions.

Never reinterpret old records or silently change a saved category because a new rule was learned.

### 7.3 Every number must explain itself

Use one drill-down contract:

```text
summary
  → human-readable filter description
  → canonical transaction list
  → editable record
  → back restores the summary and scroll/filter state
```

This matters more than adding another chart type.

### 7.4 Treat time as navigation

“This month,” “last cycle,” “due,” and “paid on” are primary finance questions. Use one consistent period selector across transactions, budgets, and reports. Preserve filters while moving between periods.

### 7.5 Layer feedback without judgment

Combine text, icons, color, optional haptics, and Undo. Do not rely on red/green alone. Keep budget and overdue language factual; avoid streaks, shame, or false urgency.

### 7.6 Personalize within a stable frame

Allow a small curated set of home modules to be hidden or reordered. Keep the safe-to-spend hero, four tabs, Add island, and canonical transaction list stable.

### 7.7 Visible actions first, gestures second

Swipe and long press may accelerate expert use, but every destructive, batch, or settings-changing action must also have a visible menu or button. Teach gestures after first use rather than making users guess.

### 7.8 Migration is onboarding

The first-run experience for an existing Cashew user is not a generic feature carousel. It is:

1. choose the Cashew backup;
2. inspect detected accounts, dates, currencies, and special records;
3. review warnings and mapping decisions;
4. import into a reversible workspace;
5. reconcile balances and counts;
6. land on a familiar month with the imported ledger already filtered and explainable.

---

## 8. Required V1 Model Changes

The comparison exposes data gaps that should be resolved before broad feature work:

| **Model change** | **Purpose** |
|---|---|
| Import run + source mapping tables | Idempotency, provenance, warnings, rollback, and raw-value preservation |
| Goal contribution events or explicit transaction FK | Immutable progress history |
| Debt payment events or explicit transaction FK | Immutable repayment history |
| Recurring occurrence state | Due, paid, skipped, resolved, source occurrence |
| Categorization rule table | Durable exact/contains payee/title suggestions |
| Backup format/version metadata | Reliable future restore |
| Currency policy | Base currency, rate source/time, conversion/rounding, or strict per-currency separation |
| Optional legacy record store | Lossless preservation for unsupported Cashew budgets/settings |

`metadata` may hold source residue for audit, but queryable financial behavior must not live indefinitely in opaque JSON.

---

## 9. Constraints and Non-Negotiables

Any adopted behavior must:

- work without login or network;
- write to SQLite first and update related money state atomically;
- remain compatible with additive migrations and future row sync;
- never require bank credentials;
- keep AI optional, on-device, and confirm-before-save;
- preserve dedicated transfer semantics;
- preserve the four tabs plus rightmost Add island;
- use progressive disclosure for advanced finance controls;
- provide screen-reader labels, dynamic type, non-color status cues, and reduced motion;
- expose source/provenance and reconciliation for imported records.

---

## 10. Risks and Corrections to Existing Claims

| **Risk** | **Current reality** | **Correction** |
|---|---|---|
| “Privacy-first” implies encryption | Production DB is ordinary SQLite | Implement/verify SQLCipher before claiming encryption |
| Multi-currency reports look valid | Raw values are aggregated without conversion | Separate or block mixed-currency totals |
| Goal history appears available | Contribution action mutates a scalar without creating the expected event | Choose and enforce one authoritative event model |
| Debt history appears available | Settlement mutates remaining balance/status without an immutable payment event | Link payments and derive/reconcile balance |
| Rollover appears in UX | Budget schema has no rollover field/policy | Remove from V1 UI or add explicit semantics |
| “Local-first” implies recoverable | No backup/restore exists | Make data portability a launch gate |
| Insights appears implemented | Current insight text is static | Remove from V1 claims or replace with computed deterministic summaries |

---

## 11. Licensing Boundary

The inspected Cashew repository is licensed under GNU GPL v3. This benchmark recommends adopting general product behaviors and independently implementing them.

Do not copy Cashew source code, branded copy, icons, screenshots, illustrations, translations, or bundled assets into Lootr unless Lootr intentionally accepts the applicable GPL obligations and the specific asset rights are verified. This is a product-engineering boundary, not legal advice.

---

## 12. Acceptance Criteria

The comparison work is actionable when:

- every matrix item is labeled as Cashew implemented, Lootr implemented/partial/spec-only, or deferred;
- the V1 roadmap contains every P0 replacement gate;
- a Cashew SQLite backup can complete a dry run without mutating Lootr;
- imported counts, per-account currency totals, date bounds, transfer pairs, recurring items, goals, debts, and unsupported records are reconciled;
- the import can be rolled back and repeated without duplicates;
- Lootr can create and restore its own full-fidelity backup;
- the production database is demonstrably encrypted and the device lock is functional;
- mixed-currency reports cannot present invalid totals;
- every aggregate report drills into its source ledger rows;
- filter and month state survive navigation;
- advanced options remain discoverable without relying only on long press;
- no Cashew code or assets are copied into Lootr.

---

## 13. Bottom Line

Cashew is ahead in maturity, flexibility, portability, recurrence, multi-currency, and power-user workflow. Lootr is already more coherent in assisted capture, transfers, payees, salary deductions, debt boundaries, and calm information design.

The winning V1 is not “Cashew, rewritten.” It is a trustworthy personal migration into a smaller, clearer tool that keeps the user's most valuable habits, fixes the data-model ambiguities that migration exposes, and earns the privacy-first claim through working security and portability rather than intention.

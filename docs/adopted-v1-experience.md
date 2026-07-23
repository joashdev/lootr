# Adopted V1 Experience — Personal Finance App

The connected interaction contract for Cashew-inspired daily-use improvements without copying Cashew’s product surface.
References: `cashew-product-benchmark.md` (adoption decisions), `cashew-data-migration.md` (unified model and onboarding), `navigation-arch.md` (stable frame), `design.md` (tokens and accessibility), `state-management.md` (persistence and Undo).

---

## 1. Product Boundary

Lootr keeps four fixed tabs, the rightmost Add island, one canonical transaction list, dedicated transfers, confirm-before-finalize recurrence, and calm factual feedback. The adopted experience adds progressive power inside those stable surfaces.

| **Area** | **V1 outcome** | **Boundary** |
|---|---|---|
| `add` | One type, speak, scan, calculate, or manual flow | Assistance previews; it never silently writes |
| `ledger` | Persistent period, search, filters, sort, scroll, and focused bulk cleanup | Canonical Filter Sheet uses AND semantics |
| `aggregates` | Human-readable explanation and exact ledger drill-down | Mixed currencies remain separated |
| `memory` | Explicit-correction categorization rules | No retroactive mutation |
| `recurrence` | Due, overdue, paid, skipped, and dismissed occurrences | Posting remains confirm-first |
| `budgets` | Composite scopes, cycles, inclusion reasons, and history | Unsafe imports remain read-only |
| `dashboard` | Hide, show, and reorder secondary modules | Hero, tabs, Add, and ledger stay fixed |

---

## 2. Shared Period Context

Transactions, budgets, and reports use one `PeriodContext` vocabulary:

```text
calendar month ── previous / direct select / next
custom cycle   ── cycle label + exact start/end dates
drill-down     ── originating period + filters + scroll restoration key
```

- A calendar month is labeled by month and year.
- A custom cycle shows its name and date range; it is never described as a calendar month.
- Changing period preserves every non-date filter.
- A drill-down passes a structured ledger query, not a precomputed total.
- Returning restores the originating selector, filter chips, sort, selection, and scroll offset.

---

## 3. Unified Add

The Add island opens one sheet with Quick, Manual, and Scan entry. Quick keeps the microphone inside its text field and accepts deterministic arithmetic. Manual and Scan return to the same in-context preview.

The preview exposes amount, account, category, payee, date, and recurrence as tappable correction rows. “More details” expands note, goal/debt link, source metadata, and advanced fields without leaving the sheet.

Suggestion copy is human-readable:

- “From your wording” for deterministic parsing;
- “Remembered from this payee/title” for an active correction rule;
- “From your last choice” for a visible remembered default;
- “Needs review” when required information is missing or ambiguous.

Save is one database transaction. On success the sheet closes unless “Add another” is active, focus returns to Quick entry for rapid capture, and a five-second Undo snackbar is shown. Rule creation is a separate explicit “Remember this correction” choice and never changes old rows.

---

## 4. Ledger Search, Filters, and Cleanup

The transaction tab owns durable in-memory navigation state for the app session:

| **State** | **Restoration rule** |
|---|---|
| `query` | Preserved across tab/detail navigation until cleared |
| `filters` | Visible removable chips; Reset clears all groups |
| `period` | Shared period context; non-date filters survive changes |
| `sort` | Preserved until explicitly changed |
| `scroll` | Restored after detail/edit/drill-down return |
| `selection` | Cleared only after successful batch, explicit cancel, or invalidation |

Search deterministically recognizes text, exact decimal amount with an explicit currency, and month names or `YYYY-MM`. Search and filter groups compose with AND semantics.

Long press and swipe may enter or accelerate selection, but a visible Select action is always present. Batch recategorize, move account, and delete first validate the complete selection. If any row is incompatible—such as a transfer or currency/account mismatch—the sheet explains the exact count and applies nothing. Successful batches use one database transaction and expose Undo when a lossless rollback snapshot exists.

---

## 5. Explainable Aggregates

Every interactive number follows:

```text
summary
  → “What is included” explanation
  → canonical transaction list with named filters
  → editable transaction or transfer detail
```

Chart segments, totals, account balances, budget progress, safe-to-spend components, goal progress, and debt balances either open this path or use non-interactive styling. Static insight prose is replaced by deterministic facts.

Currency aggregation returns partitions. A single-currency partition may show one total; multiple currencies show separate labeled totals and never a converted-looking sum.

---

## 6. Categorization Memory

Rules are created only after an explicit correction and opt-in. Exact matches precede contains matches; priority, pattern specificity, creation time, and ID provide deterministic tie-breaking.

The Add preview shows the suggested category and the reason. Override is one tap. Settings exposes active and archived rules with edit, enable/disable, archive, restore, and delete. Imported rules use the same table and matching engine, retain provenance, and never create payees as a matching side effect.

Rule edits affect future suggestions only.

---

## 7. Recurring Occurrences

The recurring list and detail page project series plus occurrences into:

| **Status** | **Meaning** | **Visible actions** |
|---|---|---|
| `upcoming` | Due in the future | Edit occurrence, Edit series |
| `due` | Due today | Pay, Skip, Edit occurrence, Edit series |
| `overdue` | Unresolved after original due time | Pay, Skip, Edit occurrence, Edit series |
| `paid` | Linked to one finalized ledger row | Open transaction |
| `skipped` | Deliberately not posted | View history |
| `dismissed` | Resolved without posting | View history |

Pay opens the normal Add experience prefilled from the occurrence. Confirming creates the ledger row and resolves the occurrence atomically. Skip/dismiss records resolution time while preserving original due time and next occurrence. Reminder deep links identify the exact occurrence. Optional auto-pay, if enabled later, must be explicit, reversible, and auditable.

---

## 8. Composite Budgets

Create/edit supports multiple included or excluded accounts and categories, explicit transaction membership, direction, monthly or custom/date-range periods, and amount/currency. The detail page shows scope, unresolved imported members, overlap information, historical periods, per-currency totals, and every matching transaction’s inclusion reason.

Imported definitions with unsafe or missing relationships remain visible and read-only until reviewed. Missing accounts are never silently replaced. Overlaps use neutral copy because each budget evaluates independently.

---

## 9. Bounded Dashboard Customization

Safe-to-Spend stays first. A visible Customize action controls only these secondary modules: net worth, accounts, income/expense, budgets, spending categories, recent transactions, and upcoming recurring. The product may expose at most six at once.

Users may hide/show and reorder them, then Restore Defaults. Persistence is local. Screen-reader traversal follows visual order. Hidden modules do not change underlying calculations, reports, tabs, or navigation.

---

## 10. Visual and Accessibility Contract

- Use semantic theme extensions for positive, attention, needs-review, information, selection, surfaces, and text.
- Status always includes text and/or an icon; red and green are never the sole signal.
- Normal text and meaningful controls meet WCAG AA where applicable.
- Touch targets are at least 44dp; focus, pressed, selected, and disabled states remain visible.
- Layout supports 200% text, compact phones, tablet width, safe areas, keyboard navigation, and screen readers.
- Motion is short and interruptible; non-essential motion is removed when reduced motion is requested.
- Empty, loading, and error states preserve context and provide the next safe action.

---

## 11. Verification Matrix

| **Layer** | **Required proof** |
|---|---|
| `unit` | Search parsing, rule precedence, period math, inclusion reasons, currency partitions |
| `repository` | Atomic batch/Undo, occurrence resolution, composite membership, dashboard persistence |
| `provider` | Tab/detail restoration and deterministic invalidation |
| `widget` | Visible actions, correction preview, chips, bulk validation, occurrence actions |
| `navigation` | Period/filter/scroll restoration and exact reminder/drill-down routes |
| `golden` | Light/dark, large text, compact phone, tablet, reduced-motion states |
| `integration` | Add/Undo, bulk cleanup, report-to-edit, rule learning, Pay/Skip, composite budget |

Formatting, code generation, static analysis, all relevant tests, synthetic visual review, standards/spec review, and over-engineering review must pass before completion.

---

## 12. Acceptance Criteria

- Every adopted feature is reachable from the normal app flow and writes through real repositories.
- Add remains one coherent surface and every save or correction is user-controlled.
- Query, filters, period, sort, and scroll restore after tabs, details, edits, and drill-down.
- Batch operations are atomic and preflight incompatible rows before mutation.
- Every interactive aggregate explains itself and opens its exact source ledger.
- Mixed currencies are partitioned without false conversion.
- Explicit corrections can create visible, manageable future-only categorization rules.
- Recurring Pay/Skip preserves occurrence history without duplicating ledger rows.
- Composite budget membership and inclusion reasons are inspectable.
- Dashboard customization is bounded, persistent, reversible, and accessible.
- Light/dark/accessibility verification artifacts exist and the relevant test suite passes.

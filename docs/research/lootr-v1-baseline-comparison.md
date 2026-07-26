# Lootr V1 Baseline for the Cashew Comparison

Research note, 2026-07-18.

This note establishes what Lootr's current specifications actually promise, what they explicitly defer, where Lootr is already differentiated, and what architectural constraints apply when considering Cashew features. It is a baseline for the broader Cashew assessment, not a replacement for a full Cashew feature or migration audit.

## 1. Scope and confidence

Primary Lootr sources reviewed:

- `docs/product-strategy.md`
- `docs/domain-model.md`
- `docs/database-schema.md`
- `docs/navigation-arch.md`
- `docs/solutions-arch.md`
- `docs/state-management.md`
- `docs/security-model.md`
- `docs/api-contracts.md`
- `docs/sync-engine.md`
- `docs/design.md`
- `docs/specs-backlog.md`
- `docs/mandocs/app-mockups.html`
- current Flutter source under `lib/`, especially the Drift schema, repositories, providers, router, finance screens, AI helpers, and notification scheduler
- `pubspec.yaml`

Targeted Cashew sources reviewed:

- `Cashew/README.md`
- `Cashew/budget/lib/database/tables.dart`
- `Cashew/budget/lib/widgets/importCSV.dart`
- `Cashew/budget/lib/widgets/exportCSV.dart`
- selected first-party UI files where a README claim needed confirmation

Important interpretation rule: this is both a **specification baseline** and a **source-level implementation audit**. “Implemented” below means the current Flutter source contains a connected route/UI, provider or use case, and persistence/query path; it does not mean the feature was device-tested during this research. “Partial” means a real path exists but an important behavior is stubbed, internally inconsistent, or disabled. “Spec-only” means the behavior is promised in documentation but is not present in the current app.

The architecture describes V1 as local-only and several documents use future-tense or “built but disabled” language (`docs/solutions-arch.md:16-23`, `docs/solutions-arch.md:442-454`). The visual mockup document covers only 11 representative states, despite the navigation specification inventorying 50 screens (`docs/mandocs/app-mockups.html:139-165`; `docs/navigation-arch.md:678-754`).

### 1.1 Current implementation maturity

| Status | Capability | Source-level finding |
|---|---|---|
| **Implemented** | Local database and primary product shell | The current Drift database registers all 16 planned tables and is at schema version 2 (`lib/data/database/app_database.dart:25-55`). The router connects onboarding, quick add, OCR, the four primary destinations, and secondary account/debt/goal/recurring/report/settings screens (`lib/core/router/app_router.dart:85-225`). |
| **Implemented** | Core manual finance workflows | Repositories, providers, use cases, and routed UI exist for accounts, categories, payees, transactions, dedicated transfers, monthly category budgets, recurring templates, goals, debts, and household records. The current implementation remains the narrow data model described later; “implemented” does not imply Cashew-equivalent breadth. |
| **Implemented** | Data-backed reports | Category spending, trailing six-month income/expense, 90-day reconstructed net worth, and monthly budget performance are computed from reactive repository streams (`lib/application/providers/reports_provider.dart:163-433`). These are real reports, not mockup-only screens. |
| **Implemented** | Deterministic assisted entry | Natural-language parsing extracts amount, direction, account, category, payee, and transfers (`lib/ai/nl_parser.dart:135-209`). Receipt OCR performs on-device ML Kit recognition and local field parsing (`lib/ai/ocr_pipeline.dart:47-168`). The quick-action sheet uses the platform speech recognizer for dictation (`lib/presentation/sheets/quick_actions_sheet.dart:39-112`). |
| **Implemented** | Local reminders | A local scheduler persists and schedules recurring, subscription, installment, and debt reminders, handles permissions, caps pending notifications, and deep-links into the app (`lib/application/notifications/notification_scheduler.dart:44-183`, `:240-320`). Settings are persisted locally (`lib/application/providers/notification_provider.dart:19-155`). |
| **Implemented** | Local onboarding and demo workspace | Onboarding creates a sentinel `local-user-1` profile (`lib/presentation/screens/onboarding/onboarding_screen.dart:86-139`). Demo data uses deterministic `demo-*` IDs and can be removed by prefix (`lib/data/seed/demo_data_loader.dart:25-120`; `lib/application/providers/demo_data_provider.dart:50-75`). |
| **Partial** | Goals and debt history | Goal and debt detail providers look for linked transactions through JSON metadata (`lib/application/providers/goal_contributions_provider.dart:8-21`; `lib/application/providers/debt_payments_provider.dart:8-22`), but `GoalRepo.addContribution` only increments the scalar goal amount and `DebtRepo.settle` only changes scalar debt fields (`lib/data/repositories/goal_repo.dart:41-57`; `lib/data/repositories/debt_repo.dart:46-55`). The promised event history therefore is not reliably created by the domain operations. |
| **Partial** | Categorization and “AI” | Categorization has history and keyword heuristics, plus processing logs, but the model inference method explicitly returns `null` until llama.cpp/GGUF integration exists (`lib/ai/categorizer.dart:68-182`). Deterministic assistance is implemented; model-based on-device AI is not. |
| **Partial** | Sync and households | Schema, repositories, providers, and sync-oriented fields exist, but auth exposes only an unauthenticated state and the sync screen says “coming soon” with a disabled action (`lib/application/providers/auth_provider.dart:3-12`; `lib/presentation/screens/more/settings/sync_settings_screen.dart:18-55`). Household records are local scaffolding, not active cross-device sharing. |
| **Partial** | Insights | The routed Insights UI is present, but its “15%” trend, unusual-activity message, and detail text are fixed strings rather than computed analysis (`lib/presentation/screens/more/insights_screen.dart:12-143`; `lib/presentation/screens/more/insight_detail_screen.dart:17-70`). It should not be counted as a shipped analytical or AI capability. |
| **Not implemented despite spec** | At-rest database encryption | The spec requires SQLCipher, but the production factory opens an ordinary `driftDatabase(name: 'lootr')`, with no key or encryption setup (`lib/data/database/app_database.dart:50-73`). The dependency list contains Drift and secure storage but no SQLCipher integration (`pubspec.yaml:30-59`), and there is no secure-storage use in `lib/`. Current financial data should be treated as **not encrypted at rest** until this is implemented and verified. |
| **Spec-only / placeholder** | Biometric or PIN app lock | The biometric switch is hard-coded false with a no-op callback and the PIN row says “Coming soon” (`lib/presentation/screens/more/settings/security_screen.dart:25-80`). There is no `local_auth` dependency (`pubspec.yaml:30-59`). |
| **Spec-only** | CSV import/export, backup/restore | The product and navigation specs promise CSV export, but the current source has no import/export or backup implementation and no CSV dependency. The visible sync/backup surface is disabled. This is the most important switching-readiness gap. |
| **Spec-only** | Flexible budgets, rollover, converted multi-currency reporting | The current budget table remains category + calendar month/year and contains no rollover policy (`lib/data/database/tables/budgets.dart:9-35`). Accounts have currency labels, but reports aggregate raw amounts under the user's display currency without exchange-rate conversion (`lib/application/providers/reports_provider.dart:191-219`, `:317-365`). |

This implementation split materially changes the Cashew comparison: Lootr already has a credible working core and several distinctive entry flows, but it is not yet safe to call it a privacy-hardened, data-portable replacement for a mature tracker.

## 2. Lootr's planned V1 product contract

### 2.1 Product stance

Lootr is designed as a calm, beginner-friendly, manual-first, privacy-first, offline-first personal finance app. It explicitly rejects accounting complexity, enterprise workflows, and mandatory cloud access (`docs/product-strategy.md:3-20`).

The primary persona is an early-career professional with multiple accounts and e-wallets who wants spending clarity without spreadsheet or accounting complexity. Couples and shared households are secondary and architecturally anticipated, while freelancers are tertiary (`docs/product-strategy.md:24-72`).

The core jobs are to understand spending, know what is safe to spend, record transactions quickly, track debts, build habits, and understand salary breakdowns (`docs/product-strategy.md:103-113`).

### 2.2 V1 feature baseline

| Area | Planned V1 capability | Evidence and qualification |
|---|---|---|
| **Accounts** | Manual asset and liability accounts; cash, bank, e-wallet, savings, investment, crypto, credit card, loan, and BNPL types | Product scope and account list: `docs/product-strategy.md:134-159`. Investments and crypto are account labels only; investment tracking is excluded: `docs/product-strategy.md:556-565`, `docs/navigation-arch.md:893-903`. |
| **Balances** | Stored balance for fast reads, with transaction history as the audit trail and recalculation as repair tooling | `docs/domain-model.md:91-139`; atomic balance updates in `docs/solutions-arch.md:183-208`. |
| **Transactions** | Expense and income records with amount, account, category, payee, note, and timestamp | `docs/product-strategy.md:161-195`; physical columns in `docs/database-schema.md:150-180`. |
| **Transfers** | Dedicated source-to-destination transfer records, excluded from spending and budget calculations; fees become separate expenses | `docs/database-schema.md:9-18`, `docs/database-schema.md:185-204`. The unified transaction feed must therefore join transaction and transfer data at the presentation/query layer: `docs/navigation-arch.md:131-165`. |
| **Fast entry** | Manual form, natural-language quick add, voice input, and receipt OCR; deterministic parsing precedes AI fallback | `docs/product-strategy.md:169-185`, `docs/product-strategy.md:221-241`; the one-tap Add island and quick-action sheet are specified in `docs/navigation-arch.md:25-93`. |
| **Income deductions** | Salary parent transaction plus child deduction transactions for tax, SSS, PhilHealth, Pag-IBIG, insurance, and custom deductions; deliberately not a payroll engine | `docs/product-strategy.md:243-257`; schema relationship in `docs/database-schema.md:14-18`, `docs/database-schema.md:150-168`. |
| **Organization** | Hierarchical categories, normalized payees, notes, search, and composable transaction filters | Category/payee data model: `docs/database-schema.md:208-244`. Search/filter UX: `docs/navigation-arch.md:168-221`. |
| **Budgets** | Advisory monthly category budgets with month navigation, progress, drilldown, and calm threshold feedback | `docs/product-strategy.md:277-287`; schema limits one budget per owner/category/month/year: `docs/database-schema.md:248-269`; UX: `docs/navigation-arch.md:263-347`. |
| **Debts** | Social lending and borrowing with original amount, remaining balance, due date, and status; institutional debt remains an account | `docs/product-strategy.md:288-311`; `docs/database-schema.md:273-293`. |
| **Goals** | Savings, debt-payoff, emergency-fund, travel, and custom goals with manual contributions | `docs/product-strategy.md:313-326`; scalar goal model in `docs/database-schema.md:297-316`. |
| **Recurring** | Templates for recurring income/expenses, subscriptions, installments, and reminder-only items; user confirms entries rather than the system finalizing transactions automatically | `docs/product-strategy.md:328-337`; `docs/database-schema.md:320-340`. |
| **Dashboard** | Safe-to-spend hero, net worth, account summaries, income-versus-expense, budgets, category spending, recent activity, and upcoming bills/recurring items | `docs/navigation-arch.md:97-116`; the representative mockup claims to reflect this hierarchy at `docs/mandocs/app-mockups.html:159-165`. |
| **Reports** | Spending by category, income versus expense, net-worth trend, account balances, budget performance, drilldown to transactions, and CSV export | `docs/product-strategy.md:357-368`; detailed routes and report UX in `docs/navigation-arch.md:418-429`. Core report calculations are implemented; CSV export is not. |
| **Notifications** | Offline local reminders for bills, subscriptions, installments, debts, transactions, and recurring items | `docs/product-strategy.md:370-383`. The dedicated architecture spec remains an unfinished Phase 3 document (`docs/specs-backlog.md:133-145`), but a functioning scheduler and settings implementation already exist in source. |
| **Local AI** | Optional on-device OCR, categorization, natural-language parsing, and voice-assisted entry; no cloud AI and no unconfirmed mutation | `docs/product-strategy.md:393-436`; AI-assisted flow in `docs/solutions-arch.md:270-287`. |
| **Onboarding** | Skippable introduction, AI opt-in, first account, and optional first transaction; no login wall | `docs/navigation-arch.md:521-547`. |
| **Appearance and accessibility** | Light/dark/system themes, semantic design tokens, reduced motion, screen-reader labels, font scaling, and 44–48dp targets | `docs/design.md:404-426`, `docs/design.md:459-504`. |
| **Local security** | SQLCipher-encrypted SQLite with a platform-keystore key | This is the documented target (`docs/security-model.md:144-202`), not the current implementation. The app currently opens standard Drift SQLite without encryption (`lib/data/database/app_database.dart:50-73`). Biometric app lock is also a placeholder. |
| **Local-first behavior** | Every runtime read and write is local; network is not on the UI critical path; writes update reactive local streams immediately | `docs/solutions-arch.md:93-105`; `docs/state-management.md:9-20`, `docs/state-management.md:92-174`. |

### 2.3 Navigation and interaction model

Lootr's primary interaction model is:

1. Four tabs: Home, Transactions, Budgets, and More.
2. A visually separate rightmost Add island that opens a sheet without changing tabs.
3. Creation and edit work in sheets; detailed inspection uses pushed pages.
4. Any feature should be reachable within three taps.
5. Transactions save first, then offer a five-second Undo action.

Sources: `docs/navigation-arch.md:9-21`, `docs/navigation-arch.md:25-93`, `docs/state-management.md:118-153`.

The choice is deliberately opinionated: secondary areas such as accounts, debts, goals, reports, categories, payees, and settings live behind More to keep the tab bar small (`docs/navigation-arch.md:350-476`).

### 2.4 Data and domain inventory

The planned local database has 12 syncable tables and four local-only tables (`docs/database-schema.md:42-44`, `docs/database-schema.md:344-402`):

- Syncable: users, households, household members, accounts, transactions, transfers, categories, payees, budgets, debt records, goals, and recurring templates.
- Device-local: balance snapshots, notification schedules, AI processing logs, and sync metadata.

The server is intentionally a sync and backup store, not a finance calculation service. Balances, dashboards, reports, and budget summaries remain on-device (`docs/api-contracts.md:9-17`; `docs/solutions-arch.md:79-89`).

## 3. Explicit deferrals, exclusions, and gates

### 3.1 Product-level exclusions

The product strategy excludes bank integrations, real investment tracking, advanced automation, desktop, external APIs/webhooks, advanced forecasting, AI financial coaching, and real-time collaboration from V1 (`docs/product-strategy.md:556-565`).

The exclusion of bank integrations is not an accidental gap. It protects the manual-first/privacy-first model and means no bank credentials or bank tokens are collected (`docs/product-strategy.md:440-448`; `docs/security-model.md:39-40`).

### 3.2 V2-gated infrastructure

The more specific architecture supersedes the product strategy's ambiguous “optional email OTP auth” V1 bullet. It says:

- email OTP is built but disabled in V1;
- cloud sync is inert without auth;
- household sharing is schema- and route-ready but not active;
- backend receipt upload is not used until sync;
- cloud push is V2.

Source: `docs/solutions-arch.md:442-454`. The same boundary is repeated in `docs/navigation-arch.md:549-566` and `docs/security-model.md:503-511`.

Biometric lock is also a V1.x or later switch, not an initial-V1 capability (`docs/security-model.md:266-275`).

### 3.3 Operational specs still missing

Phase 3 is not specified yet:

- notification architecture;
- MVP prioritization and roadmap;
- QA/testing strategy;
- CI/CD/infrastructure;
- monetization.

Source: `docs/specs-backlog.md:133-205`.

This matters to the Cashew comparison: a feature can be named in the product strategy without yet having implementable scheduling, acceptance criteria, migration, or release sequencing.

## 4. Targeted direct comparison with Cashew

This section uses only high-confidence Cashew claims confirmed by the local first-party repository. It identifies comparison pressure points for Lootr; the full Cashew audit should provide broader feature coverage and UX judgment.

| Capability | Cashew baseline | Lootr baseline | Comparison |
|---|---|---|---|
| **Budget periods** | Daily, weekly, monthly, yearly, and custom recurrence; explicit start/end dates and period length (`Cashew/README.md:113-119`; `Cashew/budget/lib/database/tables.dart:42`, `:422-475`) | One category budget for one calendar month/year (`docs/database-schema.md:248-269`) | Material Cashew advantage. Lootr cannot represent trip/event, weekly, pay-cycle, or annual budgets without schema changes. |
| **Budget composition** | A budget can include/exclude multiple categories and accounts, contain manually added transactions, and have per-category limits (`Cashew/README.md:115-118`; `Cashew/budget/lib/database/tables.dart:375-388`, `:422-475`) | One category per budget; advisory target only (`docs/database-schema.md:248-269`) | Cashew is much more flexible; Lootr is simpler and more beginner-focused. |
| **Goal accounting** | Transactions link directly to goals/objectives, so progress is transaction-derived (`Cashew/budget/lib/database/tables.dart:273-340`, `:513-539`) | Goal stores only `current_amount`; the UI searches transaction metadata for contributions, but the contribution operation only updates the scalar (`lib/application/providers/goal_contributions_provider.dart:8-21`; `lib/data/repositories/goal_repo.dart:41-57`) | Cashew has a coherent transaction-derived audit trail. Lootr's contribution history is only partially wired and cannot be relied on yet. |
| **Recurring/upcoming items** | Recurrence, end date, due-date provenance, paid/skipped state, subscriptions, upcoming transactions, debts, and credits are encoded in the transaction model (`Cashew/budget/lib/database/tables.dart:273-340`) | Separate reminder/suggestion templates; finalized transactions are not automatic (`docs/database-schema.md:320-340`) | Lootr has a safer explicit-confirmation philosophy, but Cashew supports richer lifecycle state. |
| **Multi-currency** | Accounts carry currency/format/decimals, and the product promises conversion rates and instant converted views (`Cashew/README.md:129-133`; `Cashew/budget/lib/database/tables.dart:250-271`) | Accounts have a currency code, but no exchange-rate table, rate provenance, base-currency amount, or reporting conversion rule (`docs/database-schema.md:118-146`) | Lootr is multi-currency-labelled, not yet multi-currency-correct for aggregate reporting. |
| **CSV import** | File picker, encoding detection, automatic header recognition, manual column assignment, current-account fallback, templates, and Google Sheets import (`Cashew/budget/lib/widgets/importCSV.dart:35-260`, `:522-640`) | CSV export is specified; import is absent (`docs/product-strategy.md:357-368`; `docs/navigation-arch.md:418-429`) | Critical gap for the user's Cashew-to-Lootr continuity requirement. |
| **CSV export** | Exports account, amount, currency, title, note, date, direction/type, category/subcategory, appearance metadata, budget, and objective, filtered by date/account (`Cashew/budget/lib/widgets/exportCSV.dart:74-175`, `:205-300`) | “CSV export enough initially” is specified, but the current app has neither an implementation nor a schema/version contract (`docs/product-strategy.md:357-368`; `docs/navigation-arch.md:723-741`) | Lootr needs a versioned import/export contract, not just a share action. |
| **Backup and sync** | Cross-device sync and Google Drive backup are current product features (`Cashew/README.md:148-151`) | V1 is device-only; uninstall without V2 sync means expected data loss (`docs/security-model.md:175-202`) | Cashew is safer for continuity in V1 unless Lootr adds local backup/restore or import/export before launch. |
| **Customization** | Custom accent, Material You, custom home layout/widgets, and navigation customization are first-party features (`Cashew/README.md:139-146`; home-widget persistence in `Cashew/budget/lib/database/tables.dart:86-97`, `:250-271`) | Fixed dashboard hierarchy and fixed four-tab shell; only theme mode is user-selectable (`docs/design.md:361-398`; `docs/navigation-arch.md:25-65`, `:469-470`) | Cashew better supports freeform personalization; Lootr provides a more curated, predictable hierarchy. |
| **Biometric lock** | Current feature (`Cashew/README.md:134-137`) | Designed but disabled in initial V1 (`docs/security-model.md:266-275`) | Cashew advantage until Lootr enables its existing design. |
| **Web/PWA** | Cashew ships on mobile and web/PWA (`Cashew/README.md:101-105`) | Desktop is excluded and web is future (`docs/product-strategy.md:556-565`; `docs/design.md:536-540`) | Deliberate Lootr V1 scope tradeoff. |
| **Categorization learning** | Associated titles store exact/substring title-to-category rules (`Cashew/budget/lib/database/tables.dart:390-408`) | Payees support categorization and recurring detection conceptually; local AI/rules are planned, but no persisted user correction/rule model exists (`docs/domain-model.md:325-343`; `docs/database-schema.md:229-244`) | Lootr has a stronger planned assistant surface, but Cashew has an explicit durable rule primitive today. |
| **Bulk and utility workflows** | Cashew advertises multi-select editing, and its source includes a bill splitter (`Cashew/README.md:121-127`; `Cashew/budget/lib/pages/billSplitter.dart:220-252`) | Lootr specifies row-level swipe actions and a separate social debt model; no bulk selection or split-bill workflow (`docs/navigation-arch.md:223-235`, `:403-407`) | Useful Cashew ergonomics are absent from Lootr V1. |

## 5. Distinctive Lootr advantages

These are planned advantages relative to Cashew or a typical mature tracker. They should be preserved when adopting features rather than diluted by copying Cashew wholesale.

### 5.1 Explicit privacy boundary — strong design, incomplete hardening

Lootr's strongest product differentiation is that no account and no network are required for V1. AI processing remains on-device and the backend is not in the runtime path (`docs/solutions-arch.md:16-23`, `docs/security-model.md:393-423`, `docs/security-model.md:503-511`).

This is more than “works offline”: it is an architectural rule that UI reads/writes never depend on network and that server computation is prohibited (`docs/solutions-arch.md:93-105`).

However, the current app does **not** yet fulfill the encryption half of this claim: its default database factory opens ordinary SQLite without SQLCipher (`lib/data/database/app_database.dart:50-73`). Privacy-first remains a real data-flow advantage, but “encrypted at rest” must not be used as a current comparative claim until implementation and migration tests exist.

### 5.2 Faster assisted entry without surrendering control

The implemented Add island combines:

- one-tap access from every tab;
- natural-language entry;
- voice input in the same field;
- OCR;
- deterministic parsing first;
- optional local AI fallback;
- user confirmation;
- five-second Undo.

Sources: `docs/navigation-arch.md:57-93`; `docs/solutions-arch.md:270-287`.

Cashew has app links, scanner-related code, and title rules, but Lootr's cohesive “type/speak/scan, preview, confirm” flow is a distinctive product proposition. The current natural-language, OCR, and speech paths are real; the local language-model fallback is still a stub. The flow preserves the rule that assistance never directly mutates finances.

### 5.3 Cleaner financial semantics

Lootr gives transfers a dedicated entity and excludes them from spending/budget analytics by construction (`docs/database-schema.md:11-18`, `docs/database-schema.md:185-204`). It also makes income deductions first-class child transactions without attempting payroll (`docs/product-strategy.md:243-257`).

Those decisions fit the user's likely Philippine salary/e-wallet workflow more directly than a generic transaction-special-type model.

### 5.4 Debt is not forced into one overloaded transaction model

Lootr separates person-to-person lending/borrowing from institutional liability accounts (`docs/product-strategy.md:288-311`). This should make “who owes whom” easier to reason about and leaves credit cards/loans in the account/net-worth model.

The current debt model still needs repayment-event linkage, discussed below.

### 5.5 Normalized payees and explainable local AI

Payees are normalized/deduplicated rather than remaining free-text titles (`docs/database-schema.md:229-244`). AI processing has a local audit log including source, model, payload, and confidence (`docs/database-schema.md:382-396`).

Together these create a stronger foundation for reliable categorization, recurring detection, and transparent correction than an opaque cloud classifier.

### 5.6 Calm, non-gamified interaction

Lootr explicitly forbids guilt language, badges, streaks, and engagement-bait. Budget thresholds use restrained semantic feedback, while typography and whitespace carry hierarchy (`docs/navigation-arch.md:9-21`; `docs/design.md:7-13`, `docs/design.md:31-45`).

This is a meaningful advantage if adopted Cashew flexibility is kept behind progressive disclosure instead of making every primary screen configurable or dense.

### 5.7 Future household model is more systematic

Lootr already models personal/shared ownership plus owner/member/viewer roles across schema, UI, and server authorization (`docs/database-schema.md:80-146`; `docs/security-model.md:69-79`, `docs/security-model.md:352-389`).

It is not active in V1, but it is a more explicit long-term authorization model than feature-specific sharing fields.

## 6. Architectural constraints on adopting Cashew features

### 6.1 Preserve the local-first write path

Any adopted feature must:

1. write to SQLite first;
2. update balances and related records atomically where money changes;
3. emit through Drift streams;
4. remain usable without auth/network;
5. treat sync as a later side effect.

Sources: `docs/solutions-arch.md:181-228`; `docs/state-management.md:92-174`.

Features that require live exchange-rate APIs, Google Drive, or Google Sheets therefore need a cached/manual fallback and cannot become a prerequisite for normal use.

### 6.2 Preserve manual-first and no-bank boundaries

Adding Cashew-style automation should not be interpreted as adding bank connections. Import, app links, rule-based categorization, and richer recurrence fit the product. Credentialed financial-institution ingestion does not (`docs/product-strategy.md:8-20`, `docs/product-strategy.md:440-448`, `docs/product-strategy.md:556-565`).

### 6.3 Preserve confirm-before-finalize

Lootr intentionally does not auto-create finalized recurring transactions and does not permit AI to write without confirmation (`docs/database-schema.md:320-340`; `docs/solutions-arch.md:270-287`).

Cashew's paid/skipped/upcoming lifecycle can be adopted, but the V1 default should remain “suggest/remind, then confirm.” If auto-posting is ever added, it is an explicit advanced setting and a product-scope change.

### 6.4 Keep a small primary navigation

The four tabs and Add island are archived decisions. Cashew-style dashboard and navigation customization should not replace the information architecture. A safer adoption is:

- hide/show or reorder dashboard modules below a fixed hero;
- allow More-section favorites/shortcuts;
- keep transaction creation globally stable;
- keep default settings excellent.

Sources: `docs/navigation-arch.md:9-21`, `docs/navigation-arch.md:25-65`; fixed dashboard hierarchy in `docs/design.md:361-380`.

### 6.5 Use progressive disclosure

Lootr's product principles favor beginner-friendly, low-friction, non-accounting language (`docs/product-strategy.md:8-20`, `docs/product-strategy.md:524-531`). Flexible budget periods, include/exclude filters, exchange-rate provenance, and bulk tools should therefore live in Advanced sections, contextual menus, or secondary sheets rather than the default create flow.

### 6.6 Respect sync-friendly schema evolution

The architecture expects local UUIDs, timestamps, soft deletes, and sync status on every syncable entity, and it restricts V1 migrations to additive changes (`docs/solutions-arch.md:93-105`; `docs/database-schema.md:469-476`).

New Cashew-derived entities such as budget periods, goal contributions, import runs, exchange rates, or attachments should be modeled explicitly rather than embedded indefinitely in opaque JSON. `metadata` is useful for source-specific residue, not for fields required in queries or integrity checks.

## 7. Data-model capability gaps relevant to Cashew adoption

| Desired capability | Current Lootr blocker | Minimum model direction |
|---|---|---|
| **Cashew-compatible import** | No import contract, external ID/provenance, import run, row error, or idempotency key | Add an import specification and import-run/row-result model; retain source IDs and raw source values in a traceable mapping. |
| **Flexible budgets** | `budgets` is hard-coded to category + month + year and unique on that tuple (`docs/database-schema.md:248-269`) | Add period kind/start/end or a separate budget-period model. Decide whether budgets target one category, a category set, an account set, or explicit transactions. |
| **Rollover** | UI specifies rollover (`docs/navigation-arch.md:322-337`), but the schema has no rollover field (`docs/database-schema.md:248-269`) | Add rollover policy and derived carry amount semantics before calling it V1. |
| **Per-category limits inside a broader budget** | One budget equals one category | Add `budget_category_limits` or explicitly reject Cashew's composite-budget model for V1. |
| **Goal contribution history** | Goal only stores `current_amount`. The UI queries transaction metadata for `goalId`, but the contribution use case only increments the scalar, so the two representations can diverge (`lib/application/providers/goal_contributions_provider.dart:8-21`; `lib/data/repositories/goal_repo.dart:41-57`) | Link transactions to goals with a queryable field or add immutable goal-contribution events; make one representation authoritative and reconcile current amount. |
| **Debt repayment history** | Debt stores only `remaining_balance` and status. The UI queries transaction metadata for `debtId`, but settling a debt only mutates scalar fields (`lib/application/providers/debt_payments_provider.dart:8-22`; `lib/data/repositories/debt_repo.dart:46-55`) | Link payment transactions to a debt record or add repayment events; derive remaining balance and retain audit history. |
| **Correct multi-currency reports** | Account has `currency_code`, but transaction has no original/base amount, rate, or rate timestamp (`docs/database-schema.md:118-180`) | Define base currency, manual/quoted rate, original amount/currency, converted amount, rate date, and historical-report policy. |
| **Attachments/receipt retention** | Transaction metadata can hold OCR information, but no local attachment entity/path/lifecycle exists; backend upload is V2 | Add local attachment metadata and retention/export rules. Keep receipt capture useful without cloud. |
| **Durable categorization rules** | No title/payee rule table | Add a small local rule model keyed by normalized payee/title with exact/contains behavior and precedence; keep AI as fallback. |
| **Tags** | Search mentions category/payee/note/amount; no tag entity or relation exists | Decide whether tags solve a real user workflow before adding them; if yes, use a join table rather than delimited metadata. |
| **Bulk actions** | Row actions are individual (`docs/navigation-arch.md:223-235`) | Add selection-mode UX and repository batch transactions only for proven actions such as recategorize, move account, or delete. |
| **Local backup/restore** | V1 sync is inert and uninstall without sync loses data (`docs/security-model.md:192-202`) | Add an encrypted local export/restore format or make versioned CSV/JSON export a launch gate. |

## 8. Spec inconsistencies to resolve before selecting V1 adoptions

These are not minor editorial issues. They affect whether a Cashew feature can be mapped without data loss or contradictory UI.

1. **Anonymous local user versus non-null ownership is resolved in code but stale in docs.** The schema document says a local-only user may have no `users` row (`docs/database-schema.md:57-74`), while owned rows require a user FK. Current onboarding resolves this with `local-user-1` (`lib/presentation/screens/onboarding/onboarding_screen.dart:112-139`). The documentation should adopt that invariant. There is a remaining ambiguity when demo seeding also creates `demo-user-1`, because `UserRepo` selects the first user without ordering (`lib/application/providers/demo_data_provider.dart:33-42`; `lib/data/repositories/user_repo.dart:10-35`).

2. **The documented sync metadata contract is stale; current tables are more complete.** The architecture says every syncable row has UUID, timestamps, `deleted_at`, `sync_status`, and `last_synced_at` (`docs/solutions-arch.md:93-105`). The Markdown table definitions omit some of these, but the current category, payee, budget, debt, goal, and recurring Drift tables do include them (`lib/data/database/tables/categories.dart:12-16`; `lib/data/database/tables/payees.dart:10-14`; `lib/data/database/tables/budgets.dart:22-26`; `lib/data/database/tables/debt_records.dart:17-21`; `lib/data/database/tables/goals.dart:17-21`; `lib/data/database/tables/recurring_templates.dart:19-23`). Update the schema spec before using it as the migration contract.

3. **Rollover is in UX but not data.** Navigation specifies a rollover indicator and toggle (`docs/navigation-arch.md:322-337`); the budget table has neither field nor policy (`docs/database-schema.md:248-269`).

4. **Demo-data documentation does not match the implementation.** Navigation and state management describe `is_demo = true` (`docs/navigation-arch.md:865-870`; `docs/state-management.md:361-384`), but the current implementation uses deterministic `demo-*` IDs and prefix deletion (`lib/application/providers/demo_data_provider.dart:50-64`). This works for bundled data, but should be documented and guarded so imported user IDs can never collide with the reserved prefix.

5. **Goal contribution history is partially modeled and internally inconsistent.** Navigation shows contribution history and a contribution action (`docs/navigation-arch.md:408-411`). The provider expects `goalId` in transaction metadata, while the actual contribution operation only changes `current_amount`; no event is created (`lib/application/providers/goal_contributions_provider.dart:8-21`; `lib/data/repositories/goal_repo.dart:41-57`).

6. **Debt payments are partially modeled and internally inconsistent.** Navigation offers record payment and mark settled (`docs/navigation-arch.md:403-407`). The payment provider expects `debtId` in transaction metadata, while settling only mutates the debt record; there is no enforced payment relation or immutable event (`lib/application/providers/debt_payments_provider.dart:8-22`; `lib/data/repositories/debt_repo.dart:46-55`).

7. **V1 auth language conflicts.** Product strategy includes “optional email OTP auth” in V1 (`docs/product-strategy.md:534-555`), while solution, navigation, and security specifications all say auth is disabled until V2 (`docs/solutions-arch.md:442-454`; `docs/security-model.md:503-511`). Treat the latter, more specific boundary as authoritative unless the product scope is amended.

8. **AI insights are simultaneously future and part of the V1 screen inventory.** Product strategy reserves AI insights/coaching for future work (`docs/product-strategy.md:408-419`, `:556-565`), while navigation lists Insights screens among the 50 V1 screens (`docs/navigation-arch.md:691-721`) and labels the dashboard section future (`docs/navigation-arch.md:101-115`). They should be removed from V1 acceptance criteria or explicitly converted into non-AI deterministic summaries.

9. **Transaction filter semantics diverge.** Navigation defines mode as one-time/recurring/installment/debt (`docs/navigation-arch.md:178-221`), while the representative mockup labels Mode as Manual/Voice/OCR/Recurring (`docs/mandocs/app-mockups.html:937-946`). The latter are entry sources, not the schema's `transaction_mode`; both can exist, but they require separate filter fields and labels.

10. **Security table count is stale.** Security says the encrypted database has 15 tables (`docs/security-model.md:214-221`), while the database schema and architecture now have 16. This is editorial, but it indicates cross-spec drift.

11. **Amounts use floating-point REAL.** All money is specified as SQLite REAL (`docs/database-schema.md:20-21`). This is risky for exact migration reconciliation and currency conversion. Before importing a long Cashew history, Lootr should decide whether to migrate to integer minor units or define strict rounding and tolerance rules.

12. **The solutions-architecture status section is stale.** It still calls state management and security pending and `sync_metadata` absent (`docs/solutions-arch.md:458-491`), while the backlog marks both specs done and `database-schema.md` includes `sync_metadata` (`docs/specs-backlog.md:85-129`; `docs/database-schema.md:400-418`). Do not use that status table to prioritize current work.

13. **The encryption promise is not implemented.** Security requires SQLCipher plus a keystore-wrapped key (`docs/security-model.md:144-202`), but current production startup calls plain `driftDatabase(name: 'lootr')` and only enables foreign keys (`lib/data/database/app_database.dart:50-73`). This is a launch blocker for claiming private/encrypted storage and affects how imported Cashew data must be migrated into an encrypted database later.

14. **Report currency labeling can misstate mixed-currency totals.** Current reports sum raw transaction/account amounts, then label the result with the current user's currency (`lib/application/providers/reports_provider.dart:191-219`, `:317-365`). Until conversion rules exist, mixed-currency aggregate reports should be blocked, separated by currency, or visibly marked unsupported.

## 9. Baseline V1 adoption priorities implied by this audit

The full comparison should make the final recommendation, but the Lootr baseline makes the following ordering defensible:

### Launch-critical for this user

1. **Cashew import with dry run, reconciliation, and rollback.**
2. **Versioned local backup/restore or a lossless export format.**
3. **Implement and verify SQLCipher before importing the user's real history.**
4. **Resolve goal-payment, debt-payment, rollover, mixed-currency, and demo-user invariants.**
5. **Implement biometric/PIN lock as a real feature rather than exposing no-op controls.**

Without the first three, moving from Cashew to Lootr requires accepting higher continuity and at-rest security risk than the current app.

### Strong V1 candidates

1. Persisted payee/title categorization rules learned from corrections.
2. Flexible date-range or one-time budgets, provided the simple monthly default remains primary.
3. A modest dashboard customization layer: hide/show and reorder secondary modules, not arbitrary navigation.
4. Bulk recategorize/move/delete for migration cleanup.
5. Richer recurring lifecycle: upcoming, paid, skipped, end date, while retaining user confirmation.

### Better after V1 unless required by the user's real dataset

1. Full composite budgets with category/account inclusion rules and nested limits.
2. Live exchange-rate infrastructure and converted aggregate reports.
3. Web/PWA.
4. App links and broad external automation.
5. Bill splitting beyond the existing lending/debt workflow.

### Preserve as non-negotiable Lootr differentiators

1. No login wall.
2. Fully functional offline.
3. No bank credentials.
4. On-device, optional, confirm-before-save AI.
5. Dedicated transfer semantics and salary deductions.
6. Calm, non-gamified UX.
7. A small, stable primary navigation with one-tap Add.

## 10. Bottom line

Lootr's planned V1 is not merely a smaller Cashew. It is a more opinionated product, and the current code is meaningfully further along than the spec backlog alone suggests:

- Cashew is stronger in breadth, configurability, budget expressiveness, currency handling, data portability, backup/sync availability, biometric availability, and mature power-user workflows.
- Lootr is stronger in explicit local-only data flow, implemented on-device assisted entry, salary-deduction semantics, dedicated transfers, normalized payees, correction-friendly saving, and calm UX.

The best V1 strategy is therefore **not feature parity**. It is to remove switching risk first, finish the privacy promises already central to Lootr, adopt the Cashew behaviors that protect the user's existing habits and data, and keep Cashew's complexity behind progressive disclosure. Import/export, encryption, backup/restore, and schema integrity are prerequisites to treating Lootr as a credible replacement for the user's current finance manager.

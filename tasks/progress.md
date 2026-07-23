# Progress — Lootr Implementation

---

## 2026-07-23 — Adopted V1 Experience Complete

**Feature:** Adopted V1 Product Features & UX Refinement ✅
**Summary:** Connected the unified Add flow, persistent transaction intent and atomic bulk cleanup, shared month/custom-cycle navigation, explainable report and composite-budget drill-down, explicit categorization memory, recurring occurrence Pay/Skip lifecycle, bounded dashboard customization, and accessibility refinements to the post-migration data model. Added deterministic calculator entry, exact-occurrence reminder routes, imported-budget review handling, persistent dashboard preferences, contrast and reduced-motion coverage, focused repository/provider/widget/navigation tests, and an updated migration review golden. The branch passes full static analysis and the complete Flutter test suite.

---

## 2026-07-18 — Cashew Migration V1 Complete

**Feature:** Cashew-to-Lootr Migration ✅
**Summary:** Implemented the complete local migration surface for structurally validated Cashew schema 46, 47, and 48 data files: private read-only staging, redacted dry run and discrepancy review, exact multi-currency canonicalization, atomic publication, provenance and preserved payloads, composite budgets, recurring occurrence lifecycle, immutable goal/debt events, durable title rules, rollback, idempotent re-import, encrypted Lootr backup/restore, and readable currency-aware CSV export. Added SQLCipher database opening with platform-secure key storage and plaintext-upgrade handling. The disposable real-export acceptance path passes the audited structural oracle without emitting private content, restores the exact pre-import state, re-imports without duplicates, and reproduces the imported state through backup/restore.

---

## 2026-07-07 — Task 19 Complete

**Task:** 19 — Local Notifications ✅
**Summary:** Added a local-first notifications layer built around `NotificationScheduler`, a testable `LocalNotificationsClient` wrapper for `flutter_local_notifications`, and Riverpod-backed notification settings persisted in `SharedPreferences`. The scheduler now rebuilds reminders on app start, after sync, and after recurring/debt/transaction mutations via repository callbacks and a new sync post-hook. It schedules recurring, subscription, debt, bill-due, and installment-due notifications, writes active rows into the `notifications` table, marks delivered rows complete once they fall out of the pending plugin queue, deletes completed rows after 7 days, cancels orphaned reminders for deleted records, and caps pending reminders at 64. Deep-link payloads now route taps into `go_router` (`/transactions?filter=installment`, `/recurring/:id`, `/debts/:id`, `/recurring?filter=subscription`) with app bootstrap listening for notification opens. Notification settings screen toggles are now live and reschedule immediately. Added focused scheduler/provider/router/settings tests. Verification in the task worktree included `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`, targeted `flutter analyze --no-pub --no-fatal-infos`, and focused `flutter test --no-pub` for the new notification suite, all passing.

## 2026-06-28 — Task 18 Complete

**Task:** 18 — Demo Data & Seed Data ✅
**Summary:** Implemented demo data seeding with realistic Philippine sample data. `CategorySeeds` provides 17 default categories (10 expense, 6 income, 1 transfer) with Phosphor icon names and hex colors, seeded on first launch if the categories table is empty. `DemoDataLoader` generates 4 accounts (BDO Savings 45k, GCash 3.2k, BPI Checking 120k, Cash 1.5k), 15 Philippine payees (Jollibee, Grab, Meralco, Shopee, etc.), 43 transactions across May—June 2026 with realistic PHP amounts and recurring patterns (weekly groceries, bi-monthly salary, monthly bills), 4 budgets (Food 15k/mo, Transport 5k/mo, Shopping 8k/mo, Entertainment 3k/mo), and 2 goals (Emergency Fund 100k/45k, Vacation to Japan 80k/20k). All insertions use `db.batch()` for atomicity and `insertOnConflictUpdate` for idempotency. All entity IDs prefixed `demo-` for clean clearing via `id LIKE 'demo-%'`. Refactored `DemoDataNotifier` to delegate to `DemoDataLoader`, keeping `clear()` and `hasDemoData()` as-is. Added `categorySeedProvider` (FutureProvider) wired into `App.build()`. Added 3 test files (category_seeds, demo_data_loader, demo_data_provider) with 31 tests passing. `flutter analyze` clean for changed files.

---

## 2026-06-28 — Task 20 Complete

**Task:** 20 — Testing Infrastructure ✅
**Summary:** Added reusable test infrastructure for seeded in-memory Drift databases, Riverpod ProviderContainer overrides, mocktail repository/sync/notification mocks, JSON fixtures, and a device-backed integration smoke test for the transaction add/undo data flow. Converted domain tests to `package:test` so domain coverage is pure Dart, added direct `test` and `integration_test` dev dependencies, and created a pinned Flutter 3.44.2 GitHub Actions workflow that runs pub get, build_runner, analyze, unit/widget tests, and integration tests inside an Android emulator. `dart run build_runner build`, targeted Task 20 analysis, and `flutter test --no-pub` pass locally; `flutter test --no-pub integration_test` is wired in CI but cannot run locally here without a supported connected device.

---

## 2026-06-21 — Task 15 Complete

**Task:** 15 — Presentation — Add Transaction Sheet & Forms ✅
**Summary:** Built the full Add Transaction bottom sheet with a Manual/Quick mode toggle on top of the existing transfer/edit support (preserved). Manual mode covers amount (monospace, direction-coloured AmountInput), Expense/Income direction, account dropdown with balances, direction-filtered category autocomplete, payee autocomplete that creates-on-unknown, date/time pickers, optional note, and a Transaction Mode selector (One-time / Recurring / Installment / Debt) that reveals an RRULE picker, parent-transaction picker, or debt-record picker respectively. Save runs AddTransaction/EditTransaction, pops the sheet, and pushes an UNDO snackbar via the undo stack. Quick Add (NL) mode parses input deterministically (`ParseNL`), shows a confidence-dotted preview card (amount/payee/account/category/direction), exposes a visible-but-inert mic toggle (V1), and an "Edit manually" action that switches to a pre-filled manual form. Edit transaction reuses the manual form pre-filled with "Edit Transaction" title and "Save Changes". Added new reusable inputs (AccountDropdown, CategoryAutocomplete, PayeeAutocomplete) and extended AmountInput with `label`/`onChanged`. The OCR scan screen (`screens/ocr/ocr_scan_screen.dart`) was rebuilt for REAL capture: live `camera` viewfinder with capture button, `image_picker` gallery picker, flash toggle, and ML Kit text recognition wired into `OcrPipeline._extractTextLines` (existing-file guarded, graceful no-op in headless/test). Added `camera` + `image_picker` deps. Router `/transactions/new` now also accepts `AddTransactionSheetArgs` (quick-mode / parsed-seed / edit) while keeping the `Transaction`/`Transfer` extra contract. Added widget tests for quick-add parsing, the OCR screen fallback/flash, and the new inputs. `flutter pub get`, `dart run build_runner build`, `flutter analyze --no-pub` (0 errors), and `flutter test --no-pub` (520/520 passing, +9 new) all pass.
**Device-capture caveat:** Real on-device camera capture and ML Kit extraction cannot be exercised in this headless environment; verification was limited to compile, analyze (0 errors), and widget tests that drive the gallery/flash/fallback paths with an injected OCR pipeline.

---

## 2026-06-21 — Task 16 Complete

**Task:** 16 — Presentation — Filter Sheet & Search ✅
**Summary:** Layered the full filter sheet and search functionality onto Task 12's transactions screen. Built `FilterSheet` (`lib/presentation/sheets/filter_sheet.dart`) with all six sections — Direction and Mode segmented controls, single-select Account and Category lists (categories grouped by direction), Amount Range and Date Range inputs — where segmented/list controls apply immediately to `transactionFiltersProvider` and amount/date apply on their "Apply" buttons, with a footer "Clear all filters" button and a live "Apply {n} filters" count. Upgraded the `SearchInput` component (pill shape, leading search icon, clear button, 300ms debounce) and wired it into the transactions search AppBar. Moved search logic into `filteredTransactionsProvider`, matching payee displayName/normalizedName, note, and amount case- and accent-insensitively while composing with active filters via AND logic; transfer merging from Task 12 is preserved. Added `transactionSearchQueryProvider` and removed `autoDispose` from `transactionFiltersProvider` so filters persist across tab switches (in-memory only, reset on app restart). Added `activeCount` to the `TransactionFilters` value object. Added tests: `test/presentation/sheets/filter_sheet_test.dart` (2), `test/application/providers/filtered_transactions_provider_test.dart` (3 — search/accent/amount, AND composition, date+amount), and a SearchInput debounce/clear case in `test/components/inputs_test.dart`. `flutter pub get`, `dart run build_runner build`, `flutter analyze --no-pub` (0 errors, no new warnings — 44 pre-existing issues unchanged), and `flutter test --no-pub` (517 passing, up from 511) all succeed.
---

## 2026-06-21 — Task 17 Complete

**Task:** 17 — Presentation — Onboarding ✅
**Summary:** First-launch onboarding flow implemented as a full-screen modal at `/onboarding`. Four steps (Welcome, Track, Plan, Setup) with a PageView and animated dot step indicator. Setup step collects display name, currency (dropdown, default PHP), and a "Load demo data" toggle (on by default). "Get Started" persists the profile to the users table, optionally seeds demo data via `demoDataProvider.seed()`, marks onboarding completed, and navigates to the main app. "Skip" shows a "Start with empty app?" confirmation then completes without demo data. Back button disabled via `PopScope(canPop: false)`. Extended `onboardingProvider` to a status state machine (`notStarted` / `inProgress(step)` / `completed`) persisted via SharedPreferences through a new `sharedPreferencesProvider` (overridden in `main.dart`). Router redirect continues to send not-completed users to `/onboarding` and completed users away from it. Added 7 onboarding widget tests plus expanded provider persistence tests. `dart run build_runner build --delete-conflicting-outputs` and `flutter analyze --no-pub` (0 errors) pass; `flutter test --no-pub` passes the full suite (519 tests, up from 511).

---

## 2026-06-21 — Task 14 Complete

**Task:** 14 — Presentation — More Tab & Settings ✅
**Summary:** Completed the More tab hub and pushed More flows with working create/detail actions across accounts, debts, goals, recurring items, categories, payees, households, and settings sub-screens. Replaced the household placeholder with data-backed list/detail/member management, added household providers/tests, preserved AI-gated Insights navigation, and fixed recurring edit hydration plus debt detail formatting. Regenerated Drift/JSON code with build_runner, repaired push conflict syncing so the suite verifies cleanly, and finished with `flutter test --no-pub` passing all 499 tests. `flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings` reports no analyzer errors, though existing repo warnings/infos remain.

---

## 2026-06-21 — Task 13 Complete

**Task:** 13 — Presentation — Budgets Tab ✅
**Summary:** Budgets tab implemented with month navigation, monthly summary header, category budget cards, empty/loading states, and create/edit/delete bottom-sheet flows. Budget detail now shows progress plus related transactions scoped to the selected category and period, with past-month budgets treated as read-only. The budget form now uses category autocomplete from `categoriesProvider`. Added focused provider coverage for month filtering, summary totals, and budget-detail transaction matching, plus widget coverage for the budget sheet autocomplete/edit prefill flow. `flutter analyze` passes for the Task 13 surface and targeted budget tests pass.

---

## 2026-06-21 — Task 12 Complete

**Task:** 12 — Presentation — Transactions Tab ✅
**Summary:** Completed the unified Transactions tab with sticky date-grouped list, active filter chip bar, inline AppBar search, empty/loading states, swipe edit/delete actions, pull-to-refresh sync hook, and detail screen actions/metadata. Unified provider now merges transaction rows with transfer records so transfers appear in the same list and detail route. Edit flow now supports both transaction and transfer records with prefilled forms, and transfer delete/edit paths are wired through dedicated repo/use-case support. Transaction rows now render account/category/transfer icons instead of initials. Focused analyzer and transaction/transfer tests pass.

---

## 2026-06-21 — Task 11 Complete

**Task:** 11 — Presentation — Dashboard Tab ✅
**Summary:** Dashboard home screen implemented with all 10 sections: greeting/date header with reactive sync icon and SyncStatusSheet, safe-to-spend hero backed by provider data, net worth sparkline, horizontal account cards, monthly income-vs-expense strip, animated budget progress rings, top-5 spending donut with legend, recent transactions list, upcoming recurring list, optional AI insights, plus empty and loading states. Dashboard provider now aggregates accounts, budgets, transactions, recurring items, categories, payees, and user settings into a single screen model. Added focused provider coverage and dashboard widget tests. `dart run build_runner build`, targeted `flutter analyze`, and focused `flutter test` pass in the Task 11 worktree.

---

## 2026-06-20 — Task 10 Complete

**Task:** 10 — Presentation — Navigation Shell & Tab Bar ✅
**Summary:** Full go_router configuration with StatefulShellRoute.indexedStack preserving tab state across 4 tabs. TabShell widget with BottomNavigationBar (64px, phosphor icons, active primary-600 / inactive text-tertiary). Add island (56×44px pill, primary-600, elevated) opens QuickActionsSheet. QuickActionsSheet with 3 actions (Quick Add, Manual, Scan) navigating to /transactions/new and /scan via go_router. All 33 routes from navigation-arch.md §10 registered (4 tab + 27 pushed + 2 modal/onboarding). CustomTransitionPage with proper curves/durations per design.md. AppBar per tab spec (Dashboard: sync+search, Transactions: filter+search, Budgets: [+], More: none). All placeholder screens updated with AppBars and route params. 5 new screen files created (insight_detail, report_detail, payee_detail, household_detail, ocr_scan). flutter analyze clean for new code. 494 tests pass.

---

## 2026-06-20 — Task 09 Complete

**Task:** 09 — Application Layer — AI Layer ✅
**Summary:** All AI layer files implemented: NLParser (deterministic regex-based NL parser with transfer detection, currency/abbreviation support, known payees/accounts matching), OCRPipeline (ML Kit wrapper stub, receipt field parsing), Categorizer (deterministic payee→category fallback, heuristic keyword matching, AI inference stub). AiProcessingLogRepo for audit logging. AiSettingsProvider (Notifier-based, toggle, model download status). ParseNL use case wired to NLParser. ParsedTransaction extended with isTransfer/sourceAccount/destAccount fields. 72 new AI tests (nl_parser: 72, ocr_pipeline: 4, categorizer: 13). Total 494 tests passing (380 + 114 new). flutter analyze clean for AI code.

---

## 2026-06-20 — Task 07 Complete

**Task:** 07 — Application Layer — Riverpod Providers ✅
**Summary:** All 26 provider files implemented: repository providers (re-exported), dashboard (safeToSpend, netWorth, recentTransactions, spendingByCategory, dashboardProvider), transactions (filters, filtered, tab), budgets (tab + detail), accounts (list + detail + types), debts (list + detail), goals (list + detail with progress %), recurring (list + detail), categories, payees, more tab sections, auth (V1 stub), onboarding, undo stack (single-entry, 5s expiry), demo data (seed/clear), sync (manager, health, status icon). StreamProvider for reactive Drift data, NotifierProvider for mutable state. 16 unit tests with in-memory DB override (380 total passing). flutter analyze clean.

---

## 2026-06-20 — Task 08 Complete

**Task:** 08 — Application Layer — Sync Engine ✅
**Summary:** All sync engine files implemented: SyncManager (push→pull→hooks FSM, single-cycle lock), PushClient, PullClient (cursor pagination), ConflictApplier (LWW), SyncTriggers (foreground/timer/reconnect/post-mutation), ConnectivityMonitor, SyncHttpClient. V1 gate (auth check), exponential backoff retry, sync metadata tracking. 8 source files in lib/application/sync/.

---

## 2026-06-19 — Task 06 Complete

**Task:** 06 — Domain Layer — Use Cases ✅
**Summary:** All 14 use cases implemented: AddTransaction, EditTransaction, DeleteTransaction, CreateTransfer, RecalcBalance, AddBudget, UpdateBudgetProgress, AddGoal, ContributeToGoal, SettleDebt, CreateRecurring, AdvanceRecurring, ParseNL, RunOCR. Result sealed class, ParsedTransaction and OcrPayload value objects. 75 unit tests pass with mocktail-mocked repositories. Barrel file at use_cases.dart.

---

## 2026-06-18 — Task 01 Complete

**Task:** 01 — Project Setup & Scaffolding ✅
**Summary:** Flutter project created, all dependencies installed, full directory structure scaffolded, Drift tables defined, entities as Equatable, providers stubbed. `flutter analyze` passes clean, `flutter test` runs, `build_runner` succeeds.

---

## 2026-06-19 — Tasks 02 & 03 Complete

**Task:** 02 — Design System & Theme ✅
**Summary:** All 7 theme files implemented (colors, typography, spacing, radius, shadows, theme, responsive). All 17 shared components built: buttons (4), cards (3), inputs (3), badges (4), progress (2), empty_state, sheet_handle.

**Task:** 03 — Data Layer — Drift Schema & Database ✅
**Summary:** All 16 Drift table definitions implemented (12 syncable + 4 local-only). Type converters for DateTime, bool, JSON, and all enums. `AppDatabase` class with migrations. Database provider singleton. 28 indexes, foreign key pragma enabled, in-memory DB support for tests.

---

**Task:** 04 — Data Layer — Repositories ✅
**Summary:** All 12 repository classes implemented wrapping Drift DAOs. TransactionRepo, TransferRepo handle atomic balance updates within SQLite transactions. BudgetRepo.watchSpentForBudget uses reactive stream composition. 61 unit tests pass with in-memory DB. All repos registered in repo_providers.dart.

---

**Task:** 05 — Domain Layer — Entities & Value Objects ✅
**Summary:** All 12 domain entities defined with Equatable + json_annotation + manual copyWith (freezed had unresolvable version conflicts with build_runner 2.15.0). 5 value objects implemented: Money, DateRange, TransactionFilters, SyncHealth, UndoEntry. Row→Entity and Entity→Companion mappers for all 12 entities. 66 unit tests pass. flutter analyze shows 0 domain-layer errors.

---

| Task | Status | Date |
|---|---|---|
| 01 — Project Setup & Scaffolding | ✅ Done | 2026-06-18 |
| 02 — Design System & Theme | ✅ Done | 2026-06-19 |
| 03 — Data Layer — Drift Schema & Database | ✅ Done | 2026-06-19 |
| 04 — Data Layer — Repositories | ✅ Done | 2026-06-19 |
| 05 — Domain Layer — Entities & Value Objects | ✅ Done | 2026-06-19 |
| 06 — Domain Layer — Use Cases | ✅ Done | 2026-06-19 |
| 07 — Application Layer — Riverpod Providers | ✅ Done | 2026-06-20 |
| 08 — Application Layer — Sync Engine | ✅ Done | 2026-06-20 |
| 09 — Application Layer — AI Layer | ✅ Done | 2026-06-20 |
| 10 — Presentation — Navigation Shell & Tab Bar | ✅ Done | 2026-06-20 |
| 11 — Presentation — Dashboard Tab | ✅ Done | 2026-06-21 |
| 12 — Presentation — Transactions Tab | ✅ Done | 2026-06-21 |
| 13 — Presentation — Budgets Tab | ✅ Done | 2026-06-21 |
| 14 — Presentation — More Tab & Settings | ✅ Done | 2026-06-21 |
| 15 — Presentation — Add Transaction Sheet | ✅ Done | 2026-06-21 |
| 16 — Presentation — Filter Sheet & Search | ✅ Done | 2026-06-21 |
| 17 — Presentation — Onboarding | ✅ Done | 2026-06-21 |
| 18 — Demo Data & Seed Data | ✅ Done | 2026-06-28 |
| 19 — Local Notifications | [ ] Pending | — |
| 20 — Testing Infrastructure | ✅ Done | 2026-06-28 |
| 21 — Backend — NestJS Setup & Auth | [ ] Pending | — |
| 22 — Backend — Sync Endpoints | [ ] Pending | — |

# Task 07 — Application Layer — Riverpod Providers

**Status:** [ ]

---

## Objective

Implement all Riverpod providers specified in `docs/state-management.md`. Providers bridge the domain/data layers to the presentation layer, handling loading/error/empty states and optimistic updates.

References: `docs/state-management.md`, `docs/solutions-arch.md §5 §6.2 §10.3`, `docs/domain-model.md`

## Dependencies

- 06 — Domain Layer — Use Cases
- 04 — Data Layer — Repositories

## Deliverables

### 7.1 Repository providers (already scaffolded in Task 04)
Register all 12 repos + database provider. Each is a `Provider` (no `autoDispose`, singletons).

### 7.2 Dashboard providers

| Provider | Type | Behavior |
|---|---|---|
| `safeToSpendProvider` | `Provider<SafeToSpend>` | Reads account balances, budgets, recurring upcoming. Computes: income - committed expenses. |
| `netWorthProvider` | `Provider<NetWorth>` | Sums all asset accounts - liability accounts. Real-time. |
| `recentTransactionsProvider` | `Provider<List<Transaction>>` | Last 10 transactions across all accounts. Watch mode. |
| `dashboardProvider` | `AsyncNotifierProvider` | Orchestrates dashboard data: greeting, safe-to-spend, net worth, account summary, budget progress, spending by category, recent txns, upcoming recurring, insights. |

### 7.3 Transaction providers — Tab 2

| Provider | Type | Behavior |
|---|---|---|
| `transactionFiltersProvider` | `StateProvider<TransactionFilters>` | Mutable filter state (direction, mode, account, category, amount, date range) |
| `filteredTransactionsProvider` | `AsyncNotifierProvider.family` | Reads filters from `transactionFiltersProvider`, calls `TransactionRepo.watchFiltered()`, returns filtered list |
| `transactionsTabProvider` | `AsyncNotifierProvider` | Tab-level orchestrator: list + filter state + search query |

### 7.4 Budget providers — Tab 3

| Provider | Type | Behavior |
|---|---|---|
| `budgetsTabProvider` | `AsyncNotifierProvider` | All budgets for current month/year. Computes spent per budget. |
| `budgetDetailProvider` | `AsyncNotifierProvider.family(String budgetId)` | Single budget + spent amount + related transactions. Disposed on pop. |

### 7.5 Account providers

| Provider | Type | Behavior |
|---|---|---|
| `accountsProvider` | `AsyncNotifierProvider` | All non-archived accounts. Grouped by account type. |
| `accountDetailProvider` | `AsyncNotifierProvider.family(String accountId)` | Single account + balance + recent transactions. Disposed on pop. |
| `accountTypesProvider` | `Provider` | Static list of account type enums for dropdowns. |

### 7.6 Debt providers

| Provider | Type | Behavior |
|---|---|---|
| `debtsProvider` | `AsyncNotifierProvider` | All debt records, grouped by status. |
| `debtDetailProvider` | `AsyncNotifierProvider.family(String debtId)` | Single debt + payment history. Disposed on pop. |

### 7.7 Goal providers

| Provider | Type | Behavior |
|---|---|---|
| `goalsProvider` | `AsyncNotifierProvider` | All goals with computed progress %. |
| `goalDetailProvider` | `AsyncNotifierProvider.family(String goalId)` | Single goal + contribution history. Disposed on pop. |

### 7.8 Recurring providers

| Provider | Type | Behavior |
|---|---|---|
| `recurringProvider` | `AsyncNotifierProvider` | All recurring templates, sorted by next_occurrence_at. |
| `recurringDetailProvider` | `AsyncNotifierProvider.family(String id)` | Single template + generated transaction history. Disposed on pop. |

### 7.9 Category & Payee providers

| Provider | Type | Behavior |
|---|---|---|
| `categoriesProvider` | `Provider` | All categories, grouped by category_group. Used by autocomplete. |
| `payeesProvider` | `Provider` | All payees. Used by autocomplete. |

### 7.10 More tab provider

| Provider | Type | Behavior |
|---|---|---|
| `moreTabProvider` | `Provider<List<Section>>` | Static sections: Financial, Insights, Manage, Settings. Returns section list for More screen. |

### 7.11 App-wide providers

| Provider | Type | Behavior |
|---|---|---|
| `themeProvider` | `StateProvider<ThemeMode>` | Reads/writes to SharedPreferences. Default: system. |
| `localeProvider` | `StateProvider<Locale>` | Reads/writes to SharedPreferences. |
| `onboardingProvider` | `StateProvider<OnboardingState>` | Tracks onboarding completion. Persisted in SharedPreferences. |
| `authProvider` | `StateNotifierProvider<AuthNotifier, AuthState>` | Stub in V1 — always returns `unauthenticated`. Full impl in V2. |

### 7.12 UI utility providers

| Provider | Type | Behavior |
|---|---|---|
| `undoStackProvider` | `StateNotifierProvider<UndoStackNotifier, List<UndoEntry>>` | Stack of undo-able operations. Max 1 entry at a time (5s expiry). |
| `undoEntryProvider` | `Provider.family<UndoEntry?, String>` | Exposes current undo entry for a screen context. |
| `snackbarProvider` | `StateNotifierProvider` | Global snackbar message queue for cross-screen notifications. |

### 7.13 Sync providers (bridge to sync engine)

| Provider | Type | Behavior |
|---|---|---|
| `syncManagerProvider` | `Provider<SyncManager>` | Singleton sync manager. Never disposed. |
| `syncHealthProvider` | `Provider<SyncHealth>` | Reads from `SyncMetadataRepo`. Reactive. |
| `syncStatusIconProvider` | `Provider<SyncIconState>` | Derived from sync health + connectivity. States: synced/pending/syncing/failed/offline. |

### 7.14 Demo data provider
`demoDataProvider` — `AsyncNotifierProvider<DemoDataNotifier, DemoDataState>`
- `seed()` — populates DB with realistic demo data
- `clear()` — removes all demo data
- `hasDemoData` — checks if demo data exists

### 7.15 Provider scoping
- Tab-scoped providers use `autoDispose` + `KeepAliveLink` in ShellRoute
- Screen-scoped (detail) providers use `autoDispose.family` (disposed on pop)
- Singleton providers have no `autoDispose`

## Acceptance Criteria

- [ ] All providers compile and are registered in their respective files
- [ ] `safeToSpendProvider` computes correct safe-to-spend = total income - committed expenses
- [ ] `netWorthProvider` computes correct net worth = sum(assets) - sum(liabilities)
- [ ] `filteredTransactionsProvider` reacts to `transactionFiltersProvider` changes
- [ ] `budgetDetailProvider` returns spent amount matching budget's category+period
- [ ] `goalDetailProvider` returns correct progress % = currentAmount / targetAmount * 100
- [ ] Tab-scoped providers survive tab switches (KeepAliveLink)
- [ ] Screen-scoped providers are disposed on pop (no memory leaks)
- [ ] `undoStackProvider` enforces single-entry policy (oldest expires at 5s)
- [ ] All providers have unit tests with in-memory DB override

## Files Likely Affected

- `lib/application/providers/database_provider.dart` (extended from Task 03)
- `lib/application/providers/repo_providers.dart` (extended from Task 04)
- `lib/application/providers/dashboard_provider.dart` (new)
- `lib/application/providers/safe_to_spend_provider.dart` (new)
- `lib/application/providers/net_worth_provider.dart` (new)
- `lib/application/providers/transactions_tab_provider.dart` (new)
- `lib/application/providers/transaction_filters_provider.dart` (new)
- `lib/application/providers/filtered_transactions_provider.dart` (new)
- `lib/application/providers/budgets_tab_provider.dart` (new)
- `lib/application/providers/budget_detail_provider.dart` (new)
- `lib/application/providers/accounts_provider.dart` (new)
- `lib/application/providers/account_detail_provider.dart` (new)
- `lib/application/providers/debts_provider.dart` (new)
- `lib/application/providers/debt_detail_provider.dart` (new)
- `lib/application/providers/goals_provider.dart` (new)
- `lib/application/providers/goal_detail_provider.dart` (new)
- `lib/application/providers/recurring_provider.dart` (new)
- `lib/application/providers/recurring_detail_provider.dart` (new)
- `lib/application/providers/categories_provider.dart` (new)
- `lib/application/providers/payees_provider.dart` (new)
- `lib/application/providers/more_tab_provider.dart` (new)
- `lib/application/providers/auth_provider.dart` (new)
- `lib/application/providers/theme_provider.dart` (new)
- `lib/application/providers/onboarding_provider.dart` (new)
- `lib/application/providers/undo_stack_provider.dart` (new)
- `lib/application/providers/demo_data_provider.dart` (new)
- `lib/application/providers/sync_providers.dart` (new)
- `test/application/providers/` (new)

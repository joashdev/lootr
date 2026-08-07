# State Management — Personal Finance App

Riverpod provider structure, data flow, and state patterns for the Flutter app.

References: `product-strategy.md` (optimistic UI, offline-first), `database-schema.md` (Drift streams, sync fields), `sync-engine.md` (sync status FSM, post-sync hooks), `navigation-arch.md` (tab scoping, undo snackbar), `solutions-arch.md` (layered architecture §5, data flow §6).

---

## 1. Overview

State management is layered to match the architecture:

- **Drift `.watch()`** at the data layer emits reactive streams from SQLite.
- **Repository providers** wrap Drift DAOs, exposing typed `Stream<List<T>>` for reads and `Future<void>` for writes.
- **Feature providers** consume repositories, apply domain logic, and expose `AsyncValue<T>` to the UI.
- **Tab-scoped providers** keep scroll position and filter state across tab switches.
- **Sync state** is derived from `sync_metadata` and per-row `sync_status` — not stored in feature providers.

Every read is local. Every write hits the local DB first and triggers a debounced sync cycle. The UI updates from Drift streams before sync completes (optimistic).

---

## 2. Provider Hierarchy

```
ProviderScope (root)
 │
 ├── databaseProvider         ← Drift Database singleton
 │
 ├── Repository providers (stateless, depend on databaseProvider)
 │   ├── transactionRepoProvider
 │   ├── accountRepoProvider
 │   ├── budgetRepoProvider
 │   ├── categoryRepoProvider
 │   ├── payeeRepoProvider
 │   ├── transferRepoProvider
 │   ├── debtRepoProvider
 │   ├── goalRepoProvider
 │   ├── recurringRepoProvider
 │   └── userRepoProvider
 │
 ├── Feature providers (depends on repo providers)
 │   ├── dashboardProvider         ← scoped to Dashboard tab
 │   │   ├── safeToSpendProvider
 │   │   ├── netWorthProvider
 │   │   └── recentTransactionsProvider
 │   ├── transactionsTabProvider   ← scoped to Transactions tab
 │   │   └── filteredTransactionsProvider(filters)
 │   ├── budgetsTabProvider        ← scoped to Budgets tab
 │   │   └── budgetDetailProvider(budgetId)
 │   ├── moreTabProvider           ← scoped to More tab
 │   ├── accountDetailProvider(accountId)
 │   ├── debtDetailProvider(debtId)
 │   ├── goalDetailProvider(goalId)
 │   └── recurringDetailProvider(templateId)
 │
 ├── App-level providers
 │   ├── authProvider              ← login state, JWT tokens
 │   ├── themeProvider             ← light/dark/system
 │   ├── localeProvider            ← currency, locale, timezone
 │   └── onboardingProvider        ← completed? skipped?
 │
 ├── Sync providers
 │   ├── syncManagerProvider       ← orchestrates sync cycle
 │   ├── syncHealthProvider        ← reads sync_metadata table
 │   └── syncStatusIconProvider    ← derived: synced/pending/syncing/failed/offline
 │
 ├── UI ephemeral providers
 │   ├── undoStackProvider         ← rollback closures, auto-pop after 5s
 │   ├── filterSheetProvider       ← Filter Sheet state (directions, modes, …)
 │   ├── quickAddPreviewProvider   ← NL parse preview before save
 │   └── demoDataProvider          ← seeds/clears demo data
 │
 └── Cross-cutting
     ├── snackbarProvider          ← global snackbar queue
     └── errorReporterProvider     ← Sentry + local log sink
```

### Scoping rules

| Scope | Mechanism | Example |
|---|---|---|
| App-wide (singleton) | `databaseProvider`, `syncManagerProvider` | One Drift DB, one sync lock |
| Tab-scoped | `autoDispose` + `KeepAliveLink` held by `ShellRoute` | `transactionsTabProvider`, `budgetsTabProvider` |
| Screen-scoped | `autoDispose`, created on push, disposed on pop | `budgetDetailProvider(budgetId)` |
| Ephemeral | StatefulWidget local state | Quick Add autofill preview, camera preview |

Tab-scoped providers use `autoDispose` to free resources when the tab is destroyed, but are kept alive while the tab exists via `KeepAliveLink`. Scroll position and filter state survive tab switches because the provider instance persists.

---

## 3. Data Flow Patterns

### 3.1 Read path (stream from Drift)

```
Widget
  │  ref.watch(filteredTransactionsProvider(filters))
  ▼
filteredTransactionsProvider (family, autoDispose)
  │  ref.watch(transactionRepoProvider).watchFiltered(filters)
  ▼
TransactionRepo.watchFiltered(filters)
  │  driftDb.select(transactions).watch()
  │  WHERE account_id = ? AND occurred_at BETWEEN ? AND ?
  ▼
Stream<List<TransactionRow>>
  │  emitted on every INSERT/UPDATE/DELETE in transactions table
  ▼
AsyncValue<List<TransactionView>>
  │  provider maps rows → domain entities → view models
  ▼
Widget rebuilds with AsyncValue.data, .loading, or .error
```

**Key property:** A write in any context (any screen, any tab, sync pull) triggers the Drift stream. All watching widgets rebuild automatically. No explicit event bus or manual invalidation needed. The SQLite transaction boundary ensures the stream fires only after the full mutation is committed.

### 3.2 Write path (optimistic local save)

```
User taps "Save"
  │
  ▼
Widget calls ref.read(addTransactionProvider(transaction)).save()
  │
  ▼
addTransactionProvider
  │  awaits transactionRepo.create(transaction)
  │
  ▼
TransactionRepo.create(tx)
  │  BEGIN TRANSACTION
  │    INSERT INTO transactions (...) VALUES (...)
  │    UPDATE accounts SET balance = balance ± amount WHERE id = ?
  │    UPDATE accounts SET sync_status = 'pending_sync' WHERE id = ?
  │  COMMIT
  │  return transactionId
  │
  ▼
Drift stream fires → watching providers rebuild → UI shows new row
  │
  ▼
snackbarProvider.emitUndo(transactionId)
  │  "Transaction saved · UNDO" — auto-dismiss 5s
  │  onUndo: transactionRepo.delete(transactionId)
  │           → Drift stream fires → UI removes row
  │           → undo auto-pop
  │
  ▼
Sync trigger debounced 30s
```

**Key property:** The UI never awaits sync. The write hits the local DB, the stream updates the UI, and sync happens later. If the user undoes, the row is deleted from SQLite — sync never sees it (it was `local_only` and gone before the push cycle).

### 3.3 Sync interaction with providers

```
Sync cycle
  │
  ├─ PUSH: status 'local_only'/'pending_sync' → POST /sync/push
  │   └─ On success: UPDATE sync_status='synced', last_synced_at=now
  │                 → Drift stream fires for those rows
  │                 → syncStatusIconProvider recomputes (sync_failed_count drops)
  │
  ├─ PULL: POST /sync/pull → upsert server records local
  │   └─ INSERT or UPDATE on local tables
  │      → Drift streams fire for affected tables
  │      → watching providers rebuild with new/updated data
  │
  └─ POST-SYNC: rebuild account_balance_snapshots, reschedule notifications
     → relevant providers rebuild
```

Providers do NOT trigger sync. The `syncManagerProvider` listens to network/foreground/timer events independently. Providers just react to the DB changes that sync produces. This keeps the data-flow unidirectional: sync writes to DB → DB streams fire → providers rebuild.

---

## 4. Provider Design Patterns

### 4.1 Repository providers

Stateless, pure data access. One per table group. Injected into feature providers via `ref.watch`.

```dart
// Stateless — just exposes the DAO methods
final transactionRepoProvider = Provider<TransactionRepo>((ref) {
  return TransactionRepo(ref.watch(databaseProvider));
});

// Interface
class TransactionRepo {
  final AppDatabase _db;
  TransactionRepo(this._db);

  Stream<List<TransactionRow>> watchFiltered(TransactionFilters filters) { ... }
  Future<String> create(TransactionCompanion tx) { ... }
  Future<void> update(TransactionCompanion tx) { ... }
  Future<void> softDelete(String id) { ... }
}
```

### 4.2 Feature providers (AsyncNotifier)

For screens that need loading/error/empty states. Uses `AsyncNotifier` from Riverpod 2.x.

```dart
final transactionsProvider =
    AsyncNotifierProvider.autoDispose
        .family<TransactionsState, TransactionFilters>(
            () => TransactionsNotifier);

class TransactionsNotifier
    extends AutoDisposeFamilyAsyncNotifier<TransactionsState, TransactionFilters> {
  @override
  Future<TransactionsState> build(TransactionFilters arg) async {
    final repo = ref.watch(transactionRepoProvider);
    // Returns AsyncValue.data, .loading, .error
    return repo.watchFiltered(arg).map((rows) => ...);
  }
}
```

### 4.3 Filter state within a tab provider

The filter state is a separate `StateProvider` within the tab scope. The feature provider watches it and recomputes the query.

```dart
final transactionFiltersProvider =
    StateProvider.autoDispose<TransactionFilters>((ref) => TransactionFilters.defaults);

final filteredTransactionsProvider =
    AsyncNotifierProvider.autoDispose<FilteredTransactionsState>(
        () => FilteredTransactionsNotifier);

class FilteredTransactionsNotifier extends AutoDisposeAsyncNotifier<...> {
  @override
  Future<...> build() async {
    final filters = ref.watch(transactionFiltersProvider);
    final repo = ref.watch(transactionRepoProvider);
    // Re-runs whenever filterProvider changes
    return repo.watchFiltered(filters).map(...);
  }
}
```

This pattern means changing a filter chip in the UI updates a `StateProvider`, which causes the feature provider to re-`build()` with the new filter, producing a new stream for the UI.

### 4.4 Undo stack pattern

```dart
final undoStackProvider = StateNotifierProvider<UndoStackNotifier, List<UndoEntry>>((ref) {
  return UndoStackNotifier();
});

class UndoEntry {
  final String transactionId;
  final String message;     // "Transaction saved"
  final Future<void> Function() rollback;
  final DateTime createdAt;
}

class UndoStackNotifier extends StateNotifier<List<UndoEntry>> {
  void push(UndoEntry entry) {
    state = [...state, entry];
    Future.delayed(Duration(seconds: 5), () => _pop(entry.id));
  }

  Future<void> undo(String id) async {
    final entry = state.firstWhere((e) => e.id == id);
    await entry.rollback();
    state = state.where((e) => e.id != id).toList();
  }
}
```

A `SnackbarListener` widget at the root of each tab watches `undoStackProvider` and shows the snackbar when a new entry appears, dismissing when it auto-pops.

### 4.5 Sync health provider

Aggregates sync metadata into a simple UI state.

```dart
enum SyncIconState { synced, pending, syncing, failed, offline }

final syncHealthProvider = Provider<SyncHealth>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncHealth(
    lastSyncedAt: db.syncMetadata('last_synced_at'),
    pendingCount: db.countPendingSync(),
    failedCount: db.countSyncFailed(),
    lastStatus: db.syncMetadata('last_sync_status'),
  );
});

final syncStatusIconProvider = Provider<SyncIconState>((ref) {
  final health = ref.watch(syncHealthProvider);
  // Derived state — maps counts + status + connectivity to icon
  ...
});
```

---

## 5. Loading / Error / Empty States

### 5.1 Pattern

Every feature provider returns `AsyncValue<T>`. The UI maps the three variants:

```dart
final state = ref.watch(filteredTransactionsProvider(filters));

return switch (state) {
  AsyncLoading()   => SkeletonList(count: 5),
  AsyncError(:final error) => ErrorState(message: error.toString(), onRetry: () => ref.invalidate(...)),
  AsyncData(:final value) when value.isEmpty => EmptyTransactionsState(filters: filters),
  AsyncData(:final value) => TransactionListView(transactions: value),
};
```

### 5.2 Empty state conventions

| Situation | Illustration | Primary CTA | Secondary CTA |
|---|---|---|---|
| No accounts exist | Empty wallet | "Add Account" | "Try demo data" |
| Accounts exist, no transactions | Empty envelope | "Add Transaction" | "Try demo data" |
| No budgets set | Empty chart | "Create First Budget" | "Auto-suggest" |
| No debts | Empty handshake | "Add Debt" | — |
| No goals | Empty target | "Add Goal" | — |
| No results (filter) | Empty search | "Clear Filters" | — |

### 5.3 Error state

| Error type | UI |
|---|---|
| Drift/DB error | "Something went wrong loading your data." Retry button invalidates the provider. |
| Sync failed records | Sync status sheet shows count; manual "Retry" per record or "Retry All". |
| Network error (sync) | Sync icon → amber cloud-exclamation; tap → Sync Status sheet with error details. |

---

## 6. Optimistic Update Flow

Optimistic: the UI shows the result of a write immediately, before any confirmation from sync.

```
1. User fills form, taps Save
2. Widget calls ref.read(addTransactionProvider).save(transaction)
3. Provider awaits repo.create() — inserts into SQLite
4. Drift stream fires → watching providers rebuild → new row appears in list
5. Sync trigger fires 30s later (if no other mutations in that window)
6. If sync push fails: record stays sync_failed; UI shows amber indicator on that row
7. If sync push conflicts (server has newer): LWW resolves → server version overwrites local
   → Drift stream fires → row updates in place
```

The optimistic part is steps 2-4: the row appears before sync. Users never wait for the network. The downside (sync_failed or conflict overwrite) is rare and handled gracefully — the row is still there, just with a different status or content.

---

## 7. Demo Data Provider

```dart
final demoDataProvider = AsyncNotifierProvider<DemoDataNotifier, DemoDataState>(() {
  return DemoDataNotifier();
});

class DemoDataNotifier extends AsyncNotifier<DemoDataState> {
  Future<void> seed() async {
    final db = ref.read(databaseProvider);
    // Seed: 3 accounts, 30 days transactions, 4 budgets, 2 recurring
    await db.seedDemoData();
  }

  Future<void> clear() async {
    final db = ref.read(databaseProvider);
    await db.clearDemoData();  // Delete rows registered in demo_records.
  }

  bool get hasDemoData => ...;  // check from sync_metadata or flag
}
```

`demoDataProvider` reads the local `demo_records` table so its state survives restarts. Settings → Data & Backup shows "Clear sample data" while registered rows exist. Clearing is atomic, preserves personal dependencies through the reviewed recovery path, and refreshes watching providers through Drift stream triggers. An incomplete legacy sample set stays unverified until the user reviews removal of exact known sample IDs. Ambiguous rows remain unchanged. If a legacy flag remains without known sample rows, the user can dismiss only that stale status without deleting records.

---

## 8. Provider Lifetime & Tab Scoping

### 8.1 Tab preservation with `autoDispose` + `KeepAliveLink`

```dart
final transactionsTabProvider = AsyncNotifierProvider.autoDispose<...>(() {
  return TransactionsTabNotifier();
});

// In the ShellRoute builder:
@override
Widget build(BuildContext context, WidgetRef ref, Widget navigator) {
  return KeepAlive(
    link: ref.keepAlive(),
    child: navigator,
  );
}
```

When a tab is switched away, `autoDispose` would normally dispose the provider. But `KeepAliveLink` holds a reference, preventing auto-disposal. The provider stays alive until the tab is removed from the navigation stack entirely (e.g., logout). Scroll position and filter state are preserved because the provider instance never rebuilds from scratch.

### 8.2 Screen-scoped (pushed pages)

Pushed screens (e.g., `budgetDetailProvider(budgetId)`) use `autoDispose` without a keep-alive link. They are created on push and disposed on pop. No scroll preservation needed — the user navigates away and back to the list.

### 8.3 App-wide (never disposed)

```
databaseProvider       — never disposed (lifetime = app runtime)
syncManagerProvider    — never disposed
authProvider           — never disposed
themeProvider          — never disposed
```

These are registered at `ProviderScope` root with no `autoDispose`. Singleton lifetime.

---

## 9. Repository Injection & Testing

### 9.1 Injection pattern

Repositories are injected via Riverpod:

```dart
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();  // Drift-generated
  return db;
});

final transactionRepoProvider = Provider<TransactionRepo>((ref) {
  return TransactionRepo(ref.watch(databaseProvider));
});
```

Feature providers depend on repo providers:

```dart
final transactionsProvider = AsyncNotifierProvider<...>(() {
  return TransactionsNotifier();
});

class TransactionsNotifier extends AsyncNotifier<...> {
  Future<...> build() async {
    final repo = ref.watch(transactionRepoProvider);  // injected
    return repo.watchAll().map(...);
  }
}
```

### 9.2 Testing with overrides

```dart
void main() {
  test('Transaction list shows saved rows', () async {
    final container = ProviderContainer(
      overrides: [
        // Override database with in-memory instance
        databaseProvider.overrideWith((ref) => AppDatabase.inMemory()),
      ],
    );

    addTearDown(container.dispose);

    // Apply migrations
    final db = container.read(databaseProvider);
    await db.migrate();

    // All downstream providers use the in-memory DB automatically
    final repo = container.read(transactionRepoProvider);
    await repo.create(testTransaction());

    final state = await container.read(filteredTransactionsProvider(defaultFilters).future);
    expect(state, hasLength(1));
  });
}
```

Overriding `databaseProvider` at the container level propagates to all repo and feature providers — no individual mocking needed. Drift's in-memory `NativeDatabase` provides a real SQLite instance in test.

---

## 10. AI-Assisted Entry State

The Quick Add NL preview is ephemeral — it lives in a `StatefulWidget`'s local state, not in a Riverpod provider. Only the persisted transaction touches the provider layer.

```
User types NL text
  │
  ▼
StatefulWidget local state
  │  calls NL parser (deterministic → AI fallback)
  │  holds parsedPreview: {amount, payee, category, account}
  │  shows preview card (not persisted)
  │
  ▼
User taps "Confirm"
  │
  ▼
ref.read(addTransactionProvider).save(parsedPreview)
  │  → normal write path (see §3.2)
  │
  ▼
Widget clears local state, sheet dismisses
```

If the user dismisses without confirming, the preview is discarded — nothing hits the provider layer.

---

## 11. Balance Recalculation & Provider Invalidation

When the balance recalculation utility runs (recovery tool, `recalcBalances()`), it directly updates `accounts.balance` in SQLite. This triggers the Drift stream for `accounts`, which causes all account-watching providers to rebuild.

No explicit provider invalidation needed — the Drift `.watch()` stream handles it automatically. The utility just writes to SQLite; providers follow.

---

## 12. Provider Map (Complete)

| Provider | Type | Scope | Depends on |
|---|---|---|---|
| `databaseProvider` | `Provider<AppDatabase>` | App-wide | — |
| `transactionRepoProvider` | `Provider<TransactionRepo>` | App-wide | `databaseProvider` |
| `accountRepoProvider` | `Provider<AccountRepo>` | App-wide | `databaseProvider` |
| `budgetRepoProvider` | `Provider<BudgetRepo>` | App-wide | `databaseProvider` |
| `categoryRepoProvider` | `Provider<CategoryRepo>` | App-wide | `databaseProvider` |
| `payeeRepoProvider` | `Provider<PayeeRepo>` | App-wide | `databaseProvider` |
| `transferRepoProvider` | `Provider<TransferRepo>` | App-wide | `databaseProvider` |
| `debtRepoProvider` | `Provider<DebtRepo>` | App-wide | `databaseProvider` |
| `goalRepoProvider` | `Provider<GoalRepo>` | App-wide | `databaseProvider` |
| `recurringRepoProvider` | `Provider<RecurringRepo>` | App-wide | `databaseProvider` |
| `userRepoProvider` | `Provider<UserRepo>` | App-wide | `databaseProvider` |
| `authProvider` | `StateNotifierProvider` | App-wide | `userRepoProvider` |
| `themeProvider` | `StateProvider<ThemeMode>` | App-wide | — |
| `syncManagerProvider` | `Provider<SyncManager>` | App-wide | repos, `authProvider` |
| `syncHealthProvider` | `Provider<SyncHealth>` | App-wide | `databaseProvider` |
| `syncStatusIconProvider` | `Provider<SyncIconState>` | App-wide | `syncHealthProvider` |
| `dashboardProvider` | `AsyncNotifierProvider` | Tab 1 | `accountRepoProvider`, `transactionRepoProvider`, `budgetRepoProvider` |
| `safeToSpendProvider` | `Provider<SafeToSpend>` | Tab 1 | `dashboardProvider` |
| `netWorthProvider` | `Provider<NetWorth>` | Tab 1 | `dashboardProvider` |
| `recentTransactionsProvider` | `Provider<List<Transaction>>` | Tab 1 | `transactionRepoProvider` |
| `transactionsTabProvider` | `AsyncNotifierProvider` | Tab 2 | `transactionRepoProvider` |
| `transactionFiltersProvider` | `StateProvider<TransactionFilters>` | Tab 2 | — |
| `filteredTransactionsProvider` | `AsyncNotifierProvider.family` | Tab 2 | `transactionRepoProvider`, `transactionFiltersProvider` |
| `budgetsTabProvider` | `AsyncNotifierProvider` | Tab 3 | `budgetRepoProvider`, `transactionRepoProvider` |
| `budgetDetailProvider` | `AsyncNotifierProvider.family` | Pushed | `budgetRepoProvider`, `transactionRepoProvider` |
| `moreTabProvider` | `Provider<List<Section>>` | Tab 4 | — (static sections) |
| `accountDetailProvider` | `AsyncNotifierProvider.family` | Pushed | `accountRepoProvider`, `transactionRepoProvider` |
| `debtDetailProvider` | `AsyncNotifierProvider.family` | Pushed | `debtRepoProvider` |
| `goalDetailProvider` | `AsyncNotifierProvider.family` | Pushed | `goalRepoProvider` |
| `recurringDetailProvider` | `AsyncNotifierProvider.family` | Pushed | `recurringRepoProvider` |
| `undoStackProvider` | `StateNotifierProvider` | App-wide | — |
| `filterSheetProvider` | `StateProvider<FilterSheetState>` | Ephemeral | — |
| `addTransactionProvider` | `Provider<Future<void> Function(Transaction)>` | App-wide | `transactionRepoProvider` |
| `demoDataProvider` | `AsyncNotifierProvider` | App-wide | `databaseProvider` |
| `onboardingProvider` | `StateProvider<OnboardingState>` | App-wide | — |
| `snackbarProvider` | `StateNotifierProvider` | App-wide | — |

---

## 13. Anti-Patterns (what NOT to do)

| Anti-pattern | Why avoid | Correct pattern |
|---|---|---|
| Direct DB access from widgets | Breaks layered architecture; untestable | Always go through a provider → repo |
| `ref.refresh` to force reload | Works against Drift's reactive streams | Trust `.watch()` — it fires on every mutation |
| `ref.watch` in write methods | Writes should not subscribe to data | Use `ref.read` inside `save()` / `delete()` methods |
| Storing sync status in feature providers | Redundant; sync_status is on every row in DB | Read sync_status from entity rows; aggregate via `syncHealthProvider` |
| One provider per screen (monolith) | Unnecessary rebuilds; hard to test | Compose small providers; use `family` for parameterization |
| `ChangeNotifier` in Riverpod 2.x | Legacy pattern; not compile-safe | Use `Notifier` / `AsyncNotifier` (Riverpod 2.x code-gen) |
| Ephemeral form state in providers | Pollutes long-lived state | `StatefulWidget` local state for uncommitted form fields |

---

## 14. Summary

| Concern | Pattern |
|---|---|
| Data reads | Drift `.watch()` → Stream → `AsyncNotifier` → `AsyncValue` → Widget |
| Data writes | Widget → Provider → Repo → SQLite → Stream fires → Widget rebuilds |
| Optimistic UI | Write to local DB first; sync happens later; stream updates all observers |
| Tab scoping | `autoDispose` + `KeepAliveLink`; scroll + filter survive tab switches |
| Undo | `undoStackProvider` holds rollback closures; 5s auto-pop |
| Loading/error/empty | `AsyncValue` switch expression in widgets |
| Sync state | Separate `syncHealthProvider` derived from `sync_metadata` + per-row `sync_status` |
| Demo data | `demoDataProvider` seeds via repos; clear invalidates all watching providers |
| AI preview | Local `StatefulWidget` state; only persisted on confirm |
| Testing | Override `databaseProvider` with in-memory Drift at `ProviderContainer` level |

---

## 15. Migration, Maintenance, and Database Lifecycle

The migration flow uses durable database state rather than widget-only progress.

| **Provider** | **Scope** | **Responsibility** |
|---|---|---|
| `databaseLifecycleProvider` | App-wide | Open/close/reopen encrypted DB; quiesce consumers for restore |
| `maintenanceLockProvider` | App-wide | Exclude sync, notification rebuild, import publication, rollback, and restore |
| `migrationCoordinatorProvider` | App-wide | Resume/checkpoint/cancel workers and project safe run state |
| `importRunProvider(runId)` | Screen | Watch durable run, dispositions, issues, reconciliation, and cleanup |
| `backupProvider` | App-wide | Create/verify/restore versioned encrypted backups and CSV exports |

Source picker, filesystem, clock, UUID, secure-key storage, and fault injection are injectable providers. Startup recovery scans nonterminal runs. UI cancellation writes `cancel_requested`; the worker closes handles, cleans staging, and records `cancelled`. `applying` and `verifying` are non-cancellable because publication must commit or roll back atomically.

Database restore/rollback acquires the maintenance lock, closes Drift, verifies and atomically replaces the file, reopens it, then invalidates database-dependent providers and rebuilds notifications. Raw migration exceptions never enter `AsyncError` text; only a redacted `SafeMigrationFailure` reaches the UI.

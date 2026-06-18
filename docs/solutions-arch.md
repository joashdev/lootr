# Solution Architecture — Personal Finance App

Synthesizes the foundation specs into one cohesive view of how the system fits together. Onboarding doc for any developer entering the project.

References (source of truth for detail):
- `product-strategy.md` — vision, personas, V1 scope, tech stack
- `domain-model.md` — entities, fields, relationships
- `database-schema.md` — 16 tables (12 syncable + 4 local-only), Drift mappings, migrations
- `api-contracts.md` — REST API, auth, sync endpoints, errors
- `sync-engine.md` — sync triggers, FSM, push/pull, LWW
- `navigation-arch.md` — 50 screens, tab bar, routing, sheets
- `design.md` — color/typography/spacing tokens, components, dark mode

---

## 1. What We're Building

A calm, offline-first, privacy-first personal finance app for early-career professionals. The local SQLite database is the primary runtime — every read and write happens locally. A NestJS backend exists only as an optional sync/backup layer; it never computes balances, dashboards, or analytics.

- **V1 is fully local.** No login wall. Sync infrastructure is built but email auth is disabled until V2.
- **AI is optional and on-device** (llama.cpp / GGUF). Core features work without it.
- **No bank integrations.** Manual entry + OCR + natural language parsing only.
- **Save-first.** Transactions persist immediately; no review queue. Correction-friendly with undo.

---

## 2. System Context

```
┌──────────────────────────────────────────────────────────┐
│                   MOBILE APP (Flutter)                    │
│                                                          │
│   ┌────────────┐   ┌────────────┐   ┌──────────────┐    │
│   │  UI Layer   │   │  Domain    │   │  AI Layer    │    │
│   │ (Riverpod)  │   │  Logic     │   │ (llama.cpp)  │    │
│   │  50 screens │   │  parsers,  │   │  OCR, NLP,   │    │
│   │  go_router  │   │  calcs,    │   │  categorize  │    │
│   │             │   │  rules     │   │  (optional)  │    │
│   └──────┬──────┘   └──────┬─────┘   └──────┬───────┘    │
│          │                 │                │             │
│          └────────┬────────┴────────────────┘             │
│                   ▼                                       │
│          ┌────────────────────┐   ┌──────────────────┐   │
│          │  Data Layer (Drift) │   │  Local Notifs     │   │
│          │  Repository pattern │   │  (flutter_local_  │   │
│          │                     │   │   notifications)  │   │
│          └────────┬───────────┘   └──────────────────┘   │
│                   ▼                                       │
│          ┌────────────────────┐                          │
│          │  SQLite (primary)   │                          │
│          │  16 tables, encrypted│                          │
│          │  fast indexed reads │                          │
│          └────────┬───────────┘                          │
│                   ▼                                       │
│          ┌────────────────────┐                          │
│          │  Sync Engine        │                          │
│          │  push/pull over HTTP│                          │
│          │  LWW, FSM, retry    │                          │
│          └────────┬───────────┘                          │
└───────────────────┼──────────────────────────────────────┘
                    │ HTTPS · REST · Bearer JWT
                    │ (opt-in, only after V2 auth)
┌───────────────────┼──────────────────────────────────────┐
│              BACKEND (NestJS)                            │
│   ┌───────────────┴──────────────┐                       │
│   │  /auth    OTP, refresh, JWT   │                       │
│   │  /sync    push, pull (cursor) │                       │
│   │  /uploads receipt images      │                       │
│   │  /me, /users  profile, search │                       │
│   └───────────────┬──────────────┘                       │
│   ┌───────────────┴──────────────┐                       │
│   │  PostgreSQL                   │                       │
│   │  12 syncable tables           │                       │
│   │  (mirror of local schema)     │                       │
│   └──────────────────────────────┘                       │
└──────────────────────────────────────────────────────────┘
```

### Boundaries

| Boundary | Direction | What crosses it |
|---|---|---|
| UI ↔ Domain | bidirectional | User intents up, view models down |
| Domain ↔ Data | bidirectional | Repository calls down, entity streams up |
| Data ↔ SQLite | local | SQL queries, Drift-generated |
| App ↔ AI Layer | local, optional | Raw text/image in, extracted payload out |
| Sync Engine ↔ Backend | network | JSON batches over HTTPS (V2+) |

The backend is a **dumb store + auth gate**. It validates and persists syncable rows. No business logic, no balance computation, no analytics. This keeps the server simple and the app fast offline.

---

## 3. Architecture Principles

| Principle | How it shapes the code |
|---|---|
| **Local-first** | SQLite is the runtime source. Every read is a local query. Network is never on the critical path for UI. |
| **Offline-first** | App is fully functional with no connectivity. Sync queues mutations and replays on reconnect. |
| **Save-first** | Transactions persist immediately on confirm. No review queue, no draft state. Undo snackbar (5s) is the safety net. |
| **Optimistic UI** | Writes update the local DB and notify providers before any sync. UI never waits on the network. |
| **Server is sync-only** | Backend stores and returns rows. Balances, budgets, reports — all computed on-device. |
| **AI is assistive, never authoritative** | AI extracts and suggests; it never mutates finances without user confirm. Core flows work with AI disabled. |
| **Sync-friendly from day one** | Every syncable table carries `id` (UUID), `created_at`, `updated_at`, `deleted_at`, `sync_status`, `last_synced_at`. |
| **Calm, not gamified** | Color-only semantic feedback. No streaks, badges, or guilt language. |
| **Additive migrations** | V1 schema changes add columns, never drop. Soft deletes handle removal. |

---

## 4. Tech Stack

### Mobile

| Layer | Choice | Why |
|---|---|---|
| Framework | Flutter | Single codebase, iOS + Android, strong widget testing |
| State | Riverpod | Compile-safe, testable, scoped providers per tab |
| Routing | go_router | Declarative, deep-linkable, ShellRoute for tab bar |
| Local DB | SQLite + Drift | Type-safe ORM, reactive streams, migrations, in-memory test DB |
| AI runtime | llama.cpp / GGUF | On-device, offline, no cloud dependency |
| OCR | Google ML Kit | On-device, no network needed |
| Notifications | flutter_local_notifications | Local scheduling, fully offline |

### Backend

| Layer | Choice | Why |
|---|---|---|
| Framework | NestJS | Modular, TypeScript, good for REST |
| DB | PostgreSQL | Reliable, JSON support for metadata |
| Auth | JWT (access + refresh) + email OTP | Passwordless, low friction |
| Storage | Object storage (receipt uploads) | 90-day retention, signed URLs |
| Deploy | Docker on VPS/Hetzner | Cheap, simple, GitHub Actions CI |
| Monitoring | Sentry | Error grouping, perf |

---

## 5. Layered Architecture (Mobile)

```
┌─────────────────────────────────────────────────────────┐
│  PRESENTATION                                           │
│  Widgets · Screens · Sheets · go_router routes          │
│  Consumes Riverpod providers, renders design tokens     │
│  No direct DB access                                    │
├─────────────────────────────────────────────────────────┤
│  APPLICATION / STATE                                    │
│  Riverpod providers (scoped per tab)                    │
│  Loading/Error/Empty state machines                     │
│  Undo snackbar orchestration                            │
│  Sync status UI binding                                 │
├─────────────────────────────────────────────────────────┤
│  DOMAIN                                                 │
│  Entities (Transaction, Account, Budget, …)             │
│  Use cases: AddTransaction, EditTransaction,            │
│    CreateTransfer, RecalcBalance, ParseNL, RunOCR       │
│  Pure Dart, no Flutter/DB imports                       │
│  Balance edit rules, budget math, filter logic          │
├─────────────────────────────────────────────────────────┤
│  DATA                                                   │
│  Repositories (TransactionRepo, AccountRepo, …)         │
│  Drift DAOs, queries, streams                           │
│  SQLite transactions, balance updates                   │
│  Seed data, demo data loader                            │
├─────────────────────────────────────────────────────────┤
│  SYNC                                                   │
│  SyncManager (single-cycle lock, dedupe triggers)       │
│  Push/Pull clients, conflict applier                    │
│  Retry with exponential backoff                         │
│  sync_metadata key-value store                          │
├─────────────────────────────────────────────────────────┤
│  AI (optional)                                          │
│  NL parser (deterministic first, AI fallback)           │
│  OCR pipeline (ML Kit → extract → autofill)             │
│  Categorizer · ai_processing_logs audit trail           │
└─────────────────────────────────────────────────────────┘
```

**Dependency rule:** arrows point down. Presentation depends on Application; Application depends on Domain; Domain depends on nothing below it. Sync and AI are side-channels that read/write through the Data layer's repositories — they never bypass it.

---

## 6. Data Flow

### 6.1 Write path (local mutation)

```
User taps "Save" on transaction form
  │
  ▼
AddTransaction use case (Domain)
  │  validates, applies edit rules
  ▼
TransactionRepo.create() (Data)
  │
  ▼
Drift transaction {
    INSERT transactions (... sync_status='local_only')
    UPDATE accounts SET balance = balance ± amount
    UPDATE accounts SET sync_status='pending_sync'
  }
  │
  ├─▶ Stream emits new transaction row → provider rebuilds UI
  └─▶ Sync trigger debounced 30s (or fires on foreground)
```

Key points:
- Balance update and `sync_status` flip happen in **one SQLite transaction** so they can't drift apart.
- The UI updates from the local stream immediately — no await on network.
- Sync runs later as a background concern.

### 6.2 Read path

```
Widget build()
  │  ref.watch(transactionsProvider(filter))
  ▼
Provider (Application)
  │  delegates to repo
  ▼
TransactionRepo.watchFiltered() (Data)
  │  returns Stream<List<Transaction>>
  ▼
Drift .watch() query on SQLite
  │  indexed by account, category, payee, occurred_at, direction
  ▼
Local rows → entities → view models → widget
```

All reads are local. A dashboard with net worth, budgets, and recent transactions is a handful of indexed SQLite queries — sub-frame on any device.

### 6.3 Sync cycle

```
Trigger (foreground / 5min timer / reconnect / pull-to-refresh / post-mutation debounce)
  │
  ▼
ACQUIRE SYNC LOCK (one cycle at a time; extra triggers coalesce)
  │
  ├─ Not authenticated? ──▶ ABORT (V2 gate)
  ├─ Offline? ──▶ ABORT (reconnect trigger will retry)
  └─ Token expired? ──▶ refresh ──▶ fail ──▶ ABORT
  │
  ▼
PUSH PHASE
  │  collect sync_status IN (local_only, pending_sync, sync_failed)
  │  POST /sync/push  (batched by table)
  │  per record:
  │     applied  ──▶ sync_status='synced', last_synced_at=server_updated_at
  │     conflict ──▶ replace local with server_record, sync_status='synced'
  │     error    ──▶ sync_status='sync_failed', log
  │  (on network/5xx: mark all pushed as sync_failed, skip pull)
  ▼
PULL PHASE
  │  LOOP:
  │    POST /sync/pull { last_synced_at, cursor }
  │    for each server record:
  │       not local   ──▶ INSERT (sync_status='synced')
  │       server newer ──▶ UPDATE local
  │       local newer  ──▶ SKIP
  │    has_more=true ──▶ cursor=next_cursor, repeat
  │  store server_time as global last_synced_at
  ▼
POST-SYNC HOOKS
  │  rebuild account_balance_snapshots (if txns/transfers changed)
  │  reschedule notifications (if recurring/debts changed)
  │  refresh Riverpod providers
  ▼
RELEASE LOCK
```

### 6.4 AI-assisted entry flow

```
User types "mcdo 250 gcash"  (or 🎤 voice → transcribe)
  │
  ▼
Deterministic NL parser (regex + dictionary)
  │  extracts: amount=250, payee=mcdo, account=gcash
  ├─ success? ──▶ preview card
  └─ ambiguous? ──▶ AI fallback (llama.cpp) ──▶ preview card
  │
  ▼
User confirms → normal write path (6.1)
  │
  └─ ai_processing_logs row written (model, payload, confidence)
```

AI never writes to `transactions` directly. It only fills the form; the user taps Save.

---

## 7. Domain Decomposition

The 10 domains from `domain-model.md` map to tables, screens, and sync behavior:

| Domain | Local tables | Primary screens | Syncs? |
|---|---|---|---|
| Identity | users, households, household_members | Profile, Households | Yes |
| Accounts | accounts, account_balance_snapshots | Accounts list/detail, Dashboard | Yes (snapshots: no) |
| Transactions | transactions, transfers, categories, payees | Transactions, Add sheet, Detail | Yes |
| Budgeting | budgets | Budgets, Budget detail | Yes |
| Debt | debt_records | Debts, Debt detail | Yes |
| Goals | goals | Goals, Goal detail | Yes |
| Recurring | recurring_templates | Recurring, Recurring detail | Yes |
| Notifications | notifications | Notification settings | No (local) |
| AI Assistance | ai_processing_logs | AI settings, log | No (local) |
| Sync | sync_metadata | Sync status sheet | No (local) |

### Relationship core

```
users ─── household_members ─── households
  │                                  │
  ├── accounts ──── transactions     ├── accounts (shared)
  │              └── transfers       ├── budgets (shared)
  ├── budgets                        └── goals (shared)
  ├── debt_records
  ├── goals
  └── recurring_templates

transactions ─── categories
transactions ─── payees
transactions ─── transactions (parent_transaction_id, income deductions)
```

---

## 8. Key Architectural Decisions

| # | Decision | Rationale | Source |
|---|---|---|---|
| 1 | SQLite is the runtime source; backend is sync-only | Fast offline reads, simple server, privacy | product-strategy.md |
| 2 | Stored balances + transaction audit trail | Dashboard speed; recalculation is recovery only | domain-model.md |
| 3 | Transfers in a dedicated table (no transaction row) | Excluded from spending analytics cleanly | database-schema.md §1.1 |
| 4 | Income deductions via self-ref `parent_transaction_id` | No payroll engine; simple parent/child rows | database-schema.md §1.2 |
| 5 | Amounts stored as positive REAL; direction is a column | Simple aggregations (SUM + CASE) | database-schema.md §1.4 |
| 6 | 4 tabs + rightmost Add island (not centered FAB) | Add is always one tap; accent bg signals primary action | navigation-arch.md §2 |
| 7 | Single unified transaction list + Filter Sheet | Reduces tab clutter; filters compose with AND | navigation-arch.md §4 |
| 8 | NL quick add with mic toggle inside the field | Combines text + voice in one input; rapid entry | navigation-arch.md §2 |
| 9 | Save-first, no review queue, undo snackbar | Matches Monarch/Copilot; correction-friendly | domain-model.md §527 |
| 10 | Last-write-wins conflict resolution | Single-user primary; no CRDT complexity in V1 | sync-engine.md §7 |
| 11 | Global `last_synced_at` (not per-table) | Simpler; pull returns all tables in one response | sync-engine.md §4 |
| 12 | Cursor pagination on pull | Handles large initial sync without timeout | api-contracts.md §4.2 |
| 13 | Auth disabled in V1; sync infra built but gated | Ship local-only first; flip the switch in V2 | navigation-arch.md §7.6 |
| 14 | AI optional, on-device, never auto-mutates | Privacy + reliability; core works without AI | product-strategy.md |
| 15 | Color-only semantic feedback (green/amber/red) | Calm UX, no guilt language | design.md §1, navigation-arch.md §1 |
| 16 | Additive migrations, soft deletes | Safe schema evolution in V1 | database-schema.md §6.4 |

---

## 9. How the Specs Fit Together

```
                    ┌─────────────────┐
                    │ product-strategy│  vision, scope, stack
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
      ┌───────────────┐            ┌────────────────┐
      │ domain-model  │            │  design.md     │  tokens, components
      │ (entities)    │            └────────┬───────┘
      └───────┬───────┘                     │
              │                              │
   ┌──────────┴───────────┐                  │
   ▼                      ▼                  ▼
┌──────────────┐   ┌───────────────┐  ┌──────────────────┐
│database-     │   │navigation-arch│◄─┤  app-mockups.html│  visual reference
│schema        │   │ (50 screens)  │  └──────────────────┘
│(16 tables)   │   └───────┬───────┘
└──────┬───────┘           │
       │                   │
       ▼                   │
┌──────────────┐           │
│ sync-engine  │           │
│ (FSM, LWW)   │           │
└──────┬───────┘           │
       │                   │
       ▼                   │
┌──────────────┐           │
│ api-contracts│◄──────────┘  sync endpoints referenced by nav (sync UI)
│ (REST, JWT)  │
└──────────────┘
```

- **product-strategy.md** is the root — defines what and why.
- **domain-model.md** translates strategy into entities.
- **database-schema.md** is the local physical model derived from domain-model.
- **api-contracts.md** mirrors the syncable subset of the schema over HTTP.
- **sync-engine.md** defines how the two copies (local + server) converge.
- **navigation-arch.md** maps entities to screens and user flows.
- **design.md** defines how those screens look.
- **app-mockups.html** is the visual proof of design + navigation together.

This doc (solutions-arch.md) sits above all of them, showing how the layers connect.

---

## 10. Cross-Cutting Concerns

### 10.1 Sync status lifecycle

Every syncable row moves through: `local_only` → `pending_sync` → `synced`, with `sync_failed` as a retryable error state. Local mutations flip `synced` back to `pending_sync`. Soft-deleted rows stay `pending_sync` until the deletion is pushed, then are purged after 30 days.

### 10.2 Transaction atomicity

Balance updates and `sync_status` flips share one SQLite transaction. A transaction that affects an account balance updates both atomically — no half-applied state.

### 10.3 Error handling

| Layer | Strategy |
|---|---|
| UI | Empty / error / loading states per provider; undo snackbar on writes |
| Domain | Use cases return Result types; no exceptions for expected failures |
| Data | Drift errors surface as repo failures; DB never left inconsistent |
| Sync | Network/5xx → `sync_failed` + exponential backoff; 401 → refresh token; 422 → surface to user, no auto-retry |
| API | Consistent `{ error: { code, message, details } }` envelope; machine-readable codes |

### 10.4 Observability

- **Local:** `ai_processing_logs` (audit trail for AI), `sync_metadata` (sync health: last_synced_at, last_sync_status, sync_failed_count).
- **Backend:** Sentry for errors, structured logs for sync cycles.
- **UI:** Sync status icon in top bar (synced / pending / syncing / failed / offline) → tap for Sync Status sheet.

### 10.5 Security (spec pending — specs-backlog #6)

Known decisions so far:
- No bank credentials/tokens stored.
- JWT access (15min) + refresh (30d, rotated) in secure storage.
- Household roles: owner / member / viewer (viewer hides Add island + edit buttons).
- Local DB encryption, biometric lock — specified but not yet detailed (Phase 2 spec).

### 10.6 State management (spec pending — specs-backlog #5)

Known decisions so far:
- Riverpod, providers scoped per tab.
- Tab state (scroll position, filters) preserved across switches.
- Optimistic updates: write to DB → stream notifies providers → UI rebuilds.
- Sync state separate from local state (sync status is derived, not stored per-provider).

---

## 11. V1 vs V2 Boundary

What's **built but disabled** in V1 (infrastructure exists, gate is closed):

| Capability | V1 | V2 |
|---|---|---|
| Email OTP auth | Built, disabled | Enabled |
| Cloud sync (push/pull) | Engine built, no auth → never runs | Runs after login |
| Household sharing | Schema + routes exist | Activated with sync |
| Receipt uploads (backend) | Endpoint exists | Used with sync |
| Cloud push notifications | — | FCM |

This means the codebase carries sync code in V1 but it's inert. The Cloud Sync settings screen reads: "Cloud sync coming soon. Your data stays on your device." Flipping V2 on is an auth gate, not a rewrite.

---

## 12. Open Risks & Gaps

| Gap | Impact | Mitigation / Next spec |
|---|---|---|
| State management spec not written | Provider structure unformalized | specs-backlog #5 |
| Security model not written | Encryption, biometrics, permission enforcement undefined | specs-backlog #6 |
| `sync_metadata` table not yet in database-schema.md | Schema doc out of sync with sync-engine.md | Add as table #16 |
| `AGENTS.md` not written | Dev/agent conventions not captured | Write at repo root |
| LWW loses concurrent household edits | Same-budget edits on two devices: later wins, earlier lost | Acceptable V1; field-merge in future |
| AI model download size/UX | First-run friction | Onboarding opt-in + background download |
| Balance drift over time | Stored balances can desync from transaction history | Recalculation utility exists as recovery tool |

---

## 13. Status

| Spec | Status |
|---|---|
| product-strategy.md | Done |
| domain-model.md | Done |
| database-schema.md | Done (sync_metadata pending) |
| api-contracts.md | Done |
| sync-engine.md | Done |
| navigation-arch.md | Done |
| design.md | Done |
| app-mockups.html | Done |
| **solutions-arch.md** | **Done (this doc)** |
| state-management.md | Pending (Phase 2 #5) |
| security-model.md | Pending (Phase 2 #6) |
| notifications-arch.md | Pending (Phase 3 #8) |
| roadmap.md | Pending (Phase 3 #9) |
| testing-strategy.md | Pending (Phase 3 #10) |
| infrastructure.md | Pending (Phase 3 #11) |
| monetization.md | Pending (Phase 3 #12) |

Foundation phase is complete enough to begin coding the data + domain layers. State management and security specs should land before the presentation layer.

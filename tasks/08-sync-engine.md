# Task 08 — Application Layer — Sync Engine

**Status:** [ ]

---

## Objective

Implement the sync engine FSM described in `docs/sync-engine.md` and `docs/solutions-arch.md §6.3`. Push/pull over HTTP, LWW conflict resolution, retry with exponential backoff. All built but gated behind auth (dormant in V1).

References: `docs/sync-engine.md`, `docs/solutions-arch.md §6.3 §10.1 §11`, `docs/api-contracts.md`

## Dependencies

- 04 — Data Layer — Repositories
- 03 — Data Layer — Drift Schema & Database

## Deliverables

### 8.1 SyncManager (`lib/application/sync/sync_manager.dart`)

Core orchestrator. Single-cycle lock prevents concurrent syncs.

```
class SyncManager {
  Future<void> sync() async {
    if (!await _acquireLock()) return;
    try {
      if (!_isAuthenticated()) return; // V1 gate
      if (!await _isOnline()) return;
      await _refreshTokenIfNeeded();
      await _pushPhase();
      await _pullPhase();
      await _postSyncHooks();
    } finally {
      _releaseLock();
    }
  }
}
```

### 8.2 Trigger mechanism
Triggers that fire `SyncManager.sync()`:
- **Foreground** — app resumed, check if > 5 min since last sync
- **Timer** — background 5-minute periodic (when authenticated + online)
- **Reconnect** — connectivity restored
- **Pull-to-refresh** — user-triggered
- **Post-mutation** — debounced 30s after any write

All triggers coalesce: if a sync cycle is running, subsequent triggers are no-ops.

### 8.3 PushPhase (`lib/application/sync/push_client.dart`)
1. Query all rows WHERE `sync_status IN ('local_only', 'pending_sync', 'sync_failed')` AND `deleted_at IS NULL`
2. Also query soft-deleted rows: WHERE `deleted_at IS NOT NULL`
3. Batch by table, POST to `/sync/push`
4. Per record response:
   - `applied` → set `sync_status = 'synced'`, `last_synced_at = server_updated_at`
   - `conflict` → replace local row with server's version (LWW), `sync_status = 'synced'`
   - `error` → set `sync_status = 'sync_failed'`, log to sync_metadata
5. On network error / 5xx → mark all pushed records as `sync_failed`, abort pull phase

### 8.4 PullPhase (`lib/application/sync/pull_client.dart`)
1. POST `/sync/pull` with `{ last_synced_at, cursor }`
2. For each server record:
   - **Not local** → INSERT with `sync_status = 'synced'`
   - **Server newer** (`server.updated_at > local.updated_at`) → UPDATE local
   - **Local newer** → SKIP (will be pushed on next cycle)
3. If `response.has_more == true` → repeat with next cursor
4. Store server's `server_time` as global `last_synced_at` in `sync_metadata`
5. Handle deleted records: if server has `deleted_at` set and local doesn't → soft-delete local

### 8.5 ConflictApplier (`lib/application/sync/conflict_applier.dart`)
LWW: compare `updated_at` timestamps. Server wins ties.

### 8.6 PostSyncHooks
After push + pull complete:
1. Rebuild `account_balance_snapshots` for any accounts affected by new txns/transfers
2. Reschedule local notifications (recurring/debts may have changed)
3. Refresh all Riverpod providers (invalidate)

### 8.7 Retry with exponential backoff
- On `sync_failed`: wait 30s, 60s, 120s, 300s, 600s (max)
- On auth failure (401): refresh token, retry once. If still fails → abort.
- On 422 (validation): log error, do NOT retry (user must fix data).

### 8.8 Connectivity monitor
Wrap `connectivity_plus` to expose `Stream<bool>` (online/offline). Wire to sync trigger.

### 8.9 Sync metadata keys
| Key | Purpose |
|---|---|
| `last_synced_at` | Global cursor for pull requests |
| `last_sync_attempt_at` | When sync was last attempted |
| `last_sync_status` | `success`, `partial`, `failed` |
| `last_sync_error` | Error message from last failure |
| `sync_failed_count` | Number of records in `sync_failed` state |

## Acceptance Criteria

- [ ] `SyncManager.sync()` acquires lock, runs push→pull→hooks, releases lock
- [ ] Concurrent `sync()` calls coalesce (only one runs)
- [ ] Push phase correctly batches records by table
- [ ] Push responses update `sync_status` and `last_synced_at` per record
- [ ] Pull phase handles cursor pagination (loops until `has_more == false`)
- [ ] LWW: server record replaces local when `server.updated_at >= local.updated_at`
- [ ] Soft-deleted records are pushed and purged after 30 days
- [ ] Network failure marks records as `sync_failed` and aborts pull
- [ ] Exponential backoff retries at correct intervals
- [ ] 401 triggers token refresh + single retry
- [ ] 422 does not retry
- [ ] Post-sync hooks invalidate all affected providers
- [ ] Sync metadata table updated after each cycle
- [ ] V1 gate: sync returns early if auth not enabled
- [ ] Unit tests with mocked HTTP client and in-memory DB

## Files Likely Affected

- `lib/application/sync/sync_manager.dart` (new)
- `lib/application/sync/push_client.dart` (new)
- `lib/application/sync/pull_client.dart` (new)
- `lib/application/sync/conflict_applier.dart` (new)
- `lib/application/sync/sync_triggers.dart` (new)
- `lib/application/sync/connectivity_monitor.dart` (new)
- `lib/application/providers/sync_providers.dart` (extended — wire SyncManager to providers)
- `lib/data/repositories/sync_metadata_repo.dart` (extended — may need additional operations)
- `test/application/sync/` (new)

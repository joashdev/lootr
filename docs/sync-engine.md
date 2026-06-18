# Sync Engine Design — Personal Finance App

How the local SQLite database and the NestJS backend stay in sync.

References: `product-strategy.md` (sync architecture), `database-schema.md` (sync fields, syncable tables), `api-contracts.md` (sync endpoints).

---

## 1. Overview

The app is **local-first**. The local SQLite database is the primary runtime source — all reads and writes happen locally. Sync with the backend is an optional background process that:

- Pushes local changes to the server (for backup and multi-device access)
- Pulls server changes to the local DB (for household sharing and multi-device updates)

Sync does NOT block the UI. If sync fails, the app continues to work fully offline. Sync runs over HTTP (no WebSockets in V1).

### Design constraints

- No real-time collaboration (V1 scope exclusion)
- No operational transforms or CRDTs — conflict resolution is last-write-wins
- Sync is opt-in — only runs after user authenticates via email OTP

---

## 2. Sync Triggers

Sync is triggered by the following events. Multiple triggers may fire — the sync manager deduplicates and runs at most one sync cycle at a time.

| Trigger | When | Debounce |
|---|---|---|
| App foreground | App returns to foreground from background | Immediate |
| Post-mutation | Any local write to a syncable table | 30 seconds after last mutation |
| Periodic timer | App is in foreground | Every 5 minutes |
| Network reconnect | Device regains connectivity after being offline | Immediate (after 5s delay to stabilize) |
| Manual refresh | User pulls to refresh on dashboard or transactions screen | Immediate |

### Trigger behavior

- If a sync cycle is already running, new triggers are coalesced — one additional cycle runs after the current one completes.
- If no auth token is present, all triggers are ignored.
- If the device is offline, triggers are queued and fire on network reconnect.

---

## 3. Sync State Machine

Each syncable record has a `sync_status` field that tracks its sync state.

### States

| State | Meaning |
|---|---|
| `local_only` | Created locally, never sent to server |
| `pending_sync` | Modified locally since last successful sync |
| `synced` | In sync with server |
| `sync_failed` | Last push attempt failed; awaiting retry |

### Transitions

```
                    ┌──────────────────────────────────────────┐
                    │                                          │
                    ▼                                          │
NEW RECORD ──▶ local_only ──▶ pending_sync ──▶ synced         │
                    │                │              │          │
                    │                │              │ LOCAL    │
                    │                │              │ MUTATION │
                    │                ▼              └──────────┘
                    │          sync_failed               │
                    │                │                   │
                    │                │ RETRY             │
                    │                ▼                   │
                    └─────────▶ pending_sync ◀───────────┘
                                     │
                                     │ PUSH SUCCESS
                                     ▼
                                  synced
```

| From | To | Trigger |
|---|---|---|
| (new record) | `local_only` | Local INSERT |
| `local_only` | `pending_sync` | Sync cycle starts (about to push) |
| `pending_sync` | `synced` | Push succeeded |
| `pending_sync` | `sync_failed` | Push failed (network error, server error) |
| `sync_failed` | `pending_sync` | Retry timer fires |
| `synced` | `pending_sync` | Local mutation (INSERT, UPDATE, or DELETE on this record) |

### Notes

- `local_only` and `pending_sync` are treated identically by the push flow — both are sent to the server. The distinction is for client-side observability (has this record ever synced?).
- Pull does NOT change `sync_status`. Pull updates local records from the server, but the sync_status of pulled records is set to `synced` (they came from the server, so they're in sync).
- Soft-deleted records (with `deleted_at` set) remain in `pending_sync` until the deletion is pushed to the server. After successful push, they can be purged from the local DB (configurable retention).

---

## 4. Sync Cycle

A sync cycle is a single push-then-pull sequence. Only one cycle runs at a time.

### Sequence

```
1. ACQUIRE SYNC LOCK
   └─ If already running, skip (trigger will queue another cycle)

2. CHECK PRECONDITIONS
   ├─ Is user authenticated? ── No ──▶ ABORT
   ├─ Is network available?   ── No ──▶ ABORT (triggers will retry on reconnect)
   └─ Is access token valid?  ── No ──▶ REFRESH TOKEN ── fail ──▶ ABORT

3. PUSH PHASE
   ├─ Query all records where sync_status IN ('local_only', 'pending_sync', 'sync_failed')
   ├─ Group by table
   ├─ POST /sync/push with batched changes
   ├─ Process response:
   │   ├─ status = "applied"  ──▶ set sync_status = 'synced', last_synced_at = server_updated_at
   │   ├─ status = "conflict" ──▶ replace local record with server_record, set sync_status = 'synced'
   │   └─ status = "error"    ──▶ set sync_status = 'sync_failed', log error
   └─ If push request fails (network/5xx) ──▶ set ALL pushed records to 'sync_failed', skip pull

4. PULL PHASE
   ├─ Read last_synced_at from sync metadata (per-table or global — see below)
   ├─ POST /sync/pull with last_synced_at + cursor
   ├─ For each record in response:
   │   ├─ If record exists locally and incoming updated_at > local updated_at ──▶ UPDATE local record
   │   ├─ If record doesn't exist locally ──▶ INSERT
   │   ├─ If record exists locally but incoming updated_at <= local updated_at ──▶ SKIP (local is newer)
   │   └─ Set sync_status = 'synced', last_synced_at = server updated_at for this record
   ├─ If has_more = true ──▶ repeat pull with next_cursor
   └─ After all pages: store server_time as the new last_synced_at

5. POST-SYNC HOOKS
   ├─ Rebuild account_balance_snapshots if any transactions/transfers changed
   ├─ Reschedule notifications if recurring_templates or debt_records changed
   └─ Update UI providers (Riverpod) to reflect synced data

6. RELEASE SYNC LOCK
```

### last_synced_at: global vs per-table

A single **global** `last_synced_at` timestamp is used for the pull phase. This is stored in a local `sync_metadata` key-value table:

| Key | Value |
|---|---|
| `last_synced_at` | ISO 8601 timestamp from server's `server_time` |

This is simpler than per-table timestamps and works because the pull endpoint returns changes across all tables in a single response. The global timestamp is only updated after ALL pages have been pulled successfully.

---

## 5. Push Flow Detail

### Batch construction

- Collect all records with `sync_status` IN (`local_only`, `pending_sync`, `sync_failed`)
- Group by table name
- If total records exceed a threshold (e.g., 500), split into multiple push requests by table
- Each record includes all columns EXCEPT `sync_status` and `last_synced_at` (client-only fields)

### Handling push response

For each record in the response:

| Response status | Client action |
|---|---|
| `applied` | UPDATE local SET sync_status = 'synced', last_synced_at = server_updated_at WHERE id = ? |
| `conflict` | UPDATE local SET [all fields] = server_record values, sync_status = 'synced' WHERE id = ? |
| `error` | UPDATE local SET sync_status = 'sync_failed' WHERE id = ?; log error details |

### Push failure (network/5xx)

If the push HTTP request itself fails (timeout, network error, 5xx):

- Set ALL records that were in the push batch back to `sync_failed`
- Do NOT proceed to pull phase
- Schedule retry with exponential backoff

---

## 6. Pull Flow Detail

### Pagination

Pull uses cursor-based pagination to handle large datasets:

```
LOOP:
  POST /sync/pull { last_synced_at, cursor }
  APPLY changes to local DB
  IF has_more = true:
    cursor = next_cursor
    CONTINUE
  ELSE:
    last_synced_at = server_time
    BREAK
```

### Applying pulled records

For each incoming server record:

1. Query local DB for record by `id`
2. If NOT found locally:
   - INSERT the record with `sync_status = 'synced'`
3. If found locally:
   - Compare `updated_at`: if server's `updated_at` > local `updated_at`, overwrite local record
   - If server's `updated_at` <= local `updated_at`, skip (local is newer or equal)
   - This handles the edge case where a push in the same cycle updated the record, and the pull returns the same version
4. Set `sync_status = 'synced'` and `last_synced_at = server record's updated_at` for applied records

### Soft delete propagation

- Server returns records with `deleted_at` set
- Client applies the `deleted_at` locally
- Records with `deleted_at` set are filtered out of normal queries (WHERE deleted_at IS NULL)
- Periodically (e.g., every 30 days), locally purge records where `deleted_at` is older than 30 days AND `sync_status = 'synced'`

---

## 7. Conflict Resolution

### Strategy: Last-Write-Wins (LWW) by `updated_at`

This is the simplest conflict resolution strategy and is appropriate for V1 because:

- The app is primarily single-user (household sharing is secondary)
- Most conflicts will be the same user editing on two devices — LWW picks the most recent edit
- No financial calculations happen on the server, so conflicts don't risk data corruption

### How it works

**During push:**

1. Client sends record with its local `updated_at`
2. Server compares incoming `updated_at` vs stored `updated_at`
3. If incoming > stored: server accepts, stores, returns `status = "applied"`
4. If incoming <= stored: server rejects, returns `status = "conflict"` + the server's record
5. Client replaces its local copy with the server's version

**During pull:**

1. Server returns records updated since `last_synced_at`
2. Client compares incoming `updated_at` vs local `updated_at`
3. If incoming > local: overwrite local
4. If incoming <= local: skip (local is newer — this can happen if a local mutation occurred during the sync cycle)

### Limitations of LWW

- If two users edit the same household budget simultaneously, the later edit wins and the earlier edit is lost
- No merge — field-level conflicts are not detected; the entire record is replaced
- Acceptable for V1. Future versions could add field-level merge for specific entities (e.g., budgets)

---

## 8. Initial Sync (Cold Start)

When a user authenticates for the first time on a new device (or after a local DB reset):

1. Local DB may already contain local-only data (if user used the app before authenticating)
2. Run a normal sync cycle:
   - **Push** sends local-only records to the server
   - **Pull** with `last_synced_at = null` retrieves ALL server records
3. Pull handles the large initial dataset via pagination (see §6)
4. After initial sync completes, `last_synced_at` is set to the server's current time

### Edge case: existing server data, new local data

If the user has data on the server (from another device) AND local-only data on this device:

1. Push phase sends local-only records (they get `applied` or `conflict`)
2. Pull phase receives all server records (including the ones just pushed)
3. For records just pushed: server's `updated_at` equals local `updated_at` (or is very close) — pull skips them (incoming <= local)
4. For server-only records: pull inserts them locally

This works correctly because push runs before pull.

---

## 9. Error Handling & Retry

### Retry strategy for `sync_failed` records

Records that fail to sync are retried with exponential backoff:

| Retry attempt | Delay |
|---|---|
| 1 | 30 seconds |
| 2 | 1 minute |
| 3 | 2 minutes |
| 4 | 5 minutes |
| 5 | 15 minutes |
| 6+ | 30 minutes (max) |

- Retry delay is measured from the last failed attempt, not from the original failure
- Retries are piggybacked onto normal sync cycles — if a sync trigger fires, `sync_failed` records are included in the push batch
- If a record fails 10 times, it stays in `sync_failed` and is surfaced to the user as a sync error (with a manual "retry" button)

### Error categories

| Error type | Action |
|---|---|
| Network timeout / no connectivity | Set records to `sync_failed`, retry with backoff |
| 401 Unauthorized | Attempt token refresh; if refresh fails, pause sync and prompt re-auth |
| 429 Rate limited | Wait for `retry_after` from response, then retry |
| 500 Server error | Set records to `sync_failed`, retry with backoff |
| 422 Validation error (server rejects record) | Set to `sync_failed`, do NOT retry automatically — requires user intervention |

### Sync health tracking

A `sync_metadata` key-value table stores sync health:

| Key | Value | Notes |
|---|---|---|
| `last_synced_at` | ISO 8601 | Last successful pull timestamp |
| `last_sync_attempt_at` | ISO 8601 | Last sync cycle start |
| `last_sync_status` | `success` / `partial` / `failed` | Overall status of last cycle |
| `last_sync_error` | string | Error message if last sync failed |
| `sync_failed_count` | integer | Number of records currently in `sync_failed` |

This powers the sync status indicator in the UI.

---

## 10. Local `sync_metadata` Table

A simple key-value table for sync bookkeeping. NOT syncable — local only.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| key | TEXT | PK | e.g. `last_synced_at` |
| value | TEXT | NOT NULL | Serialized value (string, number, etc.) |

This table was not in the original `database-schema.md` and should be added as table #16 (local-only).

---

## 11. Sync & Local Mutations

### How local mutations interact with sync

| Local operation | sync_status change | Notes |
|---|---|---|
| INSERT new record | → `local_only` | New record, never synced |
| UPDATE existing synced record | → `pending_sync` | Was synced, now modified |
| UPDATE existing pending record | stays `pending_sync` | Already pending, no change |
| Soft-delete (set deleted_at) | → `pending_sync` | Deletion must propagate to server |
| Hard-delete (physical delete) | N/A | Avoid in V1 — use soft delete |

### Transaction atomicity

Local mutations and sync_status updates should be in the same SQLite transaction. For example, when creating a transaction:

```sql
BEGIN TRANSACTION;
  INSERT INTO transactions (id, ..., sync_status, ...) VALUES (?, ..., 'local_only', ...);
  UPDATE accounts SET balance = balance - ? WHERE id = ?;
  UPDATE accounts SET sync_status = 'pending_sync' WHERE id = ?;
COMMIT;
```

This ensures that if a transaction affects an account's balance, both the transaction and the account's `sync_status` are updated atomically.

---

## 12. Summary: What Syncs and What Doesn't

| Table | Syncs? | Notes |
|---|---|---|
| users | Yes | |
| households | Yes | |
| household_members | Yes | |
| accounts | Yes | |
| transactions | Yes | |
| transfers | Yes | |
| categories | Yes | Seed data starts as `synced` |
| payees | Yes | |
| budgets | Yes | |
| debt_records | Yes | |
| goals | Yes | |
| recurring_templates | Yes | |
| account_balance_snapshots | No | Derived locally, rebuilt from transactions |
| notifications | No | Local scheduling only |
| ai_processing_logs | No | Local audit trail |
| sync_metadata | No | Sync bookkeeping (this spec) |

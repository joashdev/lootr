# Task 22 — Backend — Sync Endpoints

**Status:** [ ]

---

## Objective

Implement the sync push/pull endpoints, file upload for receipts, and household management endpoints. The backend validates and stores rows — it never computes balances.

References: `docs/api-contracts.md` §3-4, `docs/sync-engine.md`, `docs/solutions-arch.md` §2 §6.3

## Dependencies

- 21 — Backend — NestJS Setup & Auth

## Deliverables

### 22.1 Sync module (`backend/src/sync/`)

**Endpoints:**

`POST /sync/push`
- Auth: required (JWT)
- Body: `{ records: { users: [...], transactions: [...], ... }, device_id: "..." }`
- For each record:
  - If `deleted_at` is set → soft-delete server row
  - If exists and `client.updated_at > server.updated_at` → update row
  - If exists and `client.updated_at <= server.updated_at` → return `conflict` with server version
  - If not exists → insert
- Response: `{ results: { users: [{id, status: "applied"|"conflict", server_updated_at}], ... } }`
- All in one PostgreSQL transaction per table batch

`POST /sync/pull`
- Auth: required (JWT)
- Body: `{ last_synced_at: "ISO8601", cursor: "opaque", limit: 500 }`
- Query: all rows WHERE `updated_at > last_synced_at`, ordered by `updated_at ASC, id ASC`
- Cursor pagination: encode last `(updated_at, id)` as opaque token
- Response: `{ records: { users: [...], transactions: [...], ... }, has_more: bool, next_cursor: "opaque", server_time: "ISO8601" }`
- Includes soft-deleted rows (with `deleted_at` set) for tombstoning

### 22.2 Household endpoints

`POST /households`
- Create household, auto-add creator as member with role `owner`

`POST /households/:id/members`
- Add member by user ID or email
- Validate user exists

`PATCH /households/:id/members/:memberId`
- Update role (owner/member/viewer)

`DELETE /households/:id/members/:memberId`
- Remove member

`GET /households/:id`
- Get household with members list

### 22.3 Receipt upload endpoint

`POST /uploads/receipt`
- Auth: required (JWT)
- Body: multipart form data with image file
- Generate unique filename: `{user_id}/{uuid}.{ext}`
- Upload to object storage (S3-compatible or local disk in dev)
- Return signed URL (90-day expiry) with public URL
- Store metadata in `receipt_uploads` table: id, user_id, file_path, original_filename, content_type, size, uploaded_at, expires_at

`GET /uploads/receipt/:id`
- Return signed download URL

### 22.4 Sync validation middleware
- Validate request body shape (Zod or class-validator)
- Reject unknown fields
- Validate UUID v4 format on all IDs
- Validate sync_status values are valid enum members
- Return 422 with field-level errors on validation failure

### 22.5 Rate limiting (sync-specific)
- `/sync/push`: 30 requests per minute per user
- `/sync/pull`: 30 requests per minute per user
- `/uploads/receipt`: 10 uploads per hour per user

### 22.6 DB indexes for sync performance
- Composite index on `(updated_at, id)` for cursor pagination
- Index on `user_id` for household ownership queries
- Index on `email` for user search

## Acceptance Criteria

- [ ] `POST /sync/push` correctly inserts new rows and updates existing ones
- [ ] LWW: client wins when `client.updated_at > server.updated_at`
- [ ] Conflict: server returns its version when `client.updated_at <= server.updated_at`
- [ ] Soft-deleted rows are tombstoned on the server
- [ ] Push batch is atomic per table (all or none)
- [ ] `POST /sync/pull` returns rows updated after `last_synced_at`
- [ ] Cursor pagination works correctly (no gaps, no duplicates)
- [ ] `has_more` flag and `next_cursor` enable proper pagination loop
- [ ] Deleted rows are included in pull response (with `deleted_at`)
- [ ] Household CRUD endpoints work with correct permission checks
- [ ] Receipt upload returns signed URL with 90-day expiry
- [ ] Validation middleware rejects malformed requests with 422
- [ ] Rate limiting applies to sync endpoints
- [ ] All sync endpoints return consistent error format

## Files Likely Affected

- `backend/src/sync/sync.module.ts` (new)
- `backend/src/sync/sync.controller.ts` (new)
- `backend/src/sync/sync.service.ts` (new)
- `backend/src/sync/dto/push.dto.ts` (new)
- `backend/src/sync/dto/pull.dto.ts` (new)
- `backend/src/households/` (new)
- `backend/src/uploads/` (new)
- `backend/src/common/validation/` (new)
- `backend/src/common/guards/` (extended)
- `backend/src/database/migrations/` (extended)
- `test/sync/` (new)

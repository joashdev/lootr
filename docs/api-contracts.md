# API Contracts — Personal Finance App

REST API contract between the Flutter mobile app and the NestJS backend.

References: `product-strategy.md` (backend section), `database-schema.md` (entity shapes).

---

## 1. Overview

The backend is a **sync/backup layer only**. It does NOT compute balances, dashboards, analytics, or budget summaries — those are computed locally on-device. The API handles:

- Authentication (passwordless email OTP)
- User profile
- User search (for household invites)
- Sync (push local changes, pull server changes)
- File uploads (receipt images)

| Property | Value |
|---|---|
| Base URL | `https://api.{domain}/v1` |
| Content type | `application/json` (except uploads: `multipart/form-data`) |
| Auth scheme | Bearer JWT |
| Date format | ISO 8601, UTC |

---

## 2. Authentication

Auth does NOT block app usage. Users can operate fully offline without an account. Cloud auth is opt-in for sync/backups.

### Flow

1. Client sends email → server sends 6-digit OTP
2. Client verifies OTP → server returns access + refresh tokens
3. Client includes access token in `Authorization` header for all requests
4. Access token expires → client uses refresh token to get new pair

### Tokens

| Token | TTL | Storage |
|---|---|---|
| Access token | 15 minutes | Secure storage (Flutter secure storage) |
| Refresh token | 30 days | Secure storage, rotated on each refresh |

---

### 2.1 POST /auth/request-otp

Request an OTP code to be sent to the email.

**Request:**
```json
{
  "email": "user@example.com"
}
```

**Response — 200 OK:**
```json
{
  "expires_in": 300
}
```

**Errors:**

| Status | Code | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Invalid email format |
| 429 | `RATE_LIMITED` | Too many OTP requests |

---

### 2.2 POST /auth/verify-otp

Verify the OTP and receive tokens.

**Request:**
```json
{
  "email": "user@example.com",
  "code": "123456"
}
```

**Response — 200 OK:**
```json
{
  "access_token": "eyJhbGci...",
  "refresh_token": "eyJhbGci...",
  "expires_in": 900,
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "display_name": null,
    "currency_code": "PHP",
    "locale": null,
    "timezone": null,
    "ai_enabled": false,
    "created_at": "2026-06-17T22:00:00Z",
    "updated_at": "2026-06-17T22:00:00Z"
  }
}
```

If the email is new, a user record is auto-created. If existing, the user record is returned.

**Errors:**

| Status | Code | When |
|---|---|---|
| 400 | `INVALID_OTP` | Wrong code |
| 410 | `OTP_EXPIRED` | Code has expired |
| 429 | `RATE_LIMITED` | Too many verification attempts |

---

### 2.3 POST /auth/refresh

Exchange a refresh token for a new token pair.

**Request:**
```json
{
  "refresh_token": "eyJhbGci..."
}
```

**Response — 200 OK:**
```json
{
  "access_token": "eyJhbGci...",
  "refresh_token": "eyJhbGci...",
  "expires_in": 900
}
```

**Errors:**

| Status | Code | When |
|---|---|---|
| 401 | `INVALID_TOKEN` | Refresh token is invalid or expired |

---

### 2.4 POST /auth/logout

Revoke the current session and invalidate tokens.

**Headers:** `Authorization: Bearer {access_token}`

**Response — 204 No Content**

---

## 3. User Endpoints

### 3.1 GET /me

Get the authenticated user's profile.

**Response — 200 OK:**
```json
{
  "user": {
    "id": "550e8400-...",
    "email": "user@example.com",
    "display_name": "Joash",
    "currency_code": "PHP",
    "locale": "en-PH",
    "timezone": "Asia/Manila",
    "ai_enabled": true,
    "created_at": "2026-06-17T22:00:00Z",
    "updated_at": "2026-06-17T22:00:00Z"
  }
}
```

---

### 3.2 PUT /me

Update the authenticated user's profile.

**Request:**
```json
{
  "display_name": "Joash",
  "currency_code": "PHP",
  "locale": "en-PH",
  "timezone": "Asia/Manila",
  "ai_enabled": true
}
```

All fields optional. Only provided fields are updated.

**Response — 200 OK:** Same shape as GET /me.

---

### 3.3 GET /users/search

Search users by email. Used for household member invites.

**Query params:** `?email=user@example.com`

**Response — 200 OK:**
```json
{
  "users": [
    {
      "id": "550e8400-...",
      "email": "user@example.com",
      "display_name": "Joash"
    }
  ]
}
```

Returns at most 10 results. Only returns users who exist on the server (have completed OTP auth).

**Errors:**

| Status | Code | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Missing email param |

---

## 4. Sync Endpoints

Sync is the core of the backend. All 12 syncable tables (see `database-schema.md` §3) are synced via two endpoints: push and pull.

### Principles

- **Push first, then pull** — minimizes conflicts
- **Server is authoritative** for conflict resolution (last-write-wins by `updated_at`)
- **Soft deletes sync** — records with `deleted_at` set are pushed/pulled so deletions propagate
- **No per-entity CRUD endpoints** — all data flows through sync

---

### 4.1 POST /sync/push

Send local changes to the server. Client sends all records with `sync_status` of `local_only`, `pending_sync`, or `sync_failed`.

**Request:**
```json
{
  "changes": {
    "users": [
      {
        "id": "550e8400-...",
        "email": "user@example.com",
        "display_name": "Joash",
        "currency_code": "PHP",
        "locale": "en-PH",
        "timezone": "Asia/Manila",
        "ai_enabled": true,
        "created_at": "2026-06-17T22:00:00Z",
        "updated_at": "2026-06-17T22:30:00Z",
        "deleted_at": null
      }
    ],
    "accounts": [
      {
        "id": "660e8400-...",
        "household_id": null,
        "owner_user_id": "550e8400-...",
        "name": "GCash",
        "account_type": "ewallet",
        "balance": 5000.00,
        "currency_code": "PHP",
        "is_archived": false,
        "is_hidden": false,
        "created_at": "2026-06-17T22:00:00Z",
        "updated_at": "2026-06-17T22:30:00Z",
        "deleted_at": null
      }
    ],
    "transactions": [],
    "transfers": [],
    "categories": [],
    "payees": [],
    "budgets": [],
    "debt_records": [],
    "goals": [],
    "recurring_templates": [],
    "households": [],
    "household_members": []
  }
}
```

Only include tables that have changes. Empty arrays can be omitted.

**Response — 200 OK:**
```json
{
  "results": {
    "users": [
      {
        "id": "550e8400-...",
        "status": "applied",
        "server_updated_at": "2026-06-17T22:30:00Z"
      }
    ],
    "accounts": [
      {
        "id": "660e8400-...",
        "status": "applied",
        "server_updated_at": "2026-06-17T22:30:00Z"
      }
    ]
  }
}
```

**Per-record status values:**

| Status | Meaning | Client action |
|---|---|---|
| `applied` | Server accepted the record | Set `sync_status = 'synced'`, `last_synced_at = server_updated_at` |
| `conflict` | Server has a newer version | Replace local record with `server_record`, set `sync_status = 'synced'` |
| `error` | Server rejected (validation/permission) | Keep as `sync_failed`, log error |

**Conflict response shape:**
```json
{
  "id": "660e8400-...",
  "status": "conflict",
  "server_record": {
    "id": "660e8400-...",
    "name": "GCash Wallet",
    "balance": 4500.00,
    "updated_at": "2026-06-17T22:35:00Z",
    "...": "full record from server"
  }
}
```

---

### 4.2 POST /sync/pull

Get server changes since the last sync. Returns all records updated after `last_synced_at`.

**Request:**
```json
{
  "last_synced_at": "2026-06-17T22:00:00Z",
  "limit": 200,
  "cursor": null
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `last_synced_at` | string (ISO 8601) | Yes | Server time from previous successful pull. `null` for initial sync. |
| `limit` | integer | No | Max records per table. Default 200, max 500. |
| `cursor` | string | No | Opaque pagination cursor from previous pull response. |

**Response — 200 OK:**
```json
{
  "server_time": "2026-06-17T22:34:00Z",
  "changes": {
    "users": [],
    "households": [],
    "household_members": [],
    "accounts": [
      {
        "id": "660e8400-...",
        "household_id": null,
        "owner_user_id": "550e8400-...",
        "name": "GCash Wallet",
        "account_type": "ewallet",
        "balance": 4500.00,
        "currency_code": "PHP",
        "is_archived": false,
        "is_hidden": false,
        "created_at": "2026-06-17T22:00:00Z",
        "updated_at": "2026-06-17T22:35:00Z",
        "deleted_at": null
      }
    ],
    "transactions": [],
    "transfers": [],
    "categories": [],
    "payees": [],
    "budgets": [],
    "debt_records": [],
    "goals": [],
    "recurring_templates": []
  },
  "has_more": false,
  "next_cursor": null
}
```

**Pagination:**

- If `has_more` is `true`, call pull again with `cursor = next_cursor`.
- Repeat until `has_more` is `false`.
- Store `server_time` as the new `last_synced_at` ONLY after all pages are pulled.
- All tables are paginated independently — `has_more` is true if ANY table has more records.

---

## 5. File Upload Endpoints

### 5.1 POST /uploads

Upload a file (receipt image, etc.). Returns a URL for storage.

**Request:** `multipart/form-data`

| Field | Type | Notes |
|---|---|---|
| `file` | binary | The file to upload |
| `related_entity_id` | string (UUID) | Optional. Transaction or debt ID this file relates to. |

**Response — 201 Created:**
```json
{
  "id": "770e8400-...",
  "url": "https://storage.{domain}/uploads/770e8400-...",
  "size": 245678,
  "content_type": "image/jpeg"
}
```

**Constraints:**

| Property | Limit |
|---|---|
| Max file size | 10 MB |
| Allowed types | `image/jpeg`, `image/png`, `image/webp`, `application/pdf` |
| Retention | 90 days (configurable) |

---

### 5.2 GET /uploads/{id}

Download a file.

**Response — 200 OK:** File binary with appropriate `Content-Type`.

**Errors:**

| Status | Code | When |
|---|---|---|
| 404 | `NOT_FOUND` | File doesn't exist or has expired |

---

## 6. Error Format

All errors return a consistent JSON shape:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Email format is invalid",
    "details": {
      "field": "email",
      "issue": "must be a valid email address"
    }
  }
}
```

| Field | Type | Notes |
|---|---|---|
| `code` | string | Machine-readable error code (see below) |
| `message` | string | Human-readable error message |
| `details` | object | Optional. Field-level validation details. |

---

## 7. Error Codes

| HTTP Status | Code | When |
|---|---|---|
| 400 | `BAD_REQUEST` | Malformed request body |
| 400 | `VALIDATION_ERROR` | Request fails validation |
| 400 | `INVALID_OTP` | Wrong OTP code |
| 401 | `UNAUTHORIZED` | Missing or invalid access token |
| 401 | `INVALID_TOKEN` | Refresh token is invalid or expired |
| 403 | `FORBIDDEN` | Authenticated but not permitted (e.g. household role) |
| 404 | `NOT_FOUND` | Resource doesn't exist |
| 410 | `OTP_EXPIRED` | OTP code has expired |
| 422 | `UNPROCESSABLE_ENTITY` | Semantically invalid (e.g. duplicate payee) |
| 429 | `RATE_LIMITED` | Too many requests |
| 500 | `INTERNAL_ERROR` | Server error |

---

## 8. Rate Limiting

Rate limits are per-user (authenticated) or per-IP (unauthenticated).

| Endpoint group | Limit | Window |
|---|---|---|
| `/auth/request-otp` | 3 per email, 5 per IP | 1 minute |
| `/auth/verify-otp` | 5 per email | 1 minute |
| `/auth/refresh` | 10 per user | 1 minute |
| `/sync/push` | 30 per user | 1 minute |
| `/sync/pull` | 30 per user | 1 minute |
| `/uploads` (POST) | 10 per user | 1 minute |
| All other endpoints | 100 per user | 1 minute |

**Rate limit headers:**

| Header | Meaning |
|---|---|
| `X-RateLimit-Limit` | Max requests in window |
| `X-RateLimit-Remaining` | Remaining requests in window |
| `X-RateLimit-Reset` | Unix timestamp when window resets |

When rate limited, response includes:

```json
{
  "error": {
    "code": "RATE_LIMITED",
    "message": "Too many requests. Try again in 42 seconds.",
    "details": {
      "retry_after": 42
    }
  }
}
```

---

## 9. Entity Response Shapes

All syncable entities use the same JSON shape as their database columns (see `database-schema.md` §3). Key conventions:

| Convention | JSON representation |
|---|---|
| UUID | string |
| Timestamps | ISO 8601 string, UTC (`"2026-06-17T22:00:00Z"`) |
| Booleans | `true` / `false` |
| Nullable fields | `null` (not omitted) |
| Amounts | number (float) |
| JSON metadata | nested object |
| Soft-deleted records | included with `deleted_at` set to ISO 8601 string |

### Syncable entity list

| Table | Syncable? |
|---|---|
| `users` | Yes |
| `households` | Yes |
| `household_members` | Yes |
| `accounts` | Yes |
| `transactions` | Yes |
| `transfers` | Yes |
| `categories` | Yes |
| `payees` | Yes |
| `budgets` | Yes |
| `debt_records` | Yes |
| `goals` | Yes |
| `recurring_templates` | Yes |
| `account_balance_snapshots` | No (local-only, derived) |
| `notifications` | No (local-only) |
| `ai_processing_logs` | No (local-only) |

### Fields excluded from API responses

The following columns are local-only and NEVER sent to or returned from the server:

| Column | Reason |
|---|---|
| `sync_status` | Client-side state only |
| `last_synced_at` | Client-side state only |

The server manages these internally:
- `created_at` — set by server on first push, preserved on updates
- `updated_at` — set by server on each accepted change
- `deleted_at` — set by client, accepted by server

---

## 10. Sync Exclusions

The server does NOT receive or store:

- `account_balance_snapshots` — derived locally from transactions
- `notifications` — scheduled and consumed locally
- `ai_processing_logs` — local audit trail only

These tables exist only in the local SQLite database.

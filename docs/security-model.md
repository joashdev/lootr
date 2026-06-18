# Security Model — Personal Finance App

Data at rest, in transit, auth boundaries, and permission enforcement for the Flutter app.

References: `product-strategy.md` (privacy-first, no bank credentials), `api-contracts.md` (JWT, OTP, rate limiting), `sync-engine.md` (push/pull auth gates, token refresh), `navigation-arch.md` (household UX, security settings screen), `database-schema.md` (local-only tables, soft delete), `state-management.md` (auth provider, secure token storage), `solutions-arch.md` (§10.5).

---

## 1. Overview

The security model is built on a **defense-in-depth** approach across five layers:

```
┌─────────────────────────────────────────────────────────────────────┐
│  LAYER 5 — SERVER                                                    │
│  PostgreSQL · OTP-only (no passwords) · rate limits · RBAC           │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │  LAYER 4 — TRANSPORT                                             │ │
│  │  TLS 1.2+ · Bearer JWT · HTTPS only · no bank credentials         │ │
│  │  ┌─────────────────────────────────────────────────────────────┐ │ │
│  │  │  LAYER 3 — DATA AT REST                                      │ │ │
│  │  │  SQLCipher AES-256 · encryption key in platform keystore     │ │ │
│  │  │  Soft deletes (never physically destroyed without purge)     │ │ │
│  │  │  ┌─────────────────────────────────────────────────────────┐ │ │ │
│  │  │  │  LAYER 2 — APP GATE                                      │ │ │ │
│  │  │  │  Biometric lock · optional PIN fallback · auto-lock      │ │ │ │
│  │  │  │  Flutter secure storage for tokens                       │ │ │ │
│  │  │  │  ┌─────────────────────────────────────────────────────┐ │ │ │ │
│  │  │  │  │  LAYER 1 — DEVICE                                    │ │ │ │ │
│  │  │  │  │  Face ID / Fingerprint · Secure Enclave / TEE        │ │ │ │ │
│  │  │  │  │  Keychain (iOS) / Keystore (Android)                │ │ │ │ │
│  │  │  │  └─────────────────────────────────────────────────────┘ │ │ │ │
│  │  │  └─────────────────────────────────────────────────────────┘ │ │ │
│  │  └─────────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

**Core principle:** No bank credentials or tokens are ever stored. The app does not integrate with financial institutions. All financial data is user-entered or OCR-extracted.

---

## 2. Layer 5 — Server Security

### 2.1 PostgreSQL

The backend stores a mirror of the 12 syncable tables. No business logic, no balance computation.

### 2.2 Authentication

- **No passwords stored.** Authentication uses email OTP only. No password hashes exist on the server.
- OTP is a 6-digit code, valid for 5 minutes (`expires_in: 300`).
- On verification, server returns JWT access token (15 min TTL) + refresh token (30 day TTL).

### 2.3 Rate limiting

| Endpoint | Limit | Window |
|---|---|---|
| `/auth/request-otp` | 3 per email, 5 per IP | 1 minute |
| `/auth/verify-otp` | 5 per email | 1 minute |
| `/auth/refresh` | 10 per user | 1 minute |
| `/sync/push` | 30 per user | 1 minute |
| `/sync/pull` | 30 per user | 1 minute |
| `/uploads` | 10 per user | 1 minute |
| All other | 100 per user | 1 minute |

Rate limit responses include `Retry-After` header and JSON body with `retry_after` seconds. Client respects this and does not auto-retry before the window elapses.

### 2.4 Household permission enforcement

Permissions are enforced at **both** the server and the client:

| Role | Server enforcement | Client (UI) enforcement |
|---|---|---|
| **Owner** | Full CRUD on all household data | All buttons visible |
| **Member** | CRUD on own + shared; read-only on others' | Edit/delete hidden on others' rows |
| **Viewer** | Read-only on all | Add island hidden, all edit buttons hidden |

Server-side enforcement is the authoritative layer. If the UI fails to hide a button, the API rejects the mutation with `403 FORBIDDEN`. The UI hiding is a UX optimization, not a security boundary.

### 2.5 File upload security

- Max file size: 10 MB.
- Allowed types: `image/jpeg`, `image/png`, `image/webp`, `application/pdf`.
- Files stored with signed URLs. Access limited to authenticated users.
- Retention: 90 days (configurable). Expired files are purged.
- Receipt images may contain PII — files are private to the uploading user by default. Household-visible receipts require explicit opt-in (future).
- No public access — all GET `/uploads/{id}` requests require Bearer JWT.

### 2.6 TLS

- Minimum TLS 1.2. TLS 1.3 preferred.
- HTTPS only. No HTTP endpoints.
- API base URL configured via environment variable (not hardcoded).

---

## 3. Layer 4 — Transport Security

### 3.1 JWT tokens

| Token | TTL | Storage | Rotation |
|---|---|---|---|
| Access token | 15 minutes | `flutter_secure_storage` | Re-issued on refresh |
| Refresh token | 30 days | `flutter_secure_storage` | Rotated on every refresh |

All API requests include `Authorization: Bearer {access_token}`. If the access token is expired, the client attempts a refresh before retrying the request. If refresh fails, the user is prompted to re-authenticate (V2).

### 3.2 Token refresh race condition

Multiple API calls may fire simultaneously when the access token is expired. The `refreshTokenProvider` uses a mutex (one-at-a-time lock):

```
Request 1 → 401 → acquire refresh lock → POST /auth/refresh → new tokens → release lock → retry
Request 2 → 401 → acquire refresh lock (WAIT) → tokens already refreshed → use new token → retry
Request 3 → 401 → acquire refresh lock (WAIT) → tokens already refreshed → use new token → retry
```

Only one refresh HTTP call is made. Waiting callers use the resulting tokens.

### 3.3 What crosses the wire

| Data | Crosses wire? | Notes |
|---|---|---|
| 12 syncable entity rows | Yes (V2 only) | `users`, `accounts`, `transactions`, `transfers`, `categories`, `payees`, `budgets`, `debt_records`, `goals`, `recurring_templates`, `households`, `household_members` |
| `sync_status` | **No** | Client-side only |
| `last_synced_at` | **No** | Client-side only |
| `account_balance_snapshots` | **No** | Derived locally |
| `notifications` | **No** | Local scheduling |
| `ai_processing_logs` | **No** | Local audit trail |
| `sync_metadata` | **No** | Sync bookkeeping |
| Receipt uploads | Yes (user-initiated) | Only via explicit camera scan → upload |
| Bank credentials | **Never** | App doesn't collect them |

### 3.4 Push/pull sync authorization

- Sync endpoints require valid JWT. No auth → sync engine never runs.
- In V1, auth is disabled → sync engine is inert.
- Server validates that pushed records belong to the authenticated user (or a household they're a member of).
- Pull only returns records the user is permitted to see (their own + household memberships).

---

## 4. Layer 3 — Data at Rest

### 4.1 SQLCipher encryption (sqlite3_flutter_libs + sqlcipher)

The local SQLite database is encrypted at rest using SQLCipher (AES-256-CBC).

#### Stack

| Component | Package |
|---|---|
| Database engine | `sqlite3_flutter_libs` (with SQLCipher support) |
| ORM | `drift` (Drift) |
| Build | `drift_dev` |

Drift supports custom SQLite implementations. The `sqlite3_flutter_libs` package includes SQLCipher builds for iOS and Android. Configuration:

```dart
import 'package:drift/native.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

DatabaseConnection createEncryptedConnection(String dbPath, String key) {
  return DatabaseConnection(
    Database.open(
      dbPath,
      sqlite3: sqlite3,
    ),
  );
  // sqlite3.key(key) called in a custom setup callback
}
```

### 4.2 Encryption key management

```
┌───────────────────────────────────────────────────────────┐
│  App launch                                                │
│    │                                                       │
│    ├─ Read DB encryption key from iOS Keychain /           │
│    │  Android Keystore                                     │
│    │                                                       │
│    ├─ Found? ──▶ use key to decrypt SQLCipher DB           │
│    │                                                       │
│    └─ Not found?                                           │
│         ├─ First launch?                                    │
│         │   └─ Generate random 256-bit key                  │
│         │   └─ Store in Keychain/Keystore (biometry-protected)│
│         │   └─ Create encrypted DB with new key             │
│         │                                                   │
│         └─ Key lost? (uninstall/reinstall, new device)      │
│             └─ DB is gone — no recovery                     │
│             └─ Server data (if V2 synced) is pulled fresh   │
```

**Key properties:**
- The DB encryption key never leaves the device keychain.
- On iOS: stored in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- On Android: stored in Android Keystore with `AndroidKeyStore` provider.
- If the user uninstalls and reinstalls, the key is lost. This is acceptable — the server holds a backup if the user had cloud sync enabled (V2). Without cloud sync, data loss on uninstall is expected for a local-first app.
- The key is NOT derived from biometrics or passwords. It's a random key generated on first launch.

### 4.3 Soft delete as security

Deleted records retain `deleted_at` timestamps and are filtered by `WHERE deleted_at IS NULL` in normal queries. This provides an audit trail — nothing is ever physically destroyed without an explicit purge.

| Stage | Retention |
|---|---|
| Active | `deleted_at IS NULL` |
| Soft-deleted | `deleted_at` set; hidden from queries; pushed to server |
| Purged | Physically deleted 30 days after `deleted_at` AND `sync_status = 'synced'`; local-only records stay soft-deleted indefinitely until user requests purge |

### 4.4 What is encrypted

| Data | Encrypted? |
|---|---|
| All SQLite tables (15 tables) | **Yes** — entire DB file encrypted |
| `flutter_secure_storage` values (JWT, refresh) | **Yes** — platform-native encrypted storage |
| Temp files (receipt previews) | No — cleared on session end |
| Logs | No — local only |

---

## 5. Layer 2 — App Gate

### 5.1 Biometric lock

#### Stack

| Platform | Technology | Flutter package |
|---|---|---|
| iOS | Face ID / Touch ID via LocalAuthentication | `local_auth` |
| Android | Fingerprint / Face via BiometricManager | `local_auth` |

#### Flow

```
App enters background
  │
  ▼
Timer starts (configurable: immediately / 1 min / 5 min / 15 min)
  │
  ▼
Timer expires? ── No ──▶ App stays unlocked
  │
  ▼  Yes
App lock state: LOCKED
  │
  ▼
App returns to foreground
  │
  ▼
Biometric prompt (Face ID / Fingerprint)
  │
  ├─ Success ──▶ App unlocks, shows last active screen
  │
  └─ Fail ──▶ Retry (up to 3 attempts)
         │
         └─ 3rd fail ──▶ Fallback to app PIN
                          │
                          ├─ Correct PIN ──▶ App unlocks
                          └─ Wrong PIN ──▶ App stays locked; retry
```

#### Configuration

| Setting | Options | Default |
|---|---|---|
| Biometric lock | On / Off | Off (V1) |
| Auto-lock timer | Immediately / 1 min / 5 min / 15 min / Never | 15 min |
| App PIN | Optional fallback; 4-6 digits | Not set by default |
| Biometric on app launch | On / Off | On (if biometric lock enabled) |

V1 note: The Security Settings screen is present (`/more/settings/security`) but biometric lock is greyed out / "Coming soon" in V1. The UI and provider exist but the feature toggle is disabled. This can be enabled in a V1.x update without schema changes.

### 5.2 Flutter secure storage

All sensitive client-side values are stored in `flutter_secure_storage`:

| Value | Storage | Notes |
|---|---|---|
| Access token (JWT) | `flutter_secure_storage` | Key: `access_token` |
| Refresh token | `flutter_secure_storage` | Key: `refresh_token` |
| App PIN hash | `flutter_secure_storage` | Key: `app_pin_hash` (SHA-256) |
| Biometric lock enabled | SharedPreferences | Not sensitive — just a boolean flag |

`flutter_secure_storage` uses:
- **iOS:** Keychain Services (`kSecClassGenericPassword`)
- **Android:** EncryptedSharedPreferences or Android Keystore (depending on API level)

### 5.3 Auth provider integration

```dart
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(secureStorageProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  Future<void> login(String accessToken, String refreshToken) async {
    await _secureStorage.write('access_token', accessToken);
    await _secureStorage.write('refresh_token', refreshToken);
    state = AuthState.authenticated;
  }

  Future<void> logout() async {
    await _secureStorage.delete('access_token');
    await _secureStorage.delete('refresh_token');
    state = AuthState.localOnly;  // app still works
  }

  Future<String?> getAccessToken() async {
    final token = await _secureStorage.read('access_token');
    if (token == null) return null;

    // Check expiry (JWT payload)
    if (_isExpired(token)) {
      return await _refresh();  // mutex-guarded
    }
    return token;
  }
}

enum AuthState { localOnly, authenticated }
```

---

## 6. Layer 1 — Device Security

### 6.1 Platform keystore

The DB encryption key, app PIN hash, and JWT tokens rely on platform-native secure storage:

| Platform | Storage | Protection |
|---|---|---|
| iOS | Keychain | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — data only accessible when device unlocked; not included in iCloud backups |
| Android | Android Keystore + EncryptedSharedPreferences | `AndroidKeyStore` provider; TEE-backed on devices with hardware security modules |

Both platforms ensure that if the device is locked, secure storage values are inaccessible. A rooted/jailbroken device weakens this; the app does not add root-detection in V1 (complexity tradeoff).

### 6.2 iOS secure enclave

On iPhones with Secure Enclave (iPhone 5s+), biometric data (Face ID / Touch ID) is stored and processed entirely within the enclave. The app never receives raw biometric data — only a boolean success/failure from `LocalAuthentication`.

### 6.3 Android TEE

On Android devices with a Trusted Execution Environment (TEE), biometric templates are stored in hardware-backed keystore. The app uses `BiometricManager` / `BiometricPrompt` APIs — no direct access to biometric data.

---

## 7. Household Permission Model

### 7.1 Roles

| Role | Create | Read | Update | Delete | Add island visible |
|---|---|---|---|---|---|
| **Owner** | Everything | Everything | Everything | Everything | Yes |
| **Member** | Own + shared | Everything | Own + shared | Own only | Yes |
| **Viewer** | Nothing | Everything | Nothing | Nothing | No |

### 7.2 Ownership indicators

Transactions and accounts within a household carry ownership context:

| Label | Meaning | UI color |
|---|---|---|
| Mine | Owned by current user | Blue |
| Theirs | Owned by another member | Slate |
| Ours | Shared (`household_id` set) | Emerald |

Ownership is determined by the `owner_user_id` column on each entity. Household-shared entities have `household_id` set.

### 7.3 Household invite security

- Any authenticated user can search for another user by email (`GET /users/search`).
- Invites are sent from an owner to a searched user. The invitee receives a notification (future push / local poll).
- Rate limit: `GET /users/search` is rate-limited at 100/min per user (general tier). No invite-specific rate limit in V1 — addressed in V2.
- Invite acceptance creates a `household_members` row with role set by the inviter.

### 7.4 Viewer data exfiltration prevention

V1 does not implement export/watermark restrictions. A viewer can see data but cannot create/edit/delete. In V2, the following hardening is planned:

- Disable CSV export for viewer role.
- Disable receipt upload viewing for viewer role (metadata only).
- App watermark with viewer's email on sensitive screens (anti-screenshot).

For V1, the Viewer role is a UX trust model, not a DRM system.

---

## 8. Privacy Boundaries

### 8.1 Data classification

| Classification | Tables / Data | Behavior |
|---|---|---|
| **Local-only** | `account_balance_snapshots`, `notifications`, `ai_processing_logs`, `sync_metadata` | Never leaves device. Not pushed, not included in API responses. |
| **Client-side metadata** | `sync_status`, `last_synced_at` on every syncable row | Never sent to server. Stripped from push payloads. |
| **Syncable** | 12 syncable tables (full rows minus client-side metadata) | Pushed/pulled only when user is V2-authenticated. In V1, no data leaves the device. |
| **Never collected** | Bank credentials, bank tokens, SSN, government IDs | App doesn't have fields for these. No OCR extraction for them. |

### 8.2 What the server knows

In V2, when sync is enabled, the server stores:
- User email + profile metadata
- All 12 syncable entity rows (financial transactions, accounts, budgets, etc.)
- Household membership graph
- Uploaded receipt images (90-day retention)

The server does NOT have access to:
- Raw AI extraction payloads (stays in `ai_processing_logs` — local-only)
- Sync bookkeeping metadata (`sync_metadata`)
- Notification scheduling data

### 8.3 Privacy messaging

The privacy boundary is communicated in:
- Onboarding: "Your data lives on your device. Cloud backup is optional and encrypted."
- Settings → AI & Data: lists what data the AI processes and that AI logs stay local.
- Settings → Cloud Sync: "Your synced data is encrypted in transit (TLS) and at rest on our servers. You can delete your server data at any time by removing your account."
- No data is ever sold, shared with third parties, or used for advertising.

---

## 9. Data Deletion & Account Lifecycle

### 9.1 Delete account flow

```
User taps "Delete account & reset data" in Settings → Profile
  │
  ▼
Confirmation dialog: "This will permanently delete all your data everywhere. This cannot be undone."
  │
  ├─ Cancel ──▶ No action
  │
  └─ Confirm:
       ├─ V2: POST /auth/logout (invalidate tokens)
       ├─ V2: POST /sync/reset (server deletes user's sync data)
       ├─ Local: DROP all tables, recreate empty DB
       ├─ Clear flutter_secure_storage (tokens, PIN)
       └─ Restart app → shows onboarding fresh
```

Household data contributed by the deleted user remains in the household for other members. Only the user's personal rows and `owner_user_id` associations are removed. Shared rows where the user was the creator get a `created_by_user_id` nullification.

### 9.2 Local-only user data reset

A user who never authenticated (no `users` row) can reset from Settings → Profile → "Delete account & reset data". This drops the local DB and restarts the app.

### 9.3 Soft-deleted record purge

Periodically (every app launch + every 7 days), the sync engine purges records where:
- `deleted_at < now() - 30 days`
- `sync_status = 'synced'`

Records that never synced (local-only user) are kept until explicit reset. This prevents data loss for users who haven't enabled cloud.

---

## 10. Audit Trail & Observability

### 10.1 AI processing logs

`ai_processing_logs` provides a local audit trail for every AI extraction:
- What model was used (`gemma-4-e4b-it`, etc.)
- What raw output was produced (`extracted_payload` — JSON)
- Confidence score (0.0–1.0)

This is read-only for users, write-only for the AI module. It provides transparency for AI-assisted entries.

### 10.2 Sync metadata

`sync_metadata` stores sync health:
- `last_synced_at`, `last_sync_attempt_at`, `last_sync_status`, `last_sync_error`, `sync_failed_count`

This powers the Sync Status sheet and the sync icon in the top bar.

### 10.3 Soft delete audit trail

`deleted_at` timestamps + the record remaining in the DB (hidden by queries) means no financial data is silently destroyed. Users can request a data export that includes soft-deleted records.

---

## 11. Threat Model (V1)

| Threat | Risk level | Mitigation |
|---|---|---|
| Physical device access (unlocked) | High | Biometric lock (V1.x), auto-lock timer |
| Physical device access (locked) | Low | SQLCipher encrypts DB at rest; key in platform keystore |
| Network MITM | Low | TLS 1.2+, certificate validation |
| Malicious app on same device accessing DB file | Low | Platform sandboxing; SQLCipher encrypted file |
| Rooted/jailbroken device | Medium | Not mitigated in V1 (complexity tradeoff) |
| Server compromise | Low | Server stores only syncable rows (not AI logs, not local metadata); server computes nothing (stateless) |
| Accidental data exposure via export | Medium | CSV export is user-initiated; no auto-export |
| Viewer role screen-scraping | Low | Mitigated in V2 (watermark, export disabled) |
| JWT token theft from secure storage | Low | Platform-native encrypted storage; token TTLs short (15min access, 30d refresh) |

---

## 12. V1 Scope Note

In V1:
- **Auth is disabled.** No email OTP, no JWT, no tokens in `flutter_secure_storage`. The auth provider stays in `AuthState.localOnly`.
- **Sync is inert.** The sync engine is built but never runs (no auth → no push/pull).
- **Biometric lock is greyed out.** Security Settings screen exists, UI is built, provider is wired, but the biometric feature toggle is disabled.
- **Data stays on device.** With auth and sync disabled, no data leaves the local SQLite DB.

These features are infrastructure-complete — flipping the switch requires only enabling the auth toggle and biometric toggle. No schema changes or rewrite needed.

---

## 13. Summary

| Concern | Implementation |
|---|---|
| Data at rest (local DB) | SQLCipher AES-256 via `sqlite3_flutter_libs`; key in Keychain/Keystore |
| Data at rest (server) | PostgreSQL; V2 auth required; server never sees client-side metadata |
| Data in transit | TLS 1.2+; Bearer JWT (access 15min, refresh 30d rotated) |
| Device security | Biometric lock (`local_auth`); app PIN fallback; auto-lock timer |
| Secure token storage | `flutter_secure_storage` (Keychain / EncryptedSharedPreferences) |
| Household permissions | Owner/Member/Viewer; enforced server-side (403); UI-hidden for UX |
| Privacy boundaries | 4 tables local-only; `sync_status` + `last_synced_at` never sent to server |
| Audit trail | `ai_processing_logs` (AI), `sync_metadata` (sync health), `deleted_at` (soft delete) |
| Data deletion | Account delete wipes local DB + server data; household contributed data preserved for other members |
| V1 stance | Auth disabled, sync inert, biometric greyed out — all infrastructure exists, gated behind toggles |

# Task 21 — Backend — NestJS Setup & Auth

**Status:** [ ]

---

## Objective

Scaffold the NestJS backend with PostgreSQL, implement email OTP authentication, JWT tokens, and user profile endpoints. The backend is a dumb store + auth gate — no business logic.

References: `docs/api-contracts.md`, `docs/solutions-arch.md` §1 §11, `docs/security-model.md`

## Dependencies

- None (runs in parallel with mobile tasks)

## Deliverables

### 21.1 NestJS project scaffold
Create in `backend/` directory:
- `nest new backend` or manual scaffold
- TypeScript, strict mode
- PostgreSQL via TypeORM or Prisma
- Docker Compose for local dev (PostgreSQL + NestJS)

### 21.2 Database schema (PostgreSQL)
Mirror of the 12 syncable tables with the 6 sync columns:
- `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`
- `created_at TIMESTAMPTZ DEFAULT now()`
- `updated_at TIMESTAMPTZ DEFAULT now()`
- `deleted_at TIMESTAMPTZ` (nullable)
- `sync_status TEXT DEFAULT 'synced'`
- `last_synced_at TIMESTAMPTZ` (nullable)

Additional server-only tables:
- `refresh_tokens` — user_id, token_hash, expires_at, revoked
- `otp_codes` — email, code_hash, expires_at, attempts

### 21.3 Auth module (`backend/src/auth/`)
**Endpoints:**
- `POST /auth/send-otp` — body: `{ email }`, sends 6-digit code via email (logs to console in dev)
- `POST /auth/verify-otp` — body: `{ email, code }`, returns `{ access_token, refresh_token }`
- `POST /auth/refresh` — body: `{ refresh_token }`, returns `{ access_token, refresh_token }`
- `POST /auth/logout` — body: `{ refresh_token }`, revokes token

**JWT strategy:**
- Access token: 15 min expiry, signed with RS256
- Refresh token: 30 day expiry, stored hashed in DB, rotated on use
- `JwtAuthGuard` for all `/sync/*` and `/me/*` endpoints

### 21.4 Users module (`backend/src/users/`)
**Endpoints:**
- `GET /me` — get current user profile
- `PATCH /me` — update display_name, currency_code, locale, timezone
- `DELETE /me` — soft-delete user account
- `GET /users/search?q={email}` — search users for household invites

### 21.5 Middleware
- Rate limiting: 5 OTP attempts per email per 15 min, 100 requests per IP per min general
- Request ID: UUID per request, logged and returned in response headers
- Error filter: consistent `{ error: { code, message, details } }` envelope

### 21.6 Docker Compose
```yaml
services:
  postgres:
    image: postgres:16
    environment: POSTGRES_DB=lootr, POSTGRES_USER=lootr, POSTGRES_PASSWORD=dev
    ports: ["5432:5432"]
    volumes: [pgdata:/var/lib/postgresql/data]
  backend:
    build: .
    ports: ["3000:3000"]
    environment: DATABASE_URL=postgres://..., JWT_PRIVATE_KEY=..., ...
    depends_on: [postgres]
```

### 21.7 Environment config
- `.env.example` with all required vars
- ConfigModule for typed env access
- Secrets: JWT keys, SMTP credentials, Sentry DSN

## Acceptance Criteria

- [ ] `docker compose up` starts PostgreSQL + NestJS successfully
- [ ] `POST /auth/send-otp` sends OTP
- [ ] `POST /auth/verify-otp` returns valid JWT tokens
- [ ] `POST /auth/refresh` rotates refresh token
- [ ] `GET /me` returns user profile when authenticated
- [ ] `GET /me` returns 401 when unauthenticated
- [ ] Rate limiting blocks after 5 OTP attempts per 15 min
- [ ] All errors use consistent `{ error: { code, message, details } }` format
- [ ] Database migrations run on startup
- [ ] PostgreSQL schema matches syncable table definitions

## Files Likely Affected

- `backend/` (entirely new)
- `backend/package.json` (new)
- `backend/src/main.ts` (new)
- `backend/src/app.module.ts` (new)
- `backend/src/auth/` (new)
- `backend/src/users/` (new)
- `backend/src/common/` (new — middleware, guards, filters)
- `backend/src/database/` (new — entities, migrations)
- `backend/docker-compose.yml` (new)
- `backend/.env.example` (new)

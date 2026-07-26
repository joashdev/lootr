# Specs Backlog — Remaining Work for Spec-Driven Build

Existing reference docs:
- `docs/product-strategy.md` — vision, personas, scope, tech stack, principles
- `docs/domain-model.md` — entities, fields, relationships

---

## How To Use This

Each spec, when written, should be a standalone markdown doc that is concrete enough to hand to a developer (or yourself in 3 months) without ambiguity. Finish these before writing code.

---

# Phase 1 — Foundation Specs ✅

## 1. Database Schema ✅

**Status:** Done.
**Produces:** `docs/database-schema.md` + `docs/mandocs/database-schema.html`
**Purpose:** Full SQL schema for the local SQLite database (Drift ORM).
**Coverage:**
- All tables with columns, types, constraints, defaults
- Primary keys, foreign keys, indexes
- `sync_status`, `created_at`, `updated_at`, `deleted_at` on syncable tables
- Migration strategy (Drift migrations)
**Inputs:** `domain-model.md` entities → map each to a table
**Priority:** Critical
**Follow-up:** Add `sync_metadata` table (#16, local-only) introduced by the sync engine spec.

---

## 2. API Contracts ✅

**Status:** Done.
**Produces:** `docs/api-contracts.md` + `docs/mandocs/api-contracts.html`
**Purpose:** REST API contract between mobile app and NestJS backend.
**Coverage:**
- Endpoints (auth, sync, household, file upload)
- Request/response shapes
- Auth flow (passwordless OTP)
- Error codes
- Rate limiting
**Inputs:** `product-strategy.md` backend section
**Priority:** Critical

---

## 3. Sync Engine Design ✅

**Status:** Done.
**Produces:** `docs/sync-engine.md` + `docs/mandocs/sync-engine.html`
**Purpose:** How local and server data stay in sync.
**Coverage:**
- Pull/push flow
- Periodic, reconnect, foreground sync triggers
- Sync status FSM (`local_only` → `pending_sync` → `synced` / `sync_failed`)
- Conflict resolution strategy (last-write-wins)
- Initial sync / cold start
- Large dataset handling (cursor pagination)
**Priority:** High

---

# Phase 2 — Architecture Specs

## 4. Navigation & Routing ✅

**Status:** Done.
**Produces:** `docs/navigation-arch.md` + `docs/mandocs/navigation-arch.html`
**Purpose:** Screen tree, deep links, bottom tab structure.
**Coverage:**
- Tab bar structure (Dashboard, Transactions, Budgets, More/Profile)
- Screen hierarchy within each tab
- Modal routes (add transaction, scan receipt, etc.)
- Deep link urls
- Empty states & demo data strategy
- Swipe actions, search, filter chips
- Safe-to-spend hero card (PocketGuard pattern)
- 52 screens total (4 tabs + 27 pushed + 15 sheets + 6 onboarding/auth)
**Priority:** High

---

## 5. State Management ✅

**Status:** Done.
**Produces:** `docs/state-management.md` + `docs/mandocs/state-management.html`
**Purpose:** Riverpod structure, providers, data flow.
**Coverage:**
- Global vs scoped providers
- Entity caching strategy
- Optimistic update pattern
- Sync state vs local state separation
- Loading/error/empty states
**Priority:** High

---

## 6. Security Model ✅

**Status:** Done.
**Produces:** `docs/security-model.md` + `docs/mandocs/security-model.html`
**Purpose:** Data at rest, in transit, auth boundaries.
**Coverage:**
- Local DB encryption (sqlcipher?)
- Biometric lock
- API auth tokens (JWT?)
- Household permission model (owner / member / viewer)
- Privacy boundaries (what data stays local-only)
- Secure storage for any sensitive values
**Priority:** High

---

## 7. Design System ✅

**Status:** Done.
**Produces:** `docs/design.md` + `docs/mandocs/design.html`
**Purpose:** Token-level spec for the UI.
**Coverage:**
- Color palette (token names + hex values, light + dark mode)
- Typography scale (font family, size, weight, line height)
- Spacing scale (4px grid)
- Border radius, shadow elevation tokens
- Component library skeleton (cards, buttons, inputs, FAB, charts)
- Dark mode mapping
**Inputs:** `domain-model.md` design references section
**Priority:** Medium

---

# Phase 3 — Operational Specs

## 8. Notification Architecture

**What it produces:** `notifications-arch.md`
**Purpose:** Local + push notification system design.
**Coverage:**
- Local notification scheduling (recurring, bill due, installment, debt)
- Notification permissions flow
- Tapping notification → deep link mapping
- Future cloud push (FCM)
**Inputs:** `product-strategy.md` notifications section
**Priority:** Medium

---

## 9. MVP Prioritization & Roadmap

**What it produces:** `roadmap.md`
**Purpose:** Phased build plan with concrete milestones.
**Coverage:**
- Phase breakdown with features per phase
- Dependencies between phases
- Estimated effort per phase
- "Done" criteria for each phase
- Stretch goals vs hard scope
**Inputs:** `product-strategy.md` V1 scope (included/excluded)
**Priority:** Medium

---

## 10. QA & Testing Strategy

**What it produces:** `testing-strategy.md`
**Purpose:** How the app is tested at each level.
**Coverage:**
- Unit test targets (domain logic, parsers, calculations)
- Widget test targets (screens, components)
- Integration test targets (transaction flow, sync flow)
- Drift DB test strategy (in-memory DB per test)
- AI output snapshot testing
- Test data fixtures strategy
**Priority:** Medium

---

## 11. CI/CD & Infrastructure

**What it produces:** `infrastructure.md`
**Purpose:** Build, deploy, and monitor pipeline.
**Coverage:**
- GitHub Actions workflows (PR checks, build, deploy)
- Sentry setup and error grouping strategy
- Docker compose for local backend dev
- VPS/Hetzner deployment (Docker Compose or k3s)
- Code signing and app store deployment
- Environment variable management
**Inputs:** `product-strategy.md` infrastructure section
**Priority:** Low (needed before launch, not before coding)

---

## 12. Monetization

**What it produces:** `monetization.md`
**Purpose:** Pricing model and paywall design.
**Coverage:**
- Free tier limits
- Subscription features
- One-time purchase vs subscription
- Household pricing
- Local-first monetization strategy (no lock-in paywall during offline use)
**Priority:** Low

---

# Supporting Product & Migration Specs ✅

## 13. Cashew Product Benchmark ✅

**Status:** Done.
**Produces:** `docs/cashew-product-benchmark.md` + `docs/mandocs/cashew-product-benchmark.html`
**Purpose:** Compare Cashew's shipped capabilities with Lootr's implemented and planned product, then select V1 adoption priorities.
**Coverage:**
- Feature matrix with implemented/partial/spec-only distinctions
- Lootr advantages and Cashew capability gaps
- V1 P0/P1/P2/defer/reject decisions
- UI/UX principles worth adopting
- Required model changes, constraints, risks, and acceptance criteria
**Priority:** High

---

## 14. Cashew Data Migration ✅

**Status:** Done.
**Produces:** `docs/cashew-data-migration.md` + `docs/mandocs/cashew-data-migration.html`
**Purpose:** Define a loss-minimizing, local-only migration from a Cashew SQLite backup into Lootr.
**Coverage:**
- Source acquisition, schema detection, and integrity preflight
- Canonical staging, entity mapping, and difficult transformations
- Provenance, preserved payloads, idempotency, and rollback
- Balance reconciliation, privacy, UX, test strategy, and V1 boundary
- Schema-48 real-export audit, blockers, and completion criteria
**Priority:** Critical

---

## 15. Cashew Migration Operator Guide ✅

**Status:** Done.
**Produces:** `docs/cashew-migration-operator-guide.md` + `docs/mandocs/cashew-migration-operator-guide.html`
**Purpose:** Provide safe, privacy-preserving operating and recovery instructions for the complete Cashew migration flow.
**Coverage:**
- Source-file safety, private staging, dry run, and review
- Timezone/title policy, atomic publication, and exact reconciliation
- Cancellation, interruption recovery, rollback, and idempotent re-import
- Encrypted backup/restore, currency-aware CSV, and limitations
**Priority:** Critical

---

## 16. Adopted V1 Experience ✅

**Status:** Done.
**Produces:** `docs/adopted-v1-experience.md` + `docs/mandocs/adopted-v1-experience.html`
**Purpose:** Define the connected Cashew-inspired V1 workflows while preserving Lootr’s stable navigation, privacy boundary, and calm interaction model.
**Coverage:**
- Unified Add with progressive correction, calculator fallback, and Undo
- Persistent ledger search, filters, period, sort, scroll, and atomic bulk cleanup
- Explainable reports, categorization memory, recurring occurrence lifecycle, and composite budgets
- Bounded dashboard customization, semantic color, accessibility, and verification
**Priority:** Critical

---

## 17. Public Alpha Release ✅

**Status:** Done.
**Produces:** `docs/public-alpha-release.md` + `docs/mandocs/public-alpha-release.html`
**Purpose:** Define an auditable, signed Android alpha release and privacy-safe GitHub feedback path.
**Coverage:**
- AGPL public-audit and official-project governance boundary
- Privacy-safe in-app and repository bug reporting
- Protected, signed, tag-driven GitHub APK release
- Checksums, provenance, signing continuity, and acceptance criteria
**Priority:** Critical

---

> **Suggested work order:** Write specs 1–3 → start coding foundation → write 4–6 in parallel → write 7–10 before leaving foundation phase → 11–12 before launch.

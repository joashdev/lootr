# Task Backlog — Lootr Implementation

Derived from `docs/solutions-arch.md`. Build order follows the dependency rule: data → domain → application → presentation. Backend is parallel.

---

## Task Index

| # | Task | Depends On | Priority |
|---|---|---|---|
| 01 | Project Setup & Scaffolding | — | Critical | [x] |
| 02 | Design System & Theme | 01 | High | [x] |
| 03 | Data Layer — Drift Schema & Database | 01 | Critical | [x] |
| 04 | Data Layer — Repositories | 03 | Critical | [x] |
| 05 | Domain Layer — Entities & Value Objects | 03 | Critical | [x] |
| 06 | Domain Layer — Use Cases | 05, 04 | Critical | [x]
| 07 | Application Layer — Riverpod Providers | 06, 04 | Critical | [x] |
| 08 | Application Layer — Sync Engine | 04, 03 | High |
| 09 | Application Layer — AI Layer (Optional) | 06 | Medium |
| 10 | Presentation — Navigation Shell & Tab Bar | 02, 07 | Critical |
| 11 | Presentation — Dashboard Tab | 10, 02, 07 | High |
| 12 | Presentation — Transactions Tab | 10, 02, 07 | High |
| 13 | Presentation — Budgets Tab | 10, 02, 07 | High |
| 14 | Presentation — More Tab & Settings | 10, 02, 07 | High |
| 15 | Presentation — Add Transaction Sheet | 10, 02, 07 | High |
| 16 | Presentation — Filter Sheet & Search | 10, 02, 07 | Medium |
| 17 | Presentation — Onboarding | 10, 02 | Medium |
| 18 | Demo Data & Seed Data | 04 | Medium |
| 19 | Local Notifications | 04, 03 | Medium |
| 20 | Testing Infrastructure | 01 | High |
| 21 | Backend — NestJS Setup & Auth | — | Medium |
| 22 | Backend — Sync Endpoints | 21 | Medium |

## Status Legend
- `[ ]` Pending
- `[~]` In Progress
- `[x]` Done

## Phase Mapping

| Phase | Tasks | Description |
|---|---|---|
| 1 — Foundation | 01, 02, 03, 04, 05 | Project setup, design tokens, DB, repos, entities |
| 2 — Core Logic | 06, 07, 08 | Use cases, providers, sync engine |
| 3 — UI Shell | 10 | Navigation, tab bar, routing |
| 4 — Feature Screens | 11, 12, 13, 14, 15, 16, 17 | All screens and sheets |
| 5 — Polish | 09, 18, 19, 20, 21, 22 | AI, demo data, notifications, testing, backend |

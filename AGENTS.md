# AGENTS.md — Lootr

Spec-driven personal finance app. This file tells AI agents how to work here.

## Project

A calm, offline-first, privacy-first personal finance app. Flutter/Riverpod/Drift/SQLite on-device, NestJS/PostgreSQL backend (sync/backup only, V2). No bank integrations. AI optional + on-device only.

## Workflow

1. **Specs before code.** Read `docs/specs-backlog.md` for what's done and what's next. All specs are `.md` files under `docs/`.
2. **Write the MD first** — each spec is a standalone markdown doc that must be concrete enough to hand to a developer.
3. **Then write `docs/mandocs/{same-name}.html`** — identical content, self-contained HTML with inline CSS for human review. Match the existing style (custom CSS vars at `:root`, system font stack, mono for code, `.diagram` blocks for ASCII art).
4. **Update `specs-backlog.md`** when a spec is done — mark it `✅` and set `**Status:** Done.`
5. **Before coding:** complete all Phase 2 specs. Foundation phase (Phase 1) is sufficient to begin data/domain layers.

## Conventions

### File naming
- Specs: kebab-case, `.md` in `docs/`. e.g. `docs/database-schema.md`, `docs/solutions-arch.md`
- Review docs: same name, `.html` in `docs/mandocs/`. e.g. `docs/mandocs/database-schema.html`

### Spec format
```
# Title — Personal Finance App

Optional one-liner.
References: `upstream-spec.md` (what it contributes).

---

## 1. Section One
...
```

- Em-dash between title and "Personal Finance App"
- `References:` line second — backtick filenames with parenthetical notes
- Numbered `## H2` sections from `## 1.` onwards
- Tables: pipe tables, 3–5 columns, bold headers, monospace first column for entity/keyword tables
- ASCII diagrams in fenced ` ``` ` code blocks (not `<pre>`)
- Cross-reference with `§` notation: `database-schema.md §3.1`
- 15px body, 14px tables, 13px code

### Commit format
Conventional Commits: `type(scope): subject`

Footer: `Co-authored-by: {{ model_name }}` (replace `{{ model_name }}` with the actual model name at commit time).

### Specs-backlog
Each spec entry has:
```
## N. Spec Name [✅ if done]
**Status:** Done/Pending.
**Produces:** `docs/file.md` + `docs/mandocs/file.html`
**Purpose:** one-liner
**Coverage:** bullet list of required sections
**Priority:** Critical/High/Medium/Low
```

## Key files (read these first)

| File | Role |
|---|---|
| `docs/product-strategy.md` | Root — vision, personas, V1 scope, tech stack |
| `docs/domain-model.md` | 10 domains, entity definitions |
| `docs/database-schema.md` | 16 tables (12 syncable + 4 local-only), Drift mappings |
| `docs/navigation-arch.md` | 50 screens, go_router routes, tab bar structure |
| `docs/solutions-arch.md` | Cohesive architecture overview, data flow, key decisions |
| `docs/state-management.md` | Riverpod provider hierarchy, patterns, testing |
| `docs/security-model.md` | 5-layer defense-in-depth, SQLCipher, JWT, biometric |
| `docs/api-contracts.md` | REST API, auth OTP, sync endpoints |
| `docs/sync-engine.md` | Sync FSM, push/pull, LWW conflict resolution |
| `docs/design.md` | Tokens, components, dark mode |
| `docs/specs-backlog.md` | Progress tracker, remaining work |
| `docs/mandocs/app-mockups.html` | Visual reference — 11 screens |

## Archived decisions (things not to revisit without new information)

| Decision | Settled in |
|---|---|
| 4 tabs + rightmost Add island | docs/navigation-arch.md §2 |
| Unified transaction list + Filter Sheet | docs/navigation-arch.md §4 |
| NL quick add with mic toggle inside field | docs/navigation-arch.md §2 |
| Save-first, no review queue, undo snackbar 5s | docs/domain-model.md §527 |
| Stored balances + transaction audit trail | docs/database-schema.md §1, docs/domain-model.md |
| Transfers in dedicated table (not transaction rows) | docs/database-schema.md §1.1 |
| Income deductions via parent_transaction_id | docs/database-schema.md §1.2 |
| Last-write-wins conflict resolution | docs/sync-engine.md §7 |
| Global last_synced_at (not per-table) | docs/sync-engine.md §4 |
| Auth disabled in V1, sync engine gated | docs/navigation-arch.md §7.6 |
| AI optional, on-device, never auto-mutates | docs/product-strategy.md |
| Flutter/Riverpod/Drift/SQLite + NestJS/PostgreSQL | docs/product-strategy.md |
| Color-only semantic feedback (no guilt language) | docs/design.md §1 |

## Status

Phase 1 (Foundation): ✅ #1-3
Phase 2 (Architecture): ✅ #4-7
Phase 3 (Operational): #8-12 pending
Cleanup: `sync_metadata` table done, AGENTS.md done

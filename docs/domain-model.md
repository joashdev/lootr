# Personal Finance App — Domain Model v1

# Core Philosophy

- stored balances are optimized for read-heavy UX
- transactions remain the financial event source
- balances can be recalculated from transactions
- app is offline-first
- sync-friendly from day one
- AI never mutates finances automatically

---

# High-Level Domains

1. Identity Domain
2. Accounts Domain
3. Transactions Domain
4. Budgeting Domain
5. Debt Domain
6. Goals Domain
7. Recurring Domain
8. Notifications Domain
9. AI Assistance Domain
10. Sync Domain

---

# Identity Domain

## User

Represents an app user.

### Fields
- id
- email
- display_name
- currency_code
- locale
- timezone
- ai_enabled
- created_at
- updated_at
- deleted_at

### Notes
- local-first means user account is optional
- offline users may remain anonymous locally
- cloud auth only required for sync/backups

---

## Household

Shared financial space.

### Fields
- id
- name
- created_by_user_id
- created_at
- updated_at
- deleted_at

### Purpose
Supports:
- shared accounts
- shared budgets
- shared goals
- shared debts

---

## HouseholdMember

### Fields
- id
- household_id
- user_id
- role
- created_at

### Roles
- owner
- member
- viewer

---

# Accounts Domain

## Account

Represents stored financial containers.

### Core Principle
Stored balance is the runtime source for fast reads.

Transactions remain the audit trail.

Balance recalculation exists as recovery tooling.

### Fields
- id
- household_id (nullable)
- owner_user_id
- name
- account_type
- balance
- currency_code
- is_archived
- is_hidden
- created_at
- updated_at
- deleted_at
- sync_status
- last_synced_at

### Account Types

## Asset Accounts
- cash
- bank
- ewallet
- savings
- investment
- crypto

## Liability Accounts
- credit_card
- loan
- bnpl

### Notes
- balance is stored directly
- optimized for dashboard speed
- transactions update balances immediately
- recalculation utility exists for drift correction

---

## AccountBalanceSnapshot

Optional optimization table.

### Purpose
Supports:
- fast graphs
- historical balance charts
- net worth timelines

### Fields
- id
- account_id
- balance
- snapshot_at

---

# Transactions Domain

## Transaction

Core financial event.

### Fields
- id
- account_id
- category_id
- payee_id
- recurring_template_id (nullable)
- amount
- transaction_direction
- transaction_mode
- transaction_subtype
- note
- occurred_at
- created_at
- updated_at
- deleted_at
- sync_status
- last_synced_at

---

# Transaction Direction

Represents financial direction.

### Values
- expense
- income
- transfer

---

# Transaction Mode

Represents recording behavior.

### Values
- one_time
- recurring
- installment
- debt

---

# Transaction Subtypes

Optional specialization.

### Examples
- salary
- refund
- transfer_fee
- subscription
- loan_payment
- debt_payment

---

# Transaction Creation Flow

Transactions should save immediately.

No review queue.

Suggested UX:
- quick capture
- optional edit/undo
- recent activity stream
- lightweight correction flow

---

# Transaction Editing Rules

## Expense Edit
1. refund previous amount
2. deduct new amount

## Income Edit
1. deduct previous amount
2. add new amount

## Transfer Edit
1. reverse previous transfer
2. apply updated transfer

This prevents drift accumulation.

---

# Balance Recalculation

Recovery utility for edge cases.

### Trigger Conditions
- sync conflicts
- corrupted balances
- manual repair
- migration repair

### Strategy
Recompute balance from:
- opening balance
- ordered transactions

Should NOT run continuously.

---

## Transfer

Dedicated transfer entity.

### Purpose
Avoid double transactions.

### Fields
- id
- source_account_id
- destination_account_id
- amount
- fee_amount
- note
- occurred_at
- created_at
- updated_at
- deleted_at

### Behavior
- subtract from source
- add to destination
- excluded from spending analytics

Transfer fee:
- separate expense transaction

---

## Category

Transaction grouping.

### Fields
- id
- parent_category_id
- name
- icon
- color
- category_group
- created_at
- updated_at

### Groups
- expense
- income
- transfer

---

## Payee

Normalized merchant/payee entity.

### Fields
- id
- normalized_name
- display_name
- logo_url
- created_at
- updated_at

### Purpose
- categorization
- recurring detection
- analytics
- subscriptions
- merchant insights

---

# Budgeting Domain

## Budget

Monthly spending target.

### Fields
- id
- household_id (nullable)
- owner_user_id
- category_id
- amount
- month
- year
- created_at
- updated_at

### Notes
- advisory only
- not restrictive
- computed from expense transactions

---

# Debt Domain

## DebtRecord

Social debt tracking.

### Fields
- id
- owner_user_id
- counterparty_name
- debt_direction
- amount
- remaining_balance
- note
- due_date
- status
- created_at
- updated_at

### Debt Directions
- lent
- borrowed

### Status
- active
- partially_paid
- settled

---

# Goals Domain

## Goal

Financial target tracking.

### Fields
- id
- owner_user_id
- household_id (nullable)
- name
- goal_type
- target_amount
- current_amount
- target_date
- created_at
- updated_at

### Goal Types
- emergency_fund
- savings
- travel
- debt_payoff
- custom

---

# Recurring Domain

## RecurringTemplate

Recurring transaction template.

### Fields
- id
- account_id
- category_id
- payee_id
- amount
- recurrence_rule
- reminder_enabled
- auto_create_disabled
- next_occurrence_at
- created_at
- updated_at

### Philosophy
Templates create:
- reminders
- suggested entries

NOT automatic finalized transactions.

---

# Notifications Domain

## Notification

Local-first reminder system.

### Fields
- id
- notification_type
- related_entity_id
- scheduled_at
- is_completed
- created_at

### Types
- recurring_reminder
- bill_due
- installment_due
- debt_reminder
- subscription_reminder

---

# AI Assistance Domain

## AIProcessingLog

Stores AI extraction/categorization metadata.

### Fields
- id
- source_type
- source_reference_id
- model_used
- extracted_payload
- confidence_score
- created_at

### Purpose
- debugging
- transparency
- explainability
- offline AI auditability

---

# Sync Domain

## Sync Metadata

Every syncable entity should contain:
- id (UUID)
- created_at
- updated_at
- deleted_at
- sync_status
- last_synced_at

---

# Sync Status

### Values
- local_only
- pending_sync
- synced
- sync_failed

---

# Important Architectural Decisions

## No Review Queue

The app is:
- save-first
- correction-friendly
- fast-entry optimized

Instead of review queues:
- recent activity stream
- undo actions
- quick editing
- lightweight confirmations

This matches:
- Monarch
- Copilot
- modern consumer finance UX

---

# Transaction Screen Structure

Suggested tabs:

## Transaction Directions
- Expenses
- Income
- Transfers

Filters:
- one-time
- recurring
- installment
- debt

FAB:
- quick add
- manual
- OCR
- voice

---

# Recommended Dashboard Philosophy

- calm
- glanceable
- low-noise
- fast loading
- emotionally safe

Avoid:
- enterprise density
- accounting complexity
- guilt-heavy UX

---

# Design References

## Strong Product References

### Copilot Money
Strengths:
- information hierarchy
- spacing
- onboarding
- calm visual tone
- transaction UX

### Monarch Money
Strengths:
- dashboard structure
- net worth presentation
- household handling
- reports

### Impeccable
Strengths:
- typography
- spacing
- visual rhythm
- modern card styling
- polish quality

---

# Recommended Design Direction

# Overall Style

"Calm premium consumer finance"

Characteristics:
- large spacing
- strong typography hierarchy
- soft surfaces
- low visual clutter
- subtle charts
- rounded cards
- minimal borders
- strong whitespace

---

# Recommended Visual System

## Typography

Use:
- Inter
- SF Pro style hierarchy

Characteristics:
- large balances
- medium-weight section titles
- subdued metadata
- compact transaction rows

---

## Color System

Primary:
- neutral grayscale base
- muted accent colors
- avoid oversaturated fintech colors

Suggested accents:
- emerald
- indigo
- slate
- warm neutral

Avoid:
- neon gradients
- aggressive reds
- overly gamified palettes

---

## Card Design

Use:
- large radius
- soft shadows
- layered surfaces
- subtle elevation

Avoid:
- hard outlines everywhere
- dense grids
- excessive separators

---

## Dashboard Layout

Recommended:

1. net worth hero
2. account summary cards
3. income vs expense strip
4. budget progress
5. recent transactions
6. insights

Keep dashboards vertically scannable.

---

# AI UI Philosophy

AI should feel:
- assistive
- invisible
- reliable
- non-intrusive

Avoid:
- chatbots everywhere
- AI personality overload
- fake intelligence

Best usage:
- autofill
- suggestions
- summaries
- categorization

---

# Suggested Prompt Ideas

Use these prompts in separate sessions for UI exploration.

---

## Prompt 1 — Dashboard

"Design a premium mobile personal finance dashboard inspired by Copilot Money and Monarch Money. Calm, minimal, modern, privacy-first. Large net worth hero card, account summary cards, budget rings, recent transactions, subtle charts, soft shadows, large spacing, Inter typography, dark mode, minimal visual clutter, iOS-quality polish, modern fintech app UI."

---

## Prompt 2 — Add Transaction Flow

"Design a mobile add transaction flow for a modern personal finance app. FAB opens quick actions: Quick Add (natural language), Voice Input, OCR Scan, Manual Entry. Minimal steps, ultra-fast entry, soft surfaces, premium spacing, Copilot Money inspired, dark mode, elegant typography, transaction confirmation UX."

---

## Prompt 3 — Transactions Screen

"Design a modern transactions screen for a mobile finance app inspired by Monarch Money and Copilot. Tabs for Expenses, Income, Transfers. Filters for One-time, Recurring, Installments, Debt. Large spacing, soft cards, premium dark mode, subtle category icons, calm visual hierarchy, high-end fintech UI."

---

## Prompt 4 — Budget Screen

"Design a premium budgeting screen for a mobile finance app. Category budget progress rings, monthly spending summaries, drilldown cards, soft gradients, minimal clutter, calm fintech design, large typography, dark mode, inspired by Copilot Money and modern Apple-style UI."

---

## Prompt 5 — Design System Exploration

"Create a complete design direction for a premium offline-first AI-assisted personal finance app. Style inspired by Copilot Money, Monarch Money, and Impeccable. Focus on typography, spacing, color system, surfaces, cards, charts, transaction rows, FAB interactions, dark mode, calm premium fintech aesthetics."

---

# Final Recommendation

Your strongest direction is:

- Copilot’s calm UX
- Monarch’s information structure
- Impeccable’s polish
- your own offline/privacy-first identity

That combination is extremely strong.


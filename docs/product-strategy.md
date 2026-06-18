# Personal Finance App – Product Discovery Summary

## Vision Statement
Help people build financial clarity and confidence through a simple, privacy-first, beginner-friendly personal finance app.

---

# Product Principles

- Beginner-friendly
- Manual-first
- Privacy-first
- Offline-first
- AI optional
- Local AI only
- Fast transaction recording
- Calm UX
- Household-capable, individual-first
- No accounting complexity
- No enterprise workflows

---

## Personas

### Primary Persona
Early-career professionals (22–35)

Characteristics:
- salaried employees
- e-wallet heavy
- little/no budgeting habit
- intimidated by spreadsheets
- wants financial clarity
- uses multiple wallets/accounts

Goals:
- understand spending
- budget better
- save consistently
- track debts/lending
- reduce financial anxiety

Pain Points:
- scattered finances
- inconsistent tracking
- confusing budgeting apps
- salary disappears quickly


### Secondary Persona

Couples/shared households

Needs:
- shared budgets
- shared expenses
- mine/theirs/ours visibility
- shared goals

Architecture should support this early, but UX remains individual-first.

### Tertiary Persona

Freelancers / side-hustlers

Characteristics:
- irregular income
- multiple income streams
- manual-heavy tracking

Not primary UX target.

### Anti-Personas

### Payroll Operators
Users expecting:
- payslip generation
- payroll compliance
- HR workflows

### Professional Accountants
Users expecting:
- double-entry bookkeeping
- journal entries
- audit systems
- chart of accounts

### Enterprise Finance Teams
Users expecting:
- approvals
- ERP integrations
- procurement systems

### Investment/Trading Power Users
Users expecting:
- realtime brokerage integrations
- advanced investment analytics
- tax lot tracking

---

# Jobs To Be Done (JTBD)

1. Understand where money goes
2. Know how much money can safely be spent
3. Record transactions in seconds
4. Reduce financial anxiety
5. Track shared finances simply
6. Track debts/lending
7. Build better financial habits
8. Understand salary breakdowns

---

# Core Features


## Authentication

Passwordless email OTP:
- enter email
- receive code
- verify
- login/signup

## Onboarding

- 3-page intro carousel
- AI opt-in onboarding
- guided first account creation
- guided first transaction

## Accounts
- Manual account creation
- Asset accounts
- Liability accounts
- Shared/private ownership
- Stored balances with transaction-derived updates

### Supported
Assets:
- cash
- bank
- e-wallet
- savings
- investments
- crypto

Liabilities:
- credit cards
- loans
- BNPL

### Account Philosophy

- stored + derived balance hybrid
- transactions remain source of truth
- hidden opening balance transaction

## Transactions

### Types

- Expense
- Income
- Transfer

### Features
- manual entry
- OCR entry
- natural language parsing
- voice input support
- recurring templates
- transfer support
- payees/merchants
- notes/descriptions

### Philosophy

- save-confirm flow
- no review queue needed
- deterministic parsing first
- AI fallback only if ambiguous
- transactions should take seconds

### Transaction Fields

- amount
- type
- account
- category
- payee
- note
- occurred_at

### Payees

Separate normalized entity.

Purpose:
- analytics
- recurring detection
- subscriptions
- search
- categorization

Examples:
- McDonald's
- Grab
- Spotify

### Notes

Human contextual descriptions and/or ocr text.

Examples:
- lunch with team
- airport trip

### Natural Language Parsing

Examples:
- mcdo 250 gcash
- lunch 250
- salary 45k tax 5k

Deterministic parser first.
AI fallback only if ambiguous.

### Voice Input

Supported.

## OCR Flow

1. scan receipt
2. OCR extraction
3. autofill fields
4. user adjusts
5. save transaction

## Income Deductions

Supports:
- tax withholding
- SSS
- PhilHealth
- Pag-IBIG
- insurance
- custom deductions

Modeled as:
- parent income transaction
- child breakdown entries

No payroll engine.

## Transfers

Dedicated transfer entity.

Effects:
- subtract source account
- add destination account
- excluded from spending reports

Credit card payments are transfers.

Transfer fees become expense transactions.

## Interest Philosophy

Interest treated as transactions.
No automatic accrual engine initially.

## Budgets

- category-based
- monthly-first
- advisory, not restrictive
- belongs to user or household

Supports:
- manual setup
- suggested budgets later

## Borrow / Lend

Separate debt domain.

### Social Debt
Stored in debt_records table.

Supports:
- lent
- borrowed
- partial repayments
- reminders
- optional user linking

Visibility remains private unless shared explicitly.

### Institutional Debt
Handled through liability accounts.

Examples:
- credit cards
- car loans
- BNPL
- lending apps

## Goals

Supports:
- savings goals
- debt payoff goals
- emergency funds
- travel
- custom goals

Ownership:
- user
- household

Manual contribution first.

## Recurring Transactions

Types:
- recurring expense
- recurring income
- subscriptions
- installments
- reminder-only

Recurring engine creates templates, not finalized transactions automatically.

---

# Dashboard

Structure:
- greeting
- net worth hero card + graph
- compact income/expense/savings summaries
- spending category pie chart
- budget rings
- recent transactions
- FAB for add transaction

Dashboard philosophy:
- glanceable
- emotionally calm
- lightweight

# Reports & Analytics

MVP Reports:
- spending by category
- income vs expense
- net worth trend
- account balances
- budget performance

All graphs should support drilldowns into transactions.

CSV export enough initially.

# Notifications

## Local Notifications
Work fully offline:
- bills due
- subscriptions
- installments
- debt reminders
- transaction reminders
- recurring reminders

Configurable by user.

Avoid guilt-based engagement tactics.

## Cloud Push Notifications
Future use only:
- household events
- sync events
- multi-device notifications

---

# AI Scope

## AI Philosophy

- AI optional
- fully local/on-device
- downloadable models
- offline-capable
- explainable
- never mutates finances automatically

Core functionality must work without AI.

---

## V1 AI
- OCR extraction
- smart categorization
- natural language transaction parsing
- voice-to-transaction input

---

## Future AI
- financial insights
- semantic search

---

## AI Runtime

Primary direction:
- llama.cpp
- GGUF quantized models
- on-device inference

Potential models:
- Gemma 4 E4B IT
- Qwen small models
- Phi

No cloud AI dependency.

No AI backend orchestration service.

---

# Privacy & Data Philosophy

- privacy-first
- local-first
- no bank credentials stored
- no bank tokens stored
- AI optional
- offline-first
- calm trust-oriented messaging

---

# Offline-First Philosophy

App works fully offline:
- transactions
- budgets
- reports
- accounts
- goals
- local notifications
- local AI inference

Local database is primary runtime source.

Future cloud supports:
- backups
- sync
- multi-device support
- household sharing
- push notifications

---

# Sync Philosophy

Future sync engine needs:
- UUIDs
- updated_at
- deleted_at
- sync_status
- last_synced_at

---

# Technical Principles

- local DB as runtime source
- fast local reads
- optimistic UI
- modular domains
- backend initially lightweight
- AI only suggests/extracts
- server acts primarily as sync layer

---

# Authentication

Authentication should NOT block app usage.

## Local Mode
User can:
- use app immediately
- remain offline-only
- skip account creation

## Cloud Mode
Optional signup enables:
- backups
- sync
- household sharing

Recommended auth:
- passwordless email OTP
- email → code → login/signup

Reason:
- lower friction
- mobile-friendly
- modern UX

---

# UX Principles

- transactions should take seconds
- low friction
- no accounting terminology exposed
- calm visual language
- avoid overwhelming dashboards

---

# V1 Scope

## Included
- manual accounts
- transactions
- transfers
- categories
- payees
- notes/descriptions
- monthly budgets
- recurring templates/reminders
- debt tracking
- goals
- local notifications
- basic reports
- OCR extraction
- smart categorization
- offline-first architecture
- local AI support
- voice input
- optional email OTP auth

## Excluded
- bank integrations
- investment tracking
- advanced automation
- desktop app
- APIs/webhooks
- advanced forecasting
- AI financial coaching
- realtime collaboration

---

# Recommended Tech Stack

## Mobile App

### Framework
- Flutter

### State Management
- Riverpod

### Local Database
- SQLite
- Drift ORM

### Local Storage Philosophy
- SQLite is primary runtime database
- app fully functional offline
- backend acts as sync/backup layer only

---

# Backend Architecture

## Primary Backend
- NestJS
- REST API initially

Responsibilities:
- optional authentication
- sync APIs
- household sharing
- backups
- file uploads

Backend should NOT compute:
- balances
- dashboards
- analytics
- budget summaries

These are computed locally.

---

# Cloud Database

## Database
- PostgreSQL

Purpose:
- sync persistence
- backups
- multi-device sync
- household data

---

# OCR Stack

## Recommended
- Google ML Kit

Flow:
- image scan
- OCR extraction
- AI/rules parsing
- autofill transaction
- user confirms
- save transaction

Fully on-device capable.

---

# Sync Architecture

## Sync Model
- local-first
- pull/push HTTP sync initially
- periodic sync
- reconnect sync
- foreground sync

Avoid WebSockets initially.

### Required Sync Fields
Every syncable entity should contain:
- id (UUID)
- created_at
- updated_at
- deleted_at
- sync_status
- last_synced_at

---

# Infrastructure

## Deployment
- Docker
- VPS/Hetzner initially
- GitHub Actions

## Monitoring
- Sentry

## Push Notifications
- Firebase Cloud Messaging (future cloud sync use cases)

---

# Architecture Discussions Next

1. Domain models
2. Database schema
3. Sync engine design
4. Conflict resolution strategy
5. Mobile navigation architecture
6. State management structure
7. Notification architecture
8. Multi-tenant/household model
9. Security model
10. Deployment strategy

---

# Remaining Future Work

1. API contracts
2. Database schema
3. Sync conflict strategy
4. Design system
5. Navigation architecture
6. State management
7. MVP prioritization
8. Roadmap/phases
9. Monetization
10. QA/testing strategy
11. Observability/logging
12. CI/CD
13. App store launch strategy

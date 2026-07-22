# Navigation & Routing — Personal Finance App

Screen tree, navigation structure, modal flows, and route definitions for the Flutter app.

References: `product-strategy.md` (features, UX principles), `domain-model.md` (dashboard layout, transaction screen structure), `database-schema.md` (entities), `sync-engine.md` (sync status UI).

---

## 1. Design Principles

| Principle | Rationale |
|---|---|
| **4 tabs + rightmost Add island** | Dashboard, Transactions, Budgets, More — plus Add as a separate elevated island at the rightmost with accent background. Add is always one tap away. |
| **Dashboard is home** | First thing users see. One headline number + glanceable cards, never a blank screen. |
| **More tab as hub** | Secondary features (accounts, debts, goals, reports, settings) grouped logically. Prevents tab bar clutter. |
| **Sheets for creation, pages for detail** | Create/edit flows use bottom sheets (quick, dismissible). Detail views use pushed pages (full context). |
| **No more than 3 taps to any feature** | From dashboard, any screen reachable in ≤3 taps. |
| **Calm, not gamified** | No badges, streaks, or guilt indicators in navigation. Notifications are informational, not engagement-bait. |
| **Save-first, correction-friendly** | No review queue. Transactions save immediately. Undo snackbar (5s) on every save. |
| **Empty states are actionable** | Every empty screen shows an illustration, a one-sentence explanation, and a primary CTA. Optional demo data for exploration. |
| **Semantic color-only feedback** | Green = on track, amber = warning, red = overspent. No exclamation text or guilt language. |

---

## 2. Navigation Structure Overview

```
┌──────────────────────────────────────────────────────────────┐
│                 APP SHELL                                     │
│  ┌─────────────────────────────────────────────────────┐    │
│  │         Top Bar (contextual)                         │    │
│  │  [← back]   Title    [sync icon] [⋮]                │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │                                                     │    │
│  │           Active Tab Content                        │    │
│  │           (scrollable)                              │    │
│  │                                                     │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │ [Dash] [Trans] [Budgets] [More]       ┌───────┐    │    │
│  │                                       │  +    │    │    │
│  │                                       └───────┘    │    │
│  │                                    Add island       │    │
│  │                                  (accent bg)        │    │
│  └─────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

### Bottom Tab Bar

| # | Tab | Icon | Label | Behavior |
|---|---|---|---|---|
| 1 | Dashboard | home | Home | Tap → Dashboard tab |
| 2 | Transactions | list | Transactions | Tap → Transactions tab |
| 3 | Budgets | chart | Budgets | Tap → Budgets tab |
| 4 | More | grid | More | Tap → More tab |

### Add Island (rightmost)

| Element | Icon | Behavior |
|---|---|---|
| **Add button** | **plus** | **Tap → Quick Actions Bottom Sheet** |

The **Add island** sits at the rightmost of the tab bar, visually separated from the 4 tabs. It has an **accent color background**, is **elevated**, and uses a **larger icon**. It does not represent a page — tapping it opens the **Quick Actions Bottom Sheet** without changing the active tab. The previously active tab remains selected.

Tab state (scroll position, filter state) is preserved when switching tabs via Riverpod providers scoped per tab.

### Add Island → Quick Actions Bottom Sheet

Tapping the Add island opens a **Quick Actions Bottom Sheet**:

```
┌─────────────────────────────┐
│        Add Transaction      │
│                             │
│  ┌───────────────────────┐  │
│  │ mcdo 250 gcash    🎤  │  │  ← NL input with mic toggle
│  └───────────────────────┘  │
│                             │
│  ┌─────────┐ ┌─────────┐   │
│  │ Manual  │ │  Scan   │   │
│  └─────────┘ └─────────┘   │
└─────────────────────────────┘
```

| Action | Icon | Behavior |
|---|---|---|
| **Quick Add (NL)** | keyboard | Primary input field. Type natural language → parse → preview card → confirm → save. Tap 🎤 to toggle voice input mode. Sheet stays open for rapid entry. |
| **Manual** | pencil | Opens full transaction form sheet (all fields). Save → close sheet → undo snackbar. |
| **Scan** | camera | Opens full-screen camera → capture → OCR processing → autofill form sheet → adjust → save. |

**Mic toggle**: Inside the Quick Add input field, a 🎤 microphone icon toggles between text and voice input. In voice mode, tapping the field starts listening → transcribe → parse → preview → confirm → save.

**Undo snackbar**: After every save, a bottom snackbar appears: "Transaction saved · UNDO". Tapping undo reverts the save (deletes the record, restores previous balances). Auto-dismisses after 5 seconds.

---

## 3. Tab 1: Dashboard (Home)

The glanceable summary screen. Vertically scannable, emotionally calm. Inspired by PocketGuard's "In My Pocket" and Monarch's widget cards.

### Layout (top to bottom)

| # | Section | Tap target | Source |
|---|---|---|---|
| 1 | Greeting + date | — | product-strategy.md |
| 2 | **Safe-to-Spend hero card** — one large number showing available cash after budgets & bills | — | Research: PocketGuard "In My Pocket" |
| 3 | Net worth sparkline card (mini line chart, 30 days) | → Reports: Net worth detail | domain-model.md §688 |
| 4 | Account summary cards (horizontal scroll, 3–4 visible) | → Account detail | domain-model.md §689 |
| 5 | Income vs expense strip (current month, horizontal bar) | → Reports: Income vs expense | domain-model.md §690 |
| 6 | Budget progress rings/cards (top 3–4 overspent or closest to limit) | → Budgets tab | domain-model.md §691 |
| 7 | Spending by category donut chart (current month) | → Reports: Spending by category | Research: Copilot/Monarch |
| 8 | Recent transactions (last 5, with "See all" link) | → Transactions tab | domain-model.md §692 |
| 9 | Upcoming recurring / bills (next 7 days) | → Recurring list | Research: Monarch bill calendar |
| 10 | Insights / AI section (future, collapsible) | → Insights detail | domain-model.md §693 |

**Empty state**: If no accounts exist, show a centered illustration (friendly character), text "Let's set up your first account", and a primary CTA "Add Account". Optional secondary link "Try with demo data" that seeds 30 days of sample transactions, accounts, and budgets.

### Top bar elements

| Element | Position | Behavior |
|---|---|---|
| Sync status icon | Right | Tap → Sync status sheet. Shows last_synced_at, pending count, failed count, retry button. |
| Search icon | Right | Tap → Global search (transactions, payees, categories). |

### Pull-to-refresh

Triggers immediate sync cycle (see `sync-engine.md` §2). Shows refresh indicator. If offline, shows subtle "Offline — will sync when connected" text.

---

## 4. Tab 2: Transactions

The unified transaction list. All transactions in one scrollable list — expenses, income, and transfers together. Filterable via a single filter button. Inspired by Monarch's clean searchable list and Copilot's grouped date layout.

### Screen structure

```
┌─────────────────────────────────┐
│  🔍 Search...        [🔧]       │
├─────────────────────────────────┤
│                                 │
│  Today                          │
│  ┌─────────────────────────┐   │
│  │ 🍔 McDonald's    -₱250  │   │  ← Expense (red)
│  │    Food · GCash         │   │
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │ 💰 Salary        +₱45k  │   │  ← Income (green)
│  │    Income · BPI         │   │
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │ ↕️ BPI → GCash   -₱500  │   │  ← Transfer (blue)
│  │    Transfer · BPI       │   │
│  └─────────────────────────┘   │
│                                 │
│  Yesterday                      │
│  ┌─────────────────────────┐   │
│  │ 🚗 Grab           -₱180 │   │
│  │    Transport · GCash    │   │
│  └─────────────────────────┘   │
│                                 │
│                        ┌────┐  │
│                        │ +  │  │  ← Add island
│                        └────┘  │
└─────────────────────────────────┘
```

### Search bar

Persistent search bar at the top left of the Transactions tab. Filters in real-time across:
- Payee name (fuzzy match)
- Category name
- Amount (exact or range)
- Note text

Tapping the search bar expands it full-width and shows recent searches.

### Filter button (🔧)

Tapping the filter button (top right, wrench/funnel icon) opens a **Filter Sheet**:

```
┌─────────────────────────────────┐
│  Filters                    ✕   │
├─────────────────────────────────┤
│                                 │
│  Direction                      │
│  [All] [Expense] [Income]       │
│  [Transfer]                     │
│                                 │
│  Mode                           │
│  [All] [One-time] [Recurring]   │
│  [Installment] [Debt]           │
│                                 │
│  Account                        │
│  [All] [BPI] [GCash] [Cash]     │
│                                 │
│  Category                       │
│  [All] [Food] [Transport] ...   │
│                                 │
│  Amount Range                   │
│  [Min] — [Max]                  │
│                                 │
│  Date Range                     │
│  [Start] — [End]                │
│                                 │
│  [Clear All]      [Apply]       │
│                                 │
└─────────────────────────────────┘
```

| Filter | Options | Source |
|---|---|---|
| Direction | All, Expense, Income, Transfer | domain-model.md §552-554 |
| Mode | All, One-time, Recurring, Installment, Debt | domain-model.md §558-561 |
| Account | All, or specific account(s) | database-schema.md |
| Category | All, or specific category(s) | database-schema.md |
| Amount Range | Min / Max input | — |
| Date Range | Start / End date picker | — |

Multiple filters combine with AND logic. "Clear All" resets to default. "Apply" closes sheet and refreshes list.

### Transaction row

Each row shows:
- **Left**: Category icon or payee initial (circular avatar)
- **Center**: Payee name (bold), category + account (secondary)
- **Right**: Amount (bold, color-coded: **red** for expense, **green** for income, **blue** for transfer)
- **Direction badge**: Small text label or color indicating direction (expense/income/transfer)

**Swipe actions** (from row):
- **Swipe left**: Edit (pencil) → opens edit sheet | Delete (trash) → confirmation dialog
- **Swipe right**: Categorize (tag) → opens category picker sheet | Duplicate → creates copy

Tapping a row → **Transaction Detail** (pushed page).

### Grouping

Transactions grouped by date (Today, Yesterday, this week, this month, older). Within each group, sorted by `occurred_at` descending.

### Income deduction rows

Salary transactions with child deductions show an expand indicator (chevron). Tap → expands inline to show deduction breakdown (tax, SSS, PhilHealth, etc.). Tap again → collapse.

### Empty state

If no accounts exist:
- Illustration (empty wallet)
- "You need an account to track transactions"
- "Add your first account to get started"
- Primary CTA: "Add Account" (opens Account Creation sheet)
- Secondary: "Try demo data"

If accounts exist but no transactions:
- Illustration (empty envelope)
- "No transactions yet"
- "Tap the + button to add your first transaction"
- Primary CTA: "Add Transaction" (opens Add sheet)
- Secondary: "Try demo data"

---

## 5. Tab 3: Budgets

Monthly category budgets with progress visualization. Inspired by YNAB's month navigation and Monarch's progress bars.

### Screen structure

```
┌─────────────────────────────────┐
│  ◀ June 2026 ▶     Budgets  [+] │
├─────────────────────────────────┤
│                                 │
│  Spent ₱12,500 of ₱20,000       │  ← Monthly summary
│  ████████████░░░░░░  63%        │
│                                 │
│  ┌─────────────────────────┐   │
│  │ 🍔 Food          ₱5,200 │   │  ← Tap → Budget detail
│  │ ████████░░░░  ₱8,000    │   │     Amber = close to limit
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │ 🚗 Transport     ₱1,800 │   │
│  │ ████░░░░░░░░  ₱3,000    │   │
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │ 🎬 Entertainment  ₱2,500│   │  ← Over budget = soft red
│  │ ████████████░  ₱3,000   │   │     No guilt text, just color
│  └─────────────────────────┘   │
│                                 │
│  No budget set                  │
│  ┌─────────────────────────┐   │
│  │ 🏠 Rent          ₱0     │   │  ← Tap → Create budget sheet
│  │ Set a budget            │   │
│  └─────────────────────────┘   │
│                                 │
└─────────────────────────────────┘
```

### Month navigation

Swipe left/right or tap arrows to navigate months. State: `month` + `year`. Month label format: "June 2026". Current month is highlighted.

### Budget row

| Element | Display |
|---|---|
| Category icon + name | Left |
| Spent amount | Right (primary) |
| Progress bar | Below, colored by status |
| Budget amount | Right (secondary, muted) |

**Progress bar colors** (semantic, calm):

| Status | Color | Condition | Haptic |
|---|---|---|---|
| On track | emerald | spent < 80% of budget | None |
| Warning | amber | spent 80–100% of budget | Light tap when crossing 80% |
| Over budget | soft red | spent > 100% of budget | Light tap when crossing 100% |

No guilt language. Just color. No "over budget!" alert text.

**Rollover indicator**: If a category has rollover enabled and carries a balance from previous month, show a small "+₱X from last month" label below the progress bar in muted text.

### Tap budget row → Budget Detail (pushed page)

Shows:
- Category name + icon
- Spent vs budget (large numbers)
- Progress bar (full width)
- Rollover info (if applicable)
- All transactions in this category for the month (scrollable list, same row style as Transactions tab)
- Edit budget button (pencil)
- Delete budget button (trash, with confirmation)

### [+] button → Budget Creation/Edit Sheet

Select category (from unbudgeted categories) → enter monthly amount → toggle rollover (on/off) → save.

### Empty state

If no budgets set for the month:
- Illustration (empty chart)
- "You haven't set any budgets for June"
- "Budgets help you stay on track without stress"
- Primary CTA: "Create First Budget" (opens creation sheet)
- Secondary: "Auto-suggest budgets" (AI or heuristic suggestion based on last 3 months average spending per category)

---

## 6. Tab 4: More

Hub for all secondary features. Grouped into sections for scannability.

### Screen structure

```
┌─────────────────────────────────┐
│           More                  │
├─────────────────────────────────┤
│                                 │
│  FINANCIAL                      │
│  ┌─────────────────────────┐   │
│  │ 👤 Accounts         >   │   │
│  │ 🤝 Debts & Lending  >   │   │
│  │ 🎯 Goals            >   │   │
│  │ 🔁 Recurring        >   │   │
│  └─────────────────────────┘   │
│                                 │
│  INSIGHTS                       │
│  ┌─────────────────────────┐   │
│  │ 📊 Reports          >   │   │
│  │ 💡 Insights (AI)    >   │   │
│  └─────────────────────────┘   │
│                                 │
│  MANAGE                         │
│  ┌─────────────────────────┐   │
│  │ 🏷️ Categories       >   │   │
│  │ 🏪 Payees           >   │   │
│  │ 👨‍👩‍👧 Households       >   │   │
│  └─────────────────────────┘   │
│                                 │
│  SETTINGS                       │
│  ┌─────────────────────────┐   │
│  │ ⚙️ Profile & Prefs   >   │   │
│  │ 🔔 Notifications     >   │   │
│  │ 🤖 AI & Data         >   │   │
│  │ ☁️ Cloud Sync        >   │   │
│  │ 🌙 Appearance        >   │   │  ← Light / Dark / System
│  │ 🔒 Security          >   │   │  ← Future (biometric, encryption)
│  │ ℹ️ About             >   │   │
│  └─────────────────────────┘   │
│                                 │
└─────────────────────────────────┘
```

### Section: Financial

#### Accounts
- **Accounts list** (pushed): All accounts grouped by Asset / Liability. Shows name, type, balance. Archived accounts in separate section. Hidden accounts toggle.
- Tap account → **Account Detail** (pushed): Balance, balance history graph (from `account_balance_snapshots`), transaction list filtered by account, edit/archive/hide actions.
- [+] → **Account Creation** (sheet): Select type (asset/liability subtype), name, opening balance, currency, ownership (personal/shared).

#### Debts & Lending
- **Debt list** (pushed): Grouped by `counterparty_name`. Each group shows net balance (SUM of lent remaining − SUM of borrowed remaining). Expandable to show individual debt records.
- Tap debt → **Debt Detail** (pushed): Counterparty, direction, amount, remaining balance, due date, status, note. Actions: record payment, mark settled, edit.
- [+] → **Debt Creation** (sheet): Counterparty name, direction (lent/borrowed), amount, due date, note.

#### Goals
- **Goals list** (pushed): Cards with progress rings. Shows name, target, current, target date. Filter by type.
- Tap goal → **Goal Detail** (pushed): Progress, contribution history, edit, contribute button.
- [+] → **Goal Creation** (sheet): Name, type, target amount, target date.

#### Recurring
- **Recurring list** (pushed): Templates grouped by type (recurring expense, recurring income, subscriptions, installments, reminder-only). Shows next occurrence date.
- Tap template → **Recurring Detail** (pushed): All fields, next occurrences preview, edit, delete. "Create transaction now" button (manual trigger).
- [+] → **Recurring Creation** (sheet): Account, category, payee, amount, recurrence rule, reminder toggle.

### Section: Insights

#### Reports
- **Reports hub** (pushed): 5 report cards.
  1. Spending by category → donut chart + drilldown
  2. Income vs expense → bar chart + drilldown
  3. Net worth trend → line graph + drilldown
  4. Account balances → summary cards + drilldown
  5. Budget performance → progress overview + drilldown
- Tap report → **Report Detail** (pushed): Full chart with period selector (month/quarter/year). Tap chart segment → **Transaction list** (pushed, filtered).
- Export button → CSV export sheet.

#### Insights (AI)
- **Insights list** (pushed): AI-generated observations (anomalies, spending trends, saving opportunities). Each insight is a card with explanation and affected transactions.
- Tap insight → **Insight Detail** (pushed): Full explanation, supporting data, dismiss / apply action.

### Section: Manage

#### Categories
- **Category list** (pushed): Grouped by `category_group` (expense, income, transfer). Hierarchical display (parent → child).
- Tap category → **Category Edit** (sheet): Edit name, icon, color.
- Seed categories marked with badge. Custom categories have delete option.

#### Payees
- **Payee list** (pushed): Alphabetical. Shows display_name, normalized_name, transaction count.
- Tap payee → **Payee Detail** (pushed): Transaction history, recurring detection, merge/deduplicate option.

#### Households
- **Household list** (pushed): List of households user belongs to. Shows name, member count, role.
- Tap household → **Household Detail** (pushed): Member list with roles, shared accounts/budgets/goals, invite button.
- Invite → **User Search Sheet**: Search by email → select → assign role.

### Section: Settings

#### Profile & Preferences
- **Profile screen** (pushed): Display name, email (read-only), currency code, locale, timezone. Edit fields → save.
- Logout button at bottom.
- "Delete account & reset data" button (destructive, confirmation dialog).

#### Notifications
- **Notification settings** (pushed): Toggle per notification type (recurring_reminder, bill_due, installment_due, debt_reminder, subscription_reminder). Time preference for daily summaries.

#### AI & Data
- **AI settings** (pushed): AI enabled toggle, model info, AI processing log (read-only list), data privacy info.
- **AI Processing Log** (pushed from AI settings): List of `ai_processing_logs` entries. Shows source_type, model_used, confidence_score, timestamp. Tap → payload detail.

#### Cloud Sync
- **Sync settings** (pushed): Shows "Cloud sync coming soon. Your data stays on your device." In V1, sync infrastructure is built but email authentication is disabled. The sync settings screen explains that cloud backup will be available in a future update.
- Manual sync button (disabled/greyed in V1).
- No authentication required in V1.

#### Appearance
- **Appearance settings** (pushed): Theme selection (Light / Dark / System). Preview card showing current theme. Applies immediately.

#### Security (Future)
- **Security settings** (pushed): Biometric lock toggle, auto-lock timer, local DB encryption info. Greyed out / "Coming soon" in V1.

#### About
- **About screen** (pushed): App version, build number, licenses, privacy policy, terms, links.

---

## 7. Modal Flows & Sheets

### 7.1 Add Transaction Flow (from Add island)

Add island tap → **Quick Actions Bottom Sheet** (see §2 for layout).

| Action | Flow |
|---|---|
| **Quick Add (NL + Voice)** | Type natural language or tap 🎤 for voice → parse → preview card → confirm → save. Sheet stays open for rapid entry. Dismisses on swipe down or tap outside. |
| **Manual** | Full transaction form sheet (all fields). Save → close sheet → undo snackbar. |
| **Scan (OCR)** | Full-screen camera → capture → OCR processing → autofill form sheet → adjust → save. |

All flows end with: save transaction → update account balance → close sheet → show undo snackbar (5s).

### 7.2 Transaction Edit Flow

From Transaction Detail → edit button → **Transaction Edit Sheet** (same form as manual entry, pre-filled).

Edit rules (from `domain-model.md` §240-252):
- Expense edit: refund previous amount → deduct new amount
- Income edit: deduct previous amount → add new amount
- Transfer edit: reverse previous transfer → apply updated transfer

### 7.3 Transfer Creation Flow

From Add island → Manual → direction = transfer. Or from Account Detail → transfer button.

**Transfer Form Sheet**: source account, destination account, amount, fee (optional), note, date. Save → update both account balances → if fee, create expense transaction → close.

### 7.4 OCR Scan Flow

```
Camera (full screen)
    ↓ capture
OCR Processing (loading overlay with progress)
    ↓ extract
Autofill Form Sheet (pre-filled with merchant, amount, date)
    ↓ user adjusts
Save Transaction
```

### 7.5 Onboarding Flow

First launch only. Can be skipped at any point. Not a login wall. No authentication required for V1.

```
Step 1: Intro Carousel (3 pages)
    ├─ Page 1: "Your money, simplified"
    ├─ Page 2: "Track everything in one place"
    └─ Page 3: "Budget without stress"
    ↓
Step 2: AI Opt-in
    ├─ Enable AI (recommended) → downloads model in background
    └─ Skip for now → can enable later in Settings
    ↓
Step 3: Create First Account (guided)
    ├─ Select account type (Cash, Bank, Credit Card, etc.)
    ├─ Enter name
    ├─ Enter opening balance
    └→ Dashboard with account created
    ↓
Step 4: Add First Transaction (guided, optional)
    ├─ Quick add tutorial (highlight the Add island)
    ├→ Transaction saved
    └→ Dashboard fully populated
```

**Onboarding empty state**: After onboarding, if the user skipped adding an account, the Dashboard shows the empty state with demo data CTA.

### 7.6 Authentication Flow (V2 — Sync)

> **V1 scope**: Authentication and cloud sync are **groundwork only**. The app is fully local-first in V1. Sync infrastructure (endpoints, tokens, sync engine) is built but email authentication is **disabled** until V2.
>
> In V1, the Cloud Sync settings screen shows: "Cloud sync coming soon. Your data stays on your device."

Future V2 flow (for reference):
```
Email Entry Screen
    ↓
OTP Verification Screen
    ↓
Auto-login/Signup
    ↓
Return to previous screen
```

Does NOT block app usage. User can cancel and continue in local mode.

---

## 8. Deep Link Mappings

Notification tap → target screen. All deep links use path-based URLs.

| Notification Type | Deep Link Path | Target Screen |
|---|---|---|
| `bill_due` | `/transactions?filter=installment` | Transactions tab, installment filter |
| `installment_due` | `/transactions?filter=installment` | Transactions tab, installment filter |
| `recurring_reminder` | `/recurring/{template_id}` | Recurring Detail |
| `debt_reminder` | `/debts/{debt_id}` | Debt Detail |
| `subscription_reminder` | `/recurring?filter=subscription` | Recurring list, subscription filter |
| `transaction_reminder` | `/transactions/new` | Add Transaction sheet |

### Sync status deep link

| Trigger | Deep Link Path | Target |
|---|---|---|
| Sync failed notification | `/settings/sync` | Sync settings screen |

---

## 9. Navigation Patterns

| Pattern | When to use | Example |
|---|---|---|
| **Push (full page)** | Detail views, drilldowns, settings | Transaction detail, account detail, report detail |
| **Bottom sheet** | Creation, editing, quick actions | Add transaction, edit budget, Add island menu, category picker, filter sheet |
| **Full-screen modal** | Camera, voice input, onboarding | OCR scan, voice input, intro carousel |
| **Tab switch** | Primary navigation between top-level domains | Dashboard → Transactions |
| **Inline expansion** | Grouped data within a list | Debt groups, income deduction breakdown |

### Back navigation

- Pushed screens: system back button or custom ← in top bar
- Sheets: swipe down or tap outside
- Full-screen modals: close (✕) button
- Tab switches: no back (tabs preserve state)

### State preservation

Each tab preserves its scroll position and filter state when switching tabs. Tab state is held in Riverpod providers scoped to the tab.

---

## 10. Route Definitions (Flutter go_router)

Uses `go_router` with `ShellRoute` for the bottom tab bar.

### Route tree

```
/ (ShellRoute — bottom tab bar)
├── /                        ← Tab 1: Dashboard
├── /transactions            ← Tab 2: Transactions
│   └── /transactions/:id    ← Transaction Detail (pushed)
├── /budgets                 ← Tab 3: Budgets
│   └── /budgets/:id         ← Budget Detail (pushed)
├── /more                    ← Tab 4: More
│   ├── /more/accounts
│   │   └── /more/accounts/:id
│   ├── /more/debts
│   │   └── /more/debts/:id
│   ├── /more/goals
│   │   └── /more/goals/:id
│   ├── /more/recurring
│   │   └── /more/recurring/:id
│   ├── /more/reports
│   │   └── /more/reports/:type
│   ├── /more/insights
│   ├── /more/categories
│   ├── /more/payees
│   │   └── /more/payees/:id
│   ├── /more/households
│   │   └── /more/households/:id
│   ├── /more/settings
│   ├── /more/settings/notifications
│   ├── /more/settings/ai
│   │   └── /more/settings/ai/logs
│   ├── /more/settings/sync
│   ├── /more/settings/appearance
│   ├── /more/settings/security
│   └── /more/settings/about
│
├── /onboarding              ← Full-screen modal (first launch)
├── /transactions/new        ← Bottom sheet (add transaction)
└── /scan                    ← Full-screen modal (OCR camera)
```

### Modal routes

| Route | Presentation | Dismissal |
|---|---|---|
| `/onboarding` | fullScreen | cannot dismiss (must complete or skip) |
| `/transactions/new` | bottomSheet | swipe down |
| `/scan` | fullScreen | ✕ button |

### Query parameters

| Route | Param | Purpose |
|---|---|---|
| `/transactions` | `filter` | Mode filter: `one_time`, `recurring`, `installment`, `debt` |
| `/transactions` | `account` | Filter by account ID |
| `/transactions` | `direction` | Filter by direction: `expense`, `income`, `transfer` |
| `/more/reports/:type` | `period` | `month`, `quarter`, `year` |
| `/budgets` | `month`, `year` | Budget period |

---

## 11. Complete Screen Inventory

Every screen in the app, mapped to its source requirement.

### Tab screens (4)

| # | Screen | Tab | Route |
|---|---|---|---|
| 1 | Dashboard | 1 | `/` |
| 2 | Transactions | 2 | `/transactions` |
| 3 | Budgets | 3 | `/budgets` |
| 4 | More | 4 | `/more` |

### Pushed screens (detail & list)

| # | Screen | Route | Source |
|---|---|---|---|
| 5 | Transaction Detail | `/transactions/:id` | domain-model.md |
| 6 | Budget Detail | `/budgets/:id` | domain-model.md Prompt 4 |
| 7 | Accounts List | `/more/accounts` | product-strategy.md §Accounts |
| 8 | Account Detail | `/more/accounts/:id` | product-strategy.md §Accounts |
| 9 | Debts List | `/more/debts` | product-strategy.md §Borrow/Lend |
| 10 | Debt Detail | `/more/debts/:id` | product-strategy.md §Borrow/Lend |
| 11 | Goals List | `/more/goals` | product-strategy.md §Goals |
| 12 | Goal Detail | `/more/goals/:id` | product-strategy.md §Goals |
| 13 | Recurring List | `/more/recurring` | product-strategy.md §Recurring |
| 14 | Recurring Detail | `/more/recurring/:id` | product-strategy.md §Recurring |
| 15 | Reports Hub | `/more/reports` | product-strategy.md §Reports |
| 16 | Report Detail | `/more/reports/:type` | product-strategy.md §Reports |
| 17 | Insights List | `/more/insights` | product-strategy.md §AI Scope |
| 18 | Insight Detail | `/more/insights/:id` | product-strategy.md §AI Scope |
| 19 | Categories List | `/more/categories` | domain-model.md §Category |
| 20 | Payees List | `/more/payees` | domain-model.md §Payee |
| 21 | Payee Detail | `/more/payees/:id` | domain-model.md §Payee |
| 22 | Households List | `/more/households` | domain-model.md §Household |
| 23 | Household Detail | `/more/households/:id` | domain-model.md §Household |
| 24 | Profile & Preferences | `/more/settings` | api-contracts.md §3 |
| 25 | Notification Settings | `/more/settings/notifications` | product-strategy.md §Notifications |
| 26 | AI Settings | `/more/settings/ai` | product-strategy.md §AI Scope |
| 27 | AI Processing Log | `/more/settings/ai/logs` | domain-model.md §AIProcessingLog |
| 28 | Sync Settings | `/more/settings/sync` | sync-engine.md §9 |
| 29 | Appearance Settings | `/more/settings/appearance` | Research: dark mode standard |
| 30 | Security Settings | `/more/settings/security` | specs-backlog.md §6 (future) |
| 31 | About | `/more/settings/about` | — |

### Sheets & modals (15)

| # | Screen | Presentation | Route |
|---|---|---|---|
| 32 | Quick Actions Sheet (Add island) | bottomSheet | — (inline) |
| 33 | Add Transaction — Manual | bottomSheet | `/transactions/new` |
| 34 | Add Transaction — Quick Add (NL + Voice) | bottomSheet | `/transactions/new` |
| 35 | OCR Scan | fullScreen | `/scan` |
| 36 | Transaction Edit | bottomSheet | — (inline) |
| 37 | Budget Creation/Edit | bottomSheet | — (inline) |
| 38 | Account Creation | bottomSheet | — (inline) |
| 39 | Debt Creation | bottomSheet | — (inline) |
| 40 | Goal Creation | bottomSheet | — (inline) |
| 41 | Goal Contribution | bottomSheet | — (inline) |
| 42 | Recurring Creation | bottomSheet | — (inline) |
| 43 | User Search (household invite) | bottomSheet | — (inline) |
| 44 | Sync Status Sheet | bottomSheet | — (inline) |
| 45 | CSV Export Sheet | bottomSheet | — (inline) |
| 46 | **Filter Sheet** | bottomSheet | — (inline) |

### Onboarding (4)

| # | Screen | Presentation | Route |
|---|---|---|---|
| 47 | Intro Carousel (3 pages) | fullScreen | `/onboarding` |
| 48 | AI Opt-in | fullScreen | `/onboarding` (step 2) |
| 49 | Guided Account Creation | fullScreen | `/onboarding` (step 3) |
| 50 | Guided First Transaction | fullScreen | `/onboarding` (step 4) |

> **Auth screens (Email Entry + OTP) are V2 only.** Not included in V1 screen count.

**Total: 50 screens** (4 tab screens + 27 pushed screens + 15 sheets/modals + 4 onboarding)

---

## 12. Top Bar Behavior

| Screen | Left | Center | Right |
|---|---|---|---|
| Dashboard | — | Greeting + date | Sync icon, Search icon |
| Transactions | — | "Transactions" | Filter button (🔧), Search icon |
| Budgets | ← / → month nav | "Budgets" | + button |
| More | — | "More" | — |
| Pushed screens | ← back | Screen title | Contextual (edit, ⋮) |
| Sheets | — | Sheet title | ✕ close |

### Filter button (Transactions screen)

Tapping the filter button (🔧) opens the **Filter Sheet** (see §4 for full filter options).

### ⋮ menu (pushed screens)

Contextual ⋮ menu on pushed detail screens (Transaction Detail, Account Detail, etc.) with actions like Edit, Delete, Share, Export.

---

## 13. Sync Status UI

### Sync icon (top bar, Dashboard)

| State | Icon | Color |
|---|---|---|
| Synced | cloud-check | emerald |
| Pending | cloud-arrow-up | slate |
| Syncing | cloud-arrow-up (animated) | blue |
| Failed | cloud-exclamation | amber |
| Offline | cloud-off | slate |

Tap → **Sync Status Sheet** (bottomSheet):

```
┌─────────────────────────────────┐
│         Sync Status          ✕  │
├─────────────────────────────────┤
│                                 │
│  ✓ Last synced: 2 min ago       │
│                                 │
│  Pending: 3 changes             │
│  Failed: 0                      │
│                                 │
│  [ Sync Now ]                   │
│                                 │
│  Sync history                   │
│  ┌─────────────────────────┐   │
│  │ Today 2:34 PM  Success  │   │
│  │ Today 1:12 PM  Success  │   │
│  │ Yesterday     Failed    │   │
│  └─────────────────────────┘   │
│                                 │
│  Open sync settings >           │
│                                 │
└─────────────────────────────────┘
```

If `sync_failed_count > 0`, shows retry button and failed record list.

---

## 14. Household UX

### Mine / Theirs / Ours visibility

When viewing shared household data, transactions and accounts show an ownership indicator:

| Label | Meaning | Color |
|---|---|---|
| Mine | Owned by current user | blue |
| Theirs | Owned by another household member | slate |
| Ours | Shared (household_id set) | emerald |

### Permission-based UI

| Role | Can view | Can edit | Can delete |
|---|---|---|---|
| Owner | Everything | Everything | Everything |
| Member | Everything | Own + shared | Own only |
| Viewer | Everything | Nothing | Nothing |

Viewer role: Add island hidden, edit buttons hidden, creation buttons hidden.

---

## 15. Empty States & Demo Data

Every primary list screen has an empty state with:
1. **Illustration**: Simple, friendly vector (not photorealistic)
2. **Headline**: One sentence explaining the empty state
3. **Subtext**: One sentence explaining the value prop
4. **Primary CTA**: Action button to create the first item
5. **Secondary CTA (where applicable)**: "Try demo data" or "Learn more"

| Screen | Empty State CTA | Demo Data Available |
|---|---|---|
| Dashboard | "Add Account" | Yes — seeds accounts + 30 days transactions + budgets |
| Transactions | "Add Account" (if no accounts) or "Add Transaction" (if accounts exist) | Yes — uses same demo data |
| Budgets | "Create First Budget" | Yes — auto-suggest from demo transactions |
| Accounts | "Add Account" | Yes |
| Debts | "Add Debt" | No |
| Goals | "Add Goal" | No |
| Recurring | "Add Recurring" | No |
| Reports | "Add transactions to see reports" | Yes |

**Demo data**: Tapping "Try demo data" seeds the local DB with:
- 3 accounts (Cash, BPI Savings, GCash)
- 30 days of realistic transactions across common categories
- 4 budgets (Food, Transport, Entertainment, Rent)
- 2 recurring items (Salary, Netflix)
- Demo data is flagged with `is_demo = true` on all records. A "Clear demo data" button appears in Settings → Profile when demo data is present.

---

## 16. Industry References

Patterns adopted from market leaders:

| App | Pattern adopted | Where |
|---|---|---|
| **PocketGuard** | "Safe to Spend" hero number on dashboard | Dashboard |
| **PocketGuard** | Demo data for exploration | Empty states |
| **Copilot Money** | Spending line / calm visual tone, Add island quick actions | Dashboard, Add island |
| **Copilot Money** | Transaction list grouped by date with category icons | Transactions |
| **Monarch Money** | Net worth hero card with graph, account summary cards | Dashboard |
| **Monarch Money** | Budget progress with category drilldown | Budgets |
| **Monarch Money** | Recurring/subscriptions detection and list | Recurring |
| **Monarch Money** | Household collaboration with roles | Households |
| **Monarch Money** | Bill calendar / upcoming recurring on dashboard | Dashboard |
| **YNAB** | Month navigation on budgets (← / →) | Budgets |
| **YNAB** | Rollover budgets | Budgets |
| **Impeccable** | Typography hierarchy, spacing, card styling | Throughout |

### What we deliberately do differently

| Decision | Rationale |
|---|---|
| No bank integrations | Privacy-first, manual entry + OCR + NL parsing |
| No investment tracking tab | V1 scope exclusion. Investments are just an account type. |
| No review queue for transactions | Save-first, correction-friendly (domain-model.md §527) |
| No guilt-heavy budget alerts | Calm UX, color-only indicators |
| Offline-first, no login wall | App usable immediately, auth is opt-in |
| No gamification | Badges/streaks distract from actual financial awareness |
| Recently-added dot instead of "unreviewed" | Save-first model: transactions are trusted by default, new ones get a subtle highlight |

---

## 17. Responsive & Accessibility Notes

### Tablet layout
- Dashboard: 2-column grid for cards (hero card spans full width)
- Transactions: Master-detail split view (list left, detail right)
- Budgets: 2-column grid for budget cards
- More: 2-column grid for section cards

### Accessibility
- All icons paired with text labels (tab bar, Add island)
- Progress bars have aria-labels with percentage
- Color is never the sole indicator (paired with text/icons)
- Touch targets minimum 48×48dp
- Supports system font scaling
- Dark mode respects system preference by default

---

## 18. Data Migration and Backup Routes

Settings gains a visible **Data & backup** entry.

```text
/more/settings/data
├── /more/settings/data/import-cashew
├── /more/settings/data/import-cashew/:runId
└── /more/settings/data/imports/:runId
```

The hub exposes Import from Cashew, encrypted Lootr backup creation/restore, readable transaction CSV export, previous import summaries, preserved records, and a resume banner for nonterminal runs.

The import wizard is a full pushed page with Prepare, Choose, Analyze, Review, Reconcile, Apply, and Complete stages. It collects timezone and reversible title/payee policy in-app. Cancellation is available before publication; Apply/Verify uses `PopScope` to explain why the atomic step cannot be interrupted. Completion links to the latest imported month while restoring visible transaction filters.

Accessibility requirements: 48dp targets, semantic stage headings and “Step n of n,” phase-only live-region announcements, icon plus text statuses, accessible currency-partition lists, 200% text scaling, reduced motion, and focus on the first blocking review group. Screenshots and golden artifacts use synthetic/redacted data only.

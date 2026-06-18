# Task 14 — Presentation — More Tab & Settings

**Status:** [ ]

---

## Objective

Implement the More tab hub screen and all pushed screens: Accounts, Debts, Goals, Recurring, Reports, Insights, Categories, Payees, Households, and all Settings sub-screens.

References: `docs/navigation-arch.md §1 §6 §7`, `docs/design.md`, `docs/state-management.md`

## Dependencies

- 10 — Navigation Shell & Tab Bar
- 02 — Design System & Theme
- 07 — Application Layer — Riverpod Providers

## Deliverables

### 14.1 MoreScreen (`lib/presentation/screens/more/more_screen.dart`)
List-based screen with 4 sections, using `moreTabProvider`:

| Section | Items |
|---|---|
| **Financial** | Accounts, Debts & Lending, Goals, Recurring |
| **Insights** | Reports, Insights (tappable if AI enabled) |
| **Manage** | Categories, Payees, Households |
| **Settings** | Profile & Preferences, Notifications, AI & Data, Cloud Sync, Appearance, Security, About |

Each item is a `ListTile`-style row: icon + label + chevron → navigates to respective screen.

### 14.2 Accounts (`lib/presentation/screens/more/accounts_screen.dart`)
- List of all accounts grouped by type (Cash, Banks, E-Wallets, etc.)
- Each row: account name, type icon, balance
- Tap → `/more/accounts/:id`
- `+` button → account creation sheet

### 14.3 AccountDetailScreen (`lib/presentation/screens/more/account_detail_screen.dart`)
- Header: account name, balance (large, direction-aware if credit_card/loan)
- Transaction list: filtered to this account
- Edit/Archive actions

### 14.4 DebtsScreen (`lib/presentation/screens/more/debts_screen.dart`)
- List of all debt records grouped by status (Active, Partially Paid, Settled)
- Each row: counterparty name, amount, remaining balance, status badge
- Tap → `/more/debts/:id`
- `+` → debt creation sheet

### 14.5 DebtDetailScreen (`lib/presentation/screens/more/debt_detail_screen.dart`)
- Header: counterparty, direction (you lent / you borrowed), total, remaining
- Progress bar: paid vs total
- Related transactions (payments)
- Settle/Mark as partially paid actions

### 14.6 GoalsScreen (`lib/presentation/screens/more/goals_screen.dart`)
- List of all goals with progress bars
- Each row: goal name, target, current, progress %
- Tap → `/more/goals/:id`
- `+` → goal creation sheet

### 14.7 GoalDetailScreen (`lib/presentation/screens/more/goal_detail_screen.dart`)
- Large progress ring/bar, target amount, current amount, remaining
- Contribution history list
- "Add Contribution" button → contribution amount sheet

### 14.8 RecurringScreen (`lib/presentation/screens/more/recurring_screen.dart`)
- List of all recurring templates, sorted by next_occurrence_at
- Each row: payee, amount, frequency label, next date
- Tap → `/more/recurring/:id`
- `+` → recurring creation sheet

### 14.9 RecurringDetailScreen (`lib/presentation/screens/more/recurring_detail_screen.dart`)
- Template details: payee, amount, account, category, recurrence rule
- Next occurrence date
- Generated transaction history
- Edit/Delete/Disable actions

### 14.10 ReportsScreen (`lib/presentation/screens/more/reports_screen.dart`)
- Hub with 5 report types: Spending by Category, Income vs Expenses, Net Worth Over Time, Budget Performance, Cash Flow
- Each type: icon + label + description
- Tap → `/more/reports/:type?period=month`

### 14.11 InsightsScreen (`lib/presentation/screens/more/insights_screen.dart`)
- List of AI-generated insights (if AI enabled)
- Each insight: title, description, related data
- Tap → `/more/insights/:id`

### 14.12 CategoriesScreen (`lib/presentation/screens/more/categories_screen.dart`)
- List of all categories, grouped by category_group (expense, income, transfer)
- Each row: category icon, name, parent category indicator
- Edit option (rename, change icon/color)

### 14.13 PayeesScreen (`lib/presentation/screens/more/payees_screen.dart`)
- List of all payees, alphabetically sorted
- Each row: name, transaction count (or last used date)
- Tap → payee detail with transactions list

### 14.14 Settings sub-screens (`lib/presentation/screens/more/settings/`)

| Screen | Content |
|---|---|
| `profile_screen.dart` | Display name, email (read-only in V1), currency, locale, timezone |
| `notification_settings_screen.dart` | Toggle: recurring reminders, bill due, installment due, debt reminders |
| `ai_settings_screen.dart` | AI enabled/disabled toggle, model info, model download |
| `ai_logs_screen.dart` | List of `ai_processing_logs` rows, filterable by type |
| `sync_settings_screen.dart` | "Cloud sync coming soon" in V1; sync status, manual sync button (V2) |
| `appearance_screen.dart` | Theme mode (system/light/dark), font size, color scheme (future) |
| `security_screen.dart` | Biometric lock toggle, PIN (V1 placeholder) |
| `about_screen.dart` | App version, build number, licenses, privacy policy link |

## Acceptance Criteria

- [ ] More screen shows 4 sections with correct items, navigates to each pushed screen
- [ ] Accounts list — grouped by type, tap → detail, create sheet works
- [ ] Account detail — shows balance + filtered transaction list
- [ ] Debts list — grouped by status, debt direction shows "lent" vs "borrowed"
- [ ] Debt detail — settle/partially-pay updates remaining balance correctly
- [ ] Goals list — progress bars show correct %, tap → detail
- [ ] Goal detail — contribution flow adds to currentAmount
- [ ] Recurring list — sorted by next occurrence, status indicator
- [ ] Recurring detail — generated transaction history visible
- [ ] Reports hub — 5 report types listed, tap navigates to report
- [ ] Categories — grouped by group, edit icon/color works
- [ ] Payees — alphabetical, tap shows transactions
- [ ] All settings sub-screens accessible from More → Settings
- [ ] All routes resolve to correct screens
- [ ] Empty states for all list screens

## Files Likely Affected

- `lib/presentation/screens/more/more_screen.dart` (new)
- `lib/presentation/screens/more/accounts_screen.dart` (new)
- `lib/presentation/screens/more/account_detail_screen.dart` (new)
- `lib/presentation/screens/more/debts_screen.dart` (new)
- `lib/presentation/screens/more/debt_detail_screen.dart` (new)
- `lib/presentation/screens/more/goals_screen.dart` (new)
- `lib/presentation/screens/more/goal_detail_screen.dart` (new)
- `lib/presentation/screens/more/recurring_screen.dart` (new)
- `lib/presentation/screens/more/recurring_detail_screen.dart` (new)
- `lib/presentation/screens/more/reports_screen.dart` (new)
- `lib/presentation/screens/more/insights_screen.dart` (new)
- `lib/presentation/screens/more/categories_screen.dart` (new)
- `lib/presentation/screens/more/payees_screen.dart` (new)
- `lib/presentation/screens/more/households_screen.dart` (new)
- `lib/presentation/screens/more/settings/profile_screen.dart` (new)
- `lib/presentation/screens/more/settings/notification_settings_screen.dart` (new)
- `lib/presentation/screens/more/settings/ai_settings_screen.dart` (new)
- `lib/presentation/screens/more/settings/ai_logs_screen.dart` (new)
- `lib/presentation/screens/more/settings/sync_settings_screen.dart` (new)
- `lib/presentation/screens/more/settings/appearance_screen.dart` (new)
- `lib/presentation/screens/more/settings/security_screen.dart` (new)
- `lib/presentation/screens/more/settings/about_screen.dart` (new)
- `lib/application/providers/more_tab_provider.dart` (extended)
- `test/presentation/more/` (new)

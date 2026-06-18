# Task 11 — Presentation — Dashboard Tab

**Status:** [ ]

---

## Objective

Implement the Dashboard screen with all 10 sections specified in `docs/navigation-arch.md §2 §5`. The dashboard is the app's home screen and primary financial overview.

References: `docs/navigation-arch.md §2 §5`, `docs/design.md` (hero card, sparkline, progress bars), `docs/state-management.md` (dashboard providers)

## Dependencies

- 10 — Navigation Shell & Tab Bar
- 02 — Design System & Theme
- 07 — Application Layer — Riverpod Providers

## Deliverables

### 11.1 Dashboard screen (`lib/presentation/screens/dashboard/dashboard_screen.dart`)
Scrollable screen with 10 sections, top to bottom:

### 11.2 Greeting + Date header
- Dynamic greeting: "Good morning/afternoon/evening, {name}"
- Current date formatted: "Wednesday, June 18"
- Right side: Sync status icon (from `syncStatusIconProvider`)
  - `CloudCheck` green when synced, `CloudArrowUp` amber when pending, `CloudWarning` red when failed
  - Tap → opens `SyncStatusSheet`

### 11.3 Safe-to-Spend Hero Card
- Hero card component from design system
- Large display text (40px/700): "₱12,450.00"
- Subtitle: "Safe to spend"
- Subtext: "out of ₱50,000 monthly income"
- Color: green if > 50% remaining, amber if 20-50%, red if < 20%
- Tappable → opens breakdown sheet or transaction add

### 11.4 Net Worth Sparkline
- Small section: "Net worth" label + amount
- 30-day sparkline chart (2px stroke, primary-500)
- Subtext: "+3.2% this month" in success-600

### 11.5 Account Summary Cards
- Horizontal scrollable row of compact cards
- One card per active account
- Shows: account name, balance, account type icon
- Tap → navigates to `/more/accounts/:id`

### 11.6 Income vs Expense Strip
- Horizontal bar: income (green) and expense (red) as proportional widths
- "₱50,000 income · ₱37,550 expenses" text
- Current month only

### 11.7 Budget Progress Rings
- Horizontal scrollable row of budget progress circles
- Each shows: category icon/name, spent/total, progress ring (300ms ease-out animation)
- Color: green if under budget, amber near limit, red if over
- Tap → navigates to `/budgets/:id`

### 11.8 Spending by Category Donut
- Donut chart showing top 5 expense categories
- Legend list below with category color, name, amount, percentage
- "View all" link → navigates to reports
- Current month only

### 11.9 Recent Transactions
- Last 5-10 transactions
- Each uses `TransactionRow` component (40px circle avatar, amount, category, account)
- "See all" link → navigates to `/transactions`
- Amounts colored by direction: expense=red, income=green, transfer=blue

### 11.10 Upcoming Recurring / Bills
- List of next 3-5 upcoming recurring transactions/bills
- Shows: payee name, amount, due date (relative: "in 3 days")
- Tap → navigates to relevant detail or `/more/recurring`

### 11.11 Insights / AI (optional)
- Conditional section (shown only if AI enabled)
- 1-2 insight cards: "Your dining out is up 20% this month" etc.
- Tap → navigates to `/more/insights/:id`

### 11.12 Empty state
When no transactions/accounts exist:
- Centered empty state with illustration, "Welcome to Lootr", "Start by adding your accounts and transactions", primary "Add your first transaction" button

### 11.13 Loading state
- Shimmer placeholders matching section shapes
- No spinner-only loading (use skeleton UI)

## Acceptance Criteria

- [ ] All 10 sections render in correct order
- [ ] Safe-to-Spend hero shows correct computed value from provider
- [ ] Greeting changes by time of day (morning/afternoon/evening)
- [ ] Sync icon updates reactively from sync provider
- [ ] Account cards scroll horizontally with correct balances
- [ ] Budget progress rings show correct spent/total per budget
- [ ] Spending donut shows top 5 categories for current month
- [ ] Recent transactions list shows last 10 entries
- [ ] Upcoming recurring section shows next occurrences sorted by date
- [ ] Empty state renders when no data exists
- [ ] Loading skeleton renders while data fetches
- [ ] All sections are scrollable and testable independently
- [ ] Tapping account card navigates to account detail
- [ ] Tapping budget ring navigates to budget detail

## Files Likely Affected

- `lib/presentation/screens/dashboard/dashboard_screen.dart` (new)
- `lib/presentation/screens/dashboard/widgets/greeting_header.dart` (new)
- `lib/presentation/screens/dashboard/widgets/safe_to_spend_hero.dart` (new)
- `lib/presentation/screens/dashboard/widgets/net_worth_sparkline.dart` (new)
- `lib/presentation/screens/dashboard/widgets/account_summary_cards.dart` (new)
- `lib/presentation/screens/dashboard/widgets/income_expense_strip.dart` (new)
- `lib/presentation/screens/dashboard/widgets/budget_progress_rings.dart` (new)
- `lib/presentation/screens/dashboard/widgets/spending_donut.dart` (new)
- `lib/presentation/screens/dashboard/widgets/recent_transactions_list.dart` (new)
- `lib/presentation/screens/dashboard/widgets/upcoming_recurring_list.dart` (new)
- `lib/presentation/screens/dashboard/widgets/insights_section.dart` (new)
- `lib/presentation/screens/dashboard/widgets/dashboard_shimmer.dart` (new)
- `lib/application/providers/dashboard_provider.dart` (extended)
- `lib/application/providers/safe_to_spend_provider.dart` (extended)
- `lib/application/providers/net_worth_provider.dart` (extended)
- `test/presentation/dashboard/` (new)

# Task 12 — Presentation — Transactions Tab

**Status:** [ ]

---

## Objective

Implement the unified transaction list screen with filter bar, search, and transaction detail screen. The transaction list is the primary data surface — all transaction types (one_time, recurring, installment, debt) appear in one unified list.

References: `docs/navigation-arch.md §4 §9`, `docs/design.md` (transaction row, filter chips), `docs/state-management.md`

## Dependencies

- 10 — Navigation Shell & Tab Bar
- 02 — Design System & Theme
- 07 — Application Layer — Riverpod Providers

## Deliverables

### 12.1 TransactionsScreen (`lib/presentation/screens/transactions/transactions_screen.dart`)

**AppBar:**
- Title: "Transactions"
- Left: Filter button (funnel/wrench icon) → taps open `FilterSheet`
- Right: Search icon → expands inline search bar

**Filter bar (horizontal chip row):**
- Active filter chips below AppBar, horizontally scrollable
- Each chip: filter name + value + × to remove
- "Clear all" link on right side when any filter active

**Grouped transaction list:**
- Grouped by date (Today, Yesterday, This Week, This Month, Earlier)
- Each group has sticky `SectionHeader`
- Each row is `TransactionRow` component
- Swipe left → "Delete" (red) with undo snackbar
- Swipe right → "Edit" (blue) → opens edit form
- Pull-to-refresh triggers sync (if available)

**Empty state:**
- "No transactions yet"
- "Add your first transaction to start tracking"
- Primary button: "Add Transaction"

**TransactionRow for each item:**
- 40px circle: category icon or account icon
- Line 1: payee name or "Transfer to {account}"
- Line 2: category name + account name
- Right: amount (direction-colored), time

### 12.2 TransactionDetailScreen (`lib/presentation/screens/transactions/transaction_detail_screen.dart`)
Pushed route at `/transactions/:id`.

**Sections:**
1. **Header:** Amount (large, direction-colored), direction label, mode badge
2. **Details card:** Account, Category, Payee, Date + Time, Note (if present)
3. **Metadata:** Recurring template link (if applicable), Parent transaction link (if installment/deduction), Transfer details (if transfer)
4. **Actions:** Edit button, Delete button

**AppBar:** Title "Transaction", back arrow, edit icon button (top right)

### 12.3 Edit mode
- Tapping Edit opens the same form used by Add Transaction, pre-filled
- On save: `EditTransaction` use case → provider refresh → pop back to detail
- Handle balance reversals correctly

### 12.4 Delete with undo
- Tapping Delete shows confirmation dialog (or swipe-to-delete with undo)
- On confirm: `DeleteTransaction` use case → undo snackbar (5s) → pop back to list
- If undo tapped: restore transaction, recalc balance
- If undo expires: transaction stays soft-deleted

### 12.5 Search
- Inline search bar in AppBar
- Filters transactions by: payee name, note, amount (partial match)
- Real-time filtering (debounced 300ms)
- Clears search on back navigation

### 12.6 Loading state
- Shimmer list (skeleton rows matching transaction row shape)
- Sticky date headers visible during loading

## Acceptance Criteria

- [ ] Transactions list shows all transaction types (one_time, recurring, installment, debt, transfer) in one unified list
- [ ] List is grouped by date with sticky headers (Today, Yesterday, This Week, This Month, Earlier)
- [ ] Filter button opens FilterSheet with all filter options
- [ ] Active filter chips render below AppBar and can be individually removed
- [ ] Search filters by payee, note, and amount in real time
- [ ] TransactionRow shows correct icons, labels, and direction-colored amounts
- [ ] Swipe right → edit, swipe left → delete with undo snackbar
- [ ] TransactionDetailScreen shows all sections (header, details, metadata, actions)
- [ ] Edit form pre-fills with existing transaction data
- [ ] Delete triggers undo snackbar (5s); undo restores; expiry keeps soft-deleted
- [ ] Pull-to-refresh triggers sync attempt
- [ ] Empty state renders when no transactions exist
- [ ] Loading skeleton matches transaction row shape

## Files Likely Affected

- `lib/presentation/screens/transactions/transactions_screen.dart` (new)
- `lib/presentation/screens/transactions/transaction_detail_screen.dart` (new)
- `lib/presentation/screens/transactions/widgets/transaction_list.dart` (new)
- `lib/presentation/screens/transactions/widgets/transaction_row.dart` (new)
- `lib/presentation/screens/transactions/widgets/date_group_header.dart` (new)
- `lib/presentation/screens/transactions/widgets/filter_chip_bar.dart` (new)
- `lib/presentation/screens/transactions/widgets/transaction_search_bar.dart` (new)
- `lib/presentation/screens/transactions/widgets/transaction_shimmer.dart` (new)
- `lib/presentation/screens/transactions/widgets/transaction_detail_card.dart` (new)
- `lib/application/providers/transactions_tab_provider.dart` (extended)
- `lib/application/providers/transaction_filters_provider.dart` (extended)
- `lib/application/providers/filtered_transactions_provider.dart` (extended)
- `test/presentation/transactions/` (new)

# Task 16 — Presentation — Filter Sheet & Search

**Status:** [x]

---

## Objective

Implement the Filter Sheet (bottom sheet with all filter controls) and the search functionality used across the app. Filters apply to the transaction list and compose with each other.

References: `docs/navigation-arch.md` §4, `docs/design.md` (filter chips), `docs/state-management.md` (TransactionFilters)

## Dependencies

- 10 — Navigation Shell & Tab Bar
- 02 — Design System & Theme
- 07 — Application Layer — Riverpod Providers

## Deliverables

### 16.1 FilterSheet (`lib/presentation/sheets/filter_sheet.dart`)
Bottom sheet with sections:

| Section | Control |
|---|---|
| **Direction** | Segmented: All / Expense / Income / Transfer |
| **Mode** | Segmented: All / One-time / Recurring / Installment / Debt |
| **Account** | List of accounts, single-select, "All" default |
| **Category** | List of categories grouped by direction, single-select, "All" default |
| **Amount Range** | Min input + Max input, numeric keyboards |
| **Date Range** | Start date + End date, date pickers |

**Sheet footer:**
- "Clear all filters" text button (left)
- "Apply {n} filters" primary button (right), shows count of active filters

**Behavior:**
- Filters apply immediately on selection (no "Apply" for segmented/list controls)
- Amount and Date show "Apply" button
- Sheet dismisses on tap outside / swipe down
- Filter state persisted in `transactionFiltersProvider`

### 16.2 FilterChipBar
- Horizontally scrollable row of active filter chips
- Each chip: `FilterName: Value` with x button to remove
- "Clear all" link on the right when any filter active
- Uses `FilterChip` design system component

### 16.3 SearchInput component
- Pill-shaped search bar (radius-full)
- Leading magnifying glass icon
- Hint text: "Search transactions..."
- Clear button (x) when text present
- Debounced 300ms

### 16.4 Transaction search logic
- Integrated into `filteredTransactionsProvider`
- Searchable fields: payee name (displayName + normalizedName), note, amount
- Search combines with active filters (AND logic)
- Case-insensitive, accent-insensitive

### 16.5 Filter persistence
- Filters persist across tab switches (provider KeepAliveLinked)
- Filters reset on app restart (not persisted to disk)
- Provider notifies: `filteredTransactionsProvider` rebuilds on any filter change

## Acceptance Criteria

- [x] FilterSheet opens from Transactions screen filter button
- [x] All 6 filter sections render correctly
- [x] Direction and Mode segmented controls filter immediately
- [x] Account and Category lists filter immediately on tap
- [x] Amount range filter applies on "Apply" tap
- [x] Active filter chips render below AppBar with x dismiss
- [x] "Clear all" removes all filters and resets list
- [x] SearchInput filters transactions in real-time (debounced 300ms)
- [x] Search + filters compose with AND logic
- [x] Filters persist when switching tabs and returning

## Files Likely Affected

- `lib/presentation/sheets/filter_sheet.dart` (new)
- `lib/presentation/screens/transactions/widgets/filter_chip_bar.dart` (new)
- `lib/presentation/shared/components/inputs/search_input.dart` (new)
- `lib/application/providers/transaction_filters_provider.dart` (extended)
- `lib/application/providers/filtered_transactions_provider.dart` (extended)
- `test/presentation/sheets/filter_sheet_test.dart` (new)

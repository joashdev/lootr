# Task 13 — Presentation — Budgets Tab

**Status:** [ ]

---

## Objective

Implement the budgets list screen and budget detail screen. Budgets show spending limits per category per month, with progress visualization.

References: `docs/navigation-arch.md §5`, `docs/design.md` (progress bars), `docs/state-management.md`

## Dependencies

- 10 — Navigation Shell & Tab Bar
- 02 — Design System & Theme
- 07 — Application Layer — Riverpod Providers

## Deliverables

### 13.1 BudgetsScreen (`lib/presentation/screens/budgets/budgets_screen.dart`)

**AppBar:**
- Title: "Budgets"
- Left: Month navigator (`CaretLeft` / month-year label / `CaretRight`) — cycles through months
- Right: `+` icon → opens budget creation bottom sheet

**Summary header:**
- Total budgeted this month vs total spent
- Progress bar (full width): spent % of total budgeted
- "₱{spent} of ₱{budgeted}" with percentage

**Budget list:**
- Card per budget category
- Each card shows:
  - Category icon + name (left)
  - Spent amount / Budget amount (right)
  - Progress bar (8px height, radius-full): color by % (green <80%, amber 80-100%, red >100%)
  - "₱{remaining} left" or "₱{over} over" text

### 13.2 Budget creation sheet
Bottom sheet form:
- Category dropdown (autocomplete from `categoriesProvider`)
- Amount input (monospace, numeric keyboard)
- Month/Year (pre-filled from current navigation)
- "Save" button → `AddBudget` use case → pop sheet → refresh list

### 13.3 BudgetDetailScreen (`lib/presentation/screens/budgets/budget_detail_screen.dart`)
Pushed route at `/budgets/:id`.

**Sections:**
1. **Header:** Category icon, name, budget amount
2. **Progress card:** Large progress ring/bar, spent / budgeted, percentage, remaining/over
3. **Related transactions:** List of transactions matching this budget's category + month/year
4. **Edit/Delete actions**

### 13.4 Edit mode
- Tapping Edit opens same form as creation, pre-filled
- On save: update budget → refresh
- Delete: confirmation dialog → soft delete → pop

### 13.5 Month navigation
- `CaretLeft` / `CaretRight` arrows navigate months
- Month name + year displayed centrally: "June 2026"
- Previous months are read-only (past budgets)
- Future months show budgets but no transactions yet

### 13.6 Empty state
- "No budgets set for {month}"
- "Set spending limits to stay on track"
- Primary button: "Create Budget"

### 13.7 Loading state
- Shimmer cards matching budget card shape

## Acceptance Criteria

- [ ] Budgets list shows all budgets for selected month/year
- [ ] Month navigation (arrows) changes displayed month correctly
- [ ] Progress bars show correct spent/budgeted ratio per category
- [ ] Total spent vs total budgeted header bar updates correctly
- [ ] Budget creation sheet saves new budget and refreshes list
- [ ] Budget detail shows related transactions for that category+period
- [ ] Edit/delete works with correct balance updates
- [ ] Empty state renders when no budgets exist
- [ ] Loading shimmer matches card layout

## Files Likely Affected

- `lib/presentation/screens/budgets/budgets_screen.dart` (new)
- `lib/presentation/screens/budgets/budget_detail_screen.dart` (new)
- `lib/presentation/screens/budgets/widgets/budget_card.dart` (new)
- `lib/presentation/screens/budgets/widgets/budget_progress_bar.dart` (new)
- `lib/presentation/screens/budgets/widgets/budget_summary_header.dart` (new)
- `lib/presentation/screens/budgets/widgets/month_navigator.dart` (new)
- `lib/presentation/screens/budgets/widgets/budget_shimmer.dart` (new)
- `lib/presentation/sheets/budget_create_sheet.dart` (new)
- `lib/application/providers/budgets_tab_provider.dart` (extended)
- `lib/application/providers/budget_detail_provider.dart` (extended)
- `test/presentation/budgets/` (new)

# Task 15 — Presentation — Add Transaction Sheet & Forms

**Status:** [ ]

---

## Objective

Implement the Add Transaction bottom sheet with two modes: Manual form and Natural Language quick-add. Also implement the OCR scan screen and edit transaction form.

References: `docs/navigation-arch.md §2 §3`, `docs/design.md` (inputs, bottom sheet), `docs/solutions-arch.md §6.4`

## Dependencies

- 10 — Navigation Shell & Tab Bar
- 02 — Design System & Theme
- 07 — Application Layer — Riverpod Providers
- 06 — Domain Layer — Use Cases (AddTransaction, ParseNL, RunOCR)

## Deliverables

### 15.1 AddTransactionSheet (`lib/presentation/sheets/add_transaction_sheet.dart`)
Bottom sheet at `/transactions/new`. Two modes toggleable:

**Mode toggle in sheet header:**
- Segmented control or tab: "Manual" | "Quick"

### 15.2 Manual form mode
Form fields:
1. **Amount** — large monospace input, numeric keyboard, direction-colored
2. **Direction** — segmented: "Expense" / "Income"
3. **Account** — dropdown (from `accountsProvider`), with current balance shown
4. **Category** — autocomplete (from `categoriesProvider`), filtered by direction
5. **Payee** — autocomplete (from `payeesProvider`), creates new on unknown
6. **Date** — date picker, defaults to today
7. **Time** — time picker, defaults to now
8. **Note** — text area, optional
9. **Transaction mode** — segmented: "One-time" / "Recurring" / "Installment" / "Debt"
   - If Recurring: show recurrence rule picker
   - If Installment: show parent transaction picker
   - If Debt: show debt record picker

**Save button** (primary, full width):
- Validates all required fields
- Calls `AddTransaction` use case
- On success: pop sheet, refresh providers, show undo snackbar

### 15.3 Quick Add (NL) mode
- Single text input: "Describe your transaction..."
- Mic toggle inside field (tappable → voice input, stub in V1)
- Deterministic `ParseNL` runs on submit
- Extracted fields shown in preview card:
  - Amount, Payee, Account, Category, Direction
  - Fields marked with confidence (green dot = confident, amber = uncertain)
- Tappable fields for manual correction
- "Save" button confirms → same flow as manual
- "Edit manually" button switches to manual form pre-filled

### 15.4 OCR scan screen (`lib/presentation/screens/scan/ocr_scan_screen.dart`)
Full-screen modal at `/scan`.

**Layout:**
- Camera viewfinder (full screen)
- Capture button (bottom center, large circle)
- Gallery picker button (bottom left) for selecting existing receipt photos
- Flash toggle

**Processing flow:**
1. Capture photo → show with bounding boxes
2. Run OCR → `RunOCR` use case → extract text
3. Show extracted fields in preview card
4. User confirms/corrects
5. Save → same flow as manual

### 15.5 Edit transaction form
- Same form as manual Add, pre-filled with existing data
- Different title: "Edit Transaction"
- On save: calls `EditTransaction` use case
- Cancel: pops without changes

### 15.6 Amount input widget
Custom re-usable amount input:
- Monospace font
- Numeric keyboard with decimal
- Prefix: currency symbol (₱)
- Color: based on direction (expense=red, income=green)

## Acceptance Criteria

- [ ] AddTransactionSheet opens from QuickActionsSheet or Quick Add island
- [ ] Manual/Quick mode toggle switches form layout
- [ ] Manual form: all fields validate, Save calls AddTransaction, pops sheet
- [ ] Manual form: Recurring mode shows RRULE picker, Installment shows parent picker
- [ ] Quick Add: parse "mcdo 250 gcash" → preview card shows amount=250, payee=mcdo, account=gcash
- [ ] Quick Add: mic toggle is visible but non-functional in V1
- [ ] Quick Add: "Edit manually" switches to manual form with extracted fields pre-filled
- [ ] OCR scan: camera opens, capture works, ML Kit extracts text
- [ ] OCR scan: extracted fields shown in preview, user can confirm/save
- [ ] Edit form: pre-fills all fields from existing transaction
- [ ] Edit form: Save applies EditTransaction use case with correct balance delta
- [ ] Amount input: monospace, direction-colored, currency prefix
- [ ] Undo snackbar appears after every successful save

## Files Likely Affected

- `lib/presentation/sheets/add_transaction_sheet.dart` (new)
- `lib/presentation/sheets/transaction_mode_picker.dart` (new)
- `lib/presentation/sheets/quick_add_input.dart` (new)
- `lib/presentation/screens/scan/ocr_scan_screen.dart` (new)
- `lib/presentation/shared/components/inputs/amount_input.dart` (new)
- `lib/presentation/shared/components/inputs/category_autocomplete.dart` (new)
- `lib/presentation/shared/components/inputs/payee_autocomplete.dart` (new)
- `lib/presentation/shared/components/inputs/account_dropdown.dart` (new)
- `lib/domain/use_cases/add_transaction.dart` (extended)
- `lib/domain/use_cases/edit_transaction.dart` (extended)
- `lib/domain/use_cases/parse_nl.dart` (extended)
- `lib/domain/use_cases/run_ocr.dart` (extended)
- `test/presentation/sheets/` (new)

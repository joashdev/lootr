# Task 06 — Domain Layer — Use Cases

**Status:** [ ]

---

## Objective

Implement use case classes that encapsulate business logic, orchestrate repositories, and return `Result` types. Use cases are the only entry point to the domain layer — presentation never calls repos directly.

References: `docs/domain-model.md`, `docs/solutions-arch.md §5 §6.1`

## Dependencies

- 05 — Domain Layer — Entities & Value Objects
- 04 — Data Layer — Repositories (for repository interface signatures)

## Deliverables

### 6.1 Result type (`lib/domain/value_objects/result.dart`)
```dart
sealed class Result<T> {}
class Success<T> extends Result<T> { final T value; }
class Failure<T> extends Result<T> { final String message; final String? code; }
```

### 6.2 Use case classes

| Use Case | Input | Output | Business Logic |
|---|---|---|---|
| `AddTransaction` | Transaction entity | `Result<String>` (id) | Validates amount > 0, valid direction, valid account exists. Calls `TransactionRepo.create()`. |
| `EditTransaction` | Transaction entity (updated) | `Result<void>` | Loads original, computes balance delta, validates no negative balance on accounts (optional). Calls `TransactionRepo.update()`. |
| `DeleteTransaction` | String id | `Result<void>` | Loads original, calls `TransactionRepo.softDelete()`. Returns UndoEntry for snackbar. |
| `CreateTransfer` | Transfer entity | `Result<String>` | Validates source != destination, both accounts exist, amount > 0. Calls `TransferRepo.create()`. |
| `RecalcBalance` | String accountId | `Result<double>` | Sums all non-deleted transactions for account. Updates `accounts.balance`. Returns new balance. |
| `AddBudget` | Budget entity | `Result<String>` | Validates month 1-12, amount > 0. Checks no duplicate (owner, category, month, year). Calls `BudgetRepo.create()`. |
| `UpdateBudgetProgress` | String budgetId | `Result<double>` | Computes spent = SUM transactions for budget's category in budget's month/year. Returns spent amount. |
| `AddGoal` | Goal entity | `Result<String>` | Validates target > 0, goalType valid. Calls `GoalRepo.create()`. |
| `ContributeToGoal` | String goalId, double amount | `Result<void>` | Adds to currentAmount, validates doesn't exceed target. Calls `GoalRepo.addContribution()`. |
| `SettleDebt` | String debtId | `Result<void>` | Sets status=settled, remainingBalance=0. Calls `DebtRepo.settle()`. |
| `CreateRecurring` | RecurringTemplate entity | `Result<String>` | Validates recurrence_rule is valid RRULE. Computes next_occurrence_at. Calls `RecurringRepo.create()`. |
| `AdvanceRecurring` | String templateId | `Result<void>` | Creates transaction from template, advances next_occurrence_at per RRULE. Calls `RecurringRepo.advanceNextOccurrence()`. |
| `ParseNL` | String rawText | `Result<ParsedTransaction>` | Deterministic regex parser (payee, amount, account, category). Extracts structured fields from natural language input. |
| `RunOCR` | String imagePath | `Result<OcrPayload>` | Orchestrates ML Kit text recognition. Returns extracted text + structured fields. |

### 6.3 ParsedTransaction value object (`lib/domain/value_objects/parsed_transaction.dart`)
- `amount` (double?)
- `payee` (String?)
- `account` (String?)
- `category` (String?)
- `direction` (TransactionDirection?)
- `note` (String?)
- `confidence` (double)

### 6.4 OcrPayload value object (`lib/domain/value_objects/ocr_payload.dart`)
- `rawText` (String)
- `extractedFields` (ParsedTransaction)
- `confidence` (double)

## Acceptance Criteria

- [ ] All use cases are pure Dart (no Flutter, no Drift imports)
- [ ] Use cases receive repositories via constructor injection (interfaces)
- [ ] All errors return `Failure` with descriptive `message` + machine-readable `code`
- [ ] `AddTransaction` validates amount > 0 before calling repo
- [ ] `CreateTransfer` validates source_account != destination_account
- [ ] `RecalcBalance` returns correct sum from transaction history
- [ ] `ParseNL` correctly extracts "mcdo 250 gcash" → amount=250, payee=mcdo, account=gcash
- [ ] `ParseNL` works with currency symbols (₱, $) and abbreviations (k, m)
- [ ] `AdvanceRecurring` creates a transaction AND advances next_occurrence_at atomically
- [ ] All use cases pass unit tests with mocked repositories

## Files Likely Affected

- `lib/domain/value_objects/result.dart` (new)
- `lib/domain/value_objects/parsed_transaction.dart` (new)
- `lib/domain/value_objects/ocr_payload.dart` (new)
- `lib/domain/use_cases/add_transaction.dart` (new)
- `lib/domain/use_cases/edit_transaction.dart` (new)
- `lib/domain/use_cases/delete_transaction.dart` (new)
- `lib/domain/use_cases/create_transfer.dart` (new)
- `lib/domain/use_cases/recalc_balance.dart` (new)
- `lib/domain/use_cases/add_budget.dart` (new)
- `lib/domain/use_cases/update_budget_progress.dart` (new)
- `lib/domain/use_cases/add_goal.dart` (new)
- `lib/domain/use_cases/contribute_to_goal.dart` (new)
- `lib/domain/use_cases/settle_debt.dart` (new)
- `lib/domain/use_cases/create_recurring.dart` (new)
- `lib/domain/use_cases/advance_recurring.dart` (new)
- `lib/domain/use_cases/parse_nl.dart` (new)
- `lib/domain/use_cases/run_ocr.dart` (new)
- `test/domain/use_cases/` (new)

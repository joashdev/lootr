# Task 18 — Demo Data & Seed Data

**Status:** [x]

---

## Objective

Implement demo data seeding that populates the database with realistic sample data for onboarding and development. Also seed default categories on first launch.

References: `docs/navigation-arch.md` §7.2, `docs/database-schema.md` (category seeding), `docs/domain-model.md`

## Dependencies

- 04 — Data Layer — Repositories

## Deliverables

### 18.1 Category seeds (`lib/data/seed/category_seeds.dart`)
Default categories seeded on first launch, never deleted:

**Expense categories:**
- Food & Dining (restaurant/fast food/groceries)
- Transportation (fuel/parking/commute/ride-hailing)
- Shopping (clothing/electronics/household)
- Bills & Utilities (electricity/water/internet/phone)
- Housing (rent/mortgage/repairs)
- Entertainment (movies/games/subscriptions)
- Health & Fitness (doctor/gym/pharmacy)
- Education (tuition/books/courses)
- Personal Care (salon/spa/toiletries)
- Gifts & Donations

**Income categories:**
- Salary
- Freelance
- Business Income
- Investment Income
- Gifts Received
- Refunds

**Transfer categories:**
- Account Transfer (default for all transfers)

Each category has: name, icon (phosphor icon name), color hex, category_group.

### 18.2 DemoDataLoader (`lib/data/seed/demo_data_loader.dart`)
Generates realistic sample data:

**Accounts (4):**
- BDO Savings (bank, balance: 45,000)
- GCash (ewallet, balance: 3,200)
- BPI Checking (bank, balance: 120,000)
- Cash (cash, balance: 1,500)

**Payees (15+):**
- Common Philippine payees: Jollibee, McDonald's, Mercury Drug, SM Supermarket, Grab, Angkas, Meralco, PLDT, Converge, Landers, Shopee, Lazada, 7-Eleven, Starbucks, Puregold

**Transactions (30+ across 2 months):**
- Mix of expenses and income
- Various categories
- Realistic amounts in PHP
- Spread across the 4 accounts
- Some recurring patterns

**Budgets (4):**
- Food & Dining: ₱15,000/mo
- Transportation: ₱5,000/mo
- Shopping: ₱8,000/mo
- Entertainment: ₱3,000/mo

**Goals (2):**
- Emergency Fund: ₱100,000 target, ₱45,000 current
- Vacation to Japan: ₱80,000 target, ₱20,000 current

### 18.3 DemoDataNotifier (`lib/application/providers/demo_data_provider.dart`)
```dart
class DemoDataNotifier extends AsyncNotifier<DemoDataState> {
  Future<void> seed();
  Future<void> clear();
  bool get hasDemoData;
}
```
- `seed()`: writes all demo data in one transaction
- `clear()`: deletes all rows (for dev/testing reset)
- `hasDemoData`: checks if any demo account exists

### 18.4 Integration with onboarding
- Triggered from onboarding Step 4 if "Load demo data" toggle is on
- Also available from developer settings (hidden: long-press About → "Load Demo Data")
- Shows loading indicator during data generation

## Acceptance Criteria

- [x] Default categories are seeded on first launch (if categories table is empty)
- [x] Demo data creates 4 accounts, 15+ payees, 30+ transactions, 4 budgets, 2 goals
- [x] Transaction amounts use realistic PHP values (hundreds to tens of thousands)
- [x] Budgets match demo transactions (spent amounts visible in progress bars)
- [x] Demo data is created in a single SQLite transaction (atomic)
- [x] `clear()` removes all demo data without affecting default categories
- [x] `hasDemoData` returns true after seeding, false after clearing
- [x] Seeding is idempotent (running twice doesn't duplicate)
- [x] Demo data works with an in-memory database for testing

## Files Likely Affected

- `lib/data/seed/category_seeds.dart` (new)
- `lib/data/seed/demo_data_loader.dart` (new)
- `lib/application/providers/demo_data_provider.dart` (new or extended from Task 07)
- `lib/data/repositories/category_repo.dart` (extended — seedCategories method)
- `test/data/seed/` (new)

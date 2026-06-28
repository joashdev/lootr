# Task 20 — Testing Infrastructure

**Status:** [x]

---

## Objective

Establish testing patterns, utilities, and CI-compatible test runners. All layers have tests: unit (domain), widget (presentation), integration (flows). Use in-memory Drift database for data layer tests.

References: `docs/state-management.md` (testing patterns), `docs/solutions-arch.md` §10.4

## Dependencies

- 01 — Project Setup & Scaffolding

## Deliverables

### 20.1 Test database utility (`test/test_helpers/test_database.dart`)
```dart
AppDatabase createTestDb() => AppDatabase.inMemory();
```
- Always use in-memory DB (no filesystem dependency)
- Seed with default categories before each test
- Helper to seed demo data for integration-style tests

### 20.2 Provider test utility (`test/test_helpers/provider_container.dart`)
```dart
ProviderContainer createTestContainer({AppDatabase? db}) {
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db ?? createTestDb()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}
```

### 20.3 Mock utilities (`test/test_helpers/mocks.dart`)
- `mocktail` mocks for all repositories
- `MockTransactionRepo`, `MockAccountRepo`, etc.
- `MockSyncManager`, `MockNotificationScheduler`

### 20.4 Unit test targets (per layer)

| Layer | What to test | Tool |
|---|---|---|
| **Domain — Entities** | Equality, copyWith, JSON serialization | `flutter_test` |
| **Domain — Value Objects** | Money arithmetic, DateRange logic, TransactionFilters.apply() | `flutter_test` |
| **Domain — Use Cases** | Business logic, validation, error cases | `flutter_test` + mocks |
| **Data — Repositories** | CRUD operations, streams, balance atomicity | `flutter_test` + in-memory DB |
| **Application — Providers** | State transitions, loading/error/empty | `flutter_test` + in-memory DB |
| **Application — Sync** | Push/pull phases, conflict resolution, retry | `flutter_test` + mocks |
| **Presentation — Widgets** | Rendering, interactions, empty/loading states | `flutter_test` + mock providers |
| **Presentation — Screens** | Navigation, form validation, sheet open/close | `flutter_test` + integration |

### 20.5 Integration test targets
- Transaction add flow: open sheet → fill form → save → verify list updated → undo → verify removed
- Filter flow: apply filters → verify filtered list → clear filters → verify full list
- Budget flow: create budget → verify progress → edit → verify update
- Sync flow (mock HTTP): push → pull → verify local DB state
- Onboarding flow: complete steps → verify main app shows

### 20.6 Test fixtures
- `fixtures/sample_transaction.json` — representative transaction for parser tests
- `fixtures/sample_receipt_text.json` — OCR output samples
- `fixtures/demo_data_subset.json` — small valid dataset for integration tests

### 20.7 CI configuration
- GitHub Actions workflow: `flutter test` on every PR
- Ensure in-memory DB tests pass in CI (no native SQLite dependency issues)
- Flutter version pinned in CI config

## Acceptance Criteria

- [x] `flutter test` runs all unit/widget tests with in-memory DB
- [x] `flutter test integration_test` runs integration tests
- [x] Test DB utility creates clean in-memory database per test
- [x] Provider test utility correctly overrides providers with test DB
- [x] All domain tests are pure Dart (no Flutter dependency)
- [x] Repository tests cover CRUD, streams, and SQLite transaction atomicity
- [x] Provider tests cover loading → data → error states
- [x] Widget tests cover null-safety, empty states, and interaction callbacks
- [x] Screen tests verify navigation and sheet behavior
- [x] CI workflow runs all tests on PR

## Files Likely Affected

- `test/test_helpers/test_database.dart` (new)
- `test/test_helpers/provider_container.dart` (new)
- `test/test_helpers/mocks.dart` (new)
- `test/domain/` (extend with tests)
- `test/data/` (extend with tests)
- `test/application/` (extend with tests)
- `test/presentation/` (extend with tests)
- `integration_test/` (new)
- `test/fixtures/` (new)
- `.github/workflows/flutter_ci.yml` (new)

# Task 01 — Project Setup & Scaffolding

**Status:** [x]

---

## Objective

Create the Flutter project, configure dependencies, and establish the directory structure for the layered architecture defined in `solutions-arch.md §5`.

## Dependencies

- None (root task)

## Deliverables

### 1.1 Flutter project created
- `flutter create` the app (org: `com.lootr.app`, platforms: iOS + Android)
- Set min SDK: iOS 15, Android 24 (API 33)
- Configure `pubspec.yaml` with all required dependencies:

| Package | Purpose |
|---|---|
| `riverpod` / `flutter_riverpod` | State management |
| `go_router` | Declarative routing |
| `drift` / `drift_flutter` / `sqlite3_flutter_libs` | ORM + SQLite |
| `path_provider` | DB file location |
| `phosphor_flutter` | Icon set |
| `intl` | Number/date formatting |
| `google_mlkit_text_recognition` | OCR (on-device) |
| `flutter_local_notifications` | Local notifications |
| `shared_preferences` | Simple KV for preferences |
| `flutter_secure_storage` | JWT storage (V2) |
| `equatable` | Value equality for entities |
| `freezed` / `json_annotation` | Code generation for entities |
| `build_runner` | Code generation runner |
| `drift_dev` | Drift code generation |
| `mocktail` | Test mocking |
| `flutter_test` / `integration_test` | Testing |

### 1.2 Directory structure created
```
lib/
├── main.dart
├── app.dart                          # MaterialApp.router, ProviderScope
├── core/
│   ├── theme/
│   │   ├── colors.dart
│   │   ├── typography.dart
│   │   ├── spacing.dart
│   │   ├── radius.dart
│   │   ├── shadows.dart
│   │   └── theme.dart                # Light + dark ThemeData
│   ├── router/
│   │   └── app_router.dart           # go_router config, ShellRoute
│   ├── constants/
│   │   └── enums.dart                # SyncStatus, Direction, Mode, etc.
│   └── extensions/
│       └── context_extensions.dart
├── data/
│   ├── database/
│   │   ├── app_database.dart         # @DriftDatabase annotated class
│   │   ├── tables/
│   │   │   ├── users.dart
│   │   │   ├── households.dart
│   │   │   ├── household_members.dart
│   │   │   ├── accounts.dart
│   │   │   ├── transactions.dart
│   │   │   ├── transfers.dart
│   │   │   ├── categories.dart
│   │   │   ├── payees.dart
│   │   │   ├── budgets.dart
│   │   │   ├── debt_records.dart
│   │   │   ├── goals.dart
│   │   │   ├── recurring_templates.dart
│   │   │   ├── account_balance_snapshots.dart
│   │   │   ├── notifications.dart
│   │   │   ├── ai_processing_logs.dart
│   │   │   └── sync_metadata.dart
│   │   └── converters/
│   │       └── type_converters.dart
│   ├── repositories/
│   │   ├── transaction_repo.dart
│   │   ├── account_repo.dart
│   │   ├── budget_repo.dart
│   │   ├── category_repo.dart
│   │   ├── payee_repo.dart
│   │   ├── transfer_repo.dart
│   │   ├── debt_repo.dart
│   │   ├── goal_repo.dart
│   │   ├── recurring_repo.dart
│   │   ├── user_repo.dart
│   │   ├── household_repo.dart
│   │   └── sync_metadata_repo.dart
│   └── seed/
│       ├── demo_data_loader.dart
│       └── category_seeds.dart
├── domain/
│   ├── entities/
│   │   ├── transaction.dart
│   │   ├── account.dart
│   │   ├── budget.dart
│   │   ├── category.dart
│   │   ├── payee.dart
│   │   ├── transfer.dart
│   │   ├── debt_record.dart
│   │   ├── goal.dart
│   │   ├── recurring_template.dart
│   │   ├── user.dart
│   │   └── household.dart
│   ├── value_objects/
│   │   ├── money.dart
│   │   ├── date_range.dart
│   │   ├── transaction_filters.dart
│   │   └── sync_health.dart
│   └── use_cases/
│       ├── add_transaction.dart
│       ├── edit_transaction.dart
│       ├── delete_transaction.dart
│       ├── create_transfer.dart
│       ├── recalc_balance.dart
│       ├── parse_nl.dart
│       └── run_ocr.dart
├── application/
│   ├── providers/
│   │   ├── database_provider.dart
│   │   ├── repo_providers.dart
│   │   ├── dashboard_provider.dart
│   │   ├── safe_to_spend_provider.dart
│   │   ├── net_worth_provider.dart
│   │   ├── transactions_tab_provider.dart
│   │   ├── transaction_filters_provider.dart
│   │   ├── filtered_transactions_provider.dart
│   │   ├── budgets_tab_provider.dart
│   │   ├── budget_detail_provider.dart
│   │   ├── accounts_provider.dart
│   │   ├── account_detail_provider.dart
│   │   ├── debts_provider.dart
│   │   ├── debt_detail_provider.dart
│   │   ├── goals_provider.dart
│   │   ├── goal_detail_provider.dart
│   │   ├── recurring_provider.dart
│   │   ├── recurring_detail_provider.dart
│   │   ├── more_tab_provider.dart
│   │   ├── auth_provider.dart
│   │   ├── theme_provider.dart
│   │   ├── onboarding_provider.dart
│   │   ├── undo_stack_provider.dart
│   │   ├── demo_data_provider.dart
│   │   └── sync_providers.dart
│   └── sync/
│       ├── sync_manager.dart
│       ├── push_client.dart
│       ├── pull_client.dart
│       └── conflict_applier.dart
├── ai/
│   ├── nl_parser.dart
│   ├── ocr_pipeline.dart
│   └── categorizer.dart
└── presentation/
    ├── screens/
    │   ├── dashboard/
    │   │   ├── dashboard_screen.dart
    │   │   └── widgets/
    │   ├── transactions/
    │   │   ├── transactions_screen.dart
    │   │   ├── transaction_detail_screen.dart
    │   │   └── widgets/
    │   ├── budgets/
    │   │   ├── budgets_screen.dart
    │   │   ├── budget_detail_screen.dart
    │   │   └── widgets/
    │   ├── more/
    │   │   ├── more_screen.dart
    │   │   ├── accounts_screen.dart
    │   │   ├── account_detail_screen.dart
    │   │   ├── debts_screen.dart
    │   │   ├── debt_detail_screen.dart
    │   │   ├── goals_screen.dart
    │   │   ├── goal_detail_screen.dart
    │   │   ├── recurring_screen.dart
    │   │   ├── recurring_detail_screen.dart
    │   │   ├── reports_screen.dart
    │   │   ├── insights_screen.dart
    │   │   ├── categories_screen.dart
    │   │   ├── payees_screen.dart
    │   │   ├── households_screen.dart
    │   │   └── settings/
    │   │       ├── profile_screen.dart
    │   │       ├── notification_settings_screen.dart
    │   │       ├── ai_settings_screen.dart
    │   │       ├── ai_logs_screen.dart
    │   │       ├── sync_settings_screen.dart
    │   │       ├── appearance_screen.dart
    │   │       ├── security_screen.dart
    │   │       └── about_screen.dart
    │   └── onboarding/
    │       └── onboarding_screen.dart
    ├── sheets/
    │   ├── add_transaction_sheet.dart
    │   ├── quick_actions_sheet.dart
    │   ├── filter_sheet.dart
    │   └── sync_status_sheet.dart
    └── shared/
        ├── components/
        │   ├── cards/
        │   ├── buttons/
        │   ├── inputs/
        │   ├── badges/
        │   └── progress/
        └── layouts/
            └── tab_shell.dart
```

### 1.3 `.gitignore` configured
- Flutter-standard `.gitignore`
- Additions: `*.g.dart`, `*.freezed.dart`, `.DS_Store`

### 1.4 Code generation configured
- `build.yaml` for Drift
- `build.yaml` for freezed
- Run `dart run build_runner build` to verify

## Acceptance Criteria

- [x] `flutter pub get` succeeds with no errors
- [x] `flutter analyze` passes (may have unused imports in scaffolded files)
- [x] `dart run build_runner build` completes successfully
- [x] `flutter test` runs (may have 0 tests)
- [x] Directory structure matches spec exactly
- [x] All packages in `pubspec.yaml` are pinned to specific versions

## Files Likely Affected

- `pubspec.yaml` (new)
- `build.yaml` (new)
- `lib/` (entirely new)
- `test/` (new)
- `.gitignore` (new or appended)

# Task 10 — Presentation — Navigation Shell & Tab Bar

**Status:** [ ]

---

## Objective

Implement the go_router configuration, ShellRoute tab bar, and bottom navigation with 4 tabs + rightmost Add island. This is the structural skeleton all screens plug into.

References: `docs/navigation-arch.md §1-3`, `docs/solutions-arch.md §5`, `docs/design.md` (tab bar component)

## Dependencies

- 02 — Design System & Theme
- 07 — Application Layer — Riverpod Providers

## Deliverables

### 10.1 App router (`lib/core/router/app_router.dart`)
Full `GoRouter` configuration with 31 routes:

```
ShellRoute (TabShell) → [
  GoRoute('/', DashboardScreen),           // Tab 1
  GoRoute('/transactions', TransactionsScreen), // Tab 2
  GoRoute('/budgets', BudgetsScreen),       // Tab 3
  GoRoute('/more', MoreScreen),             // Tab 4
]

// Modal / sheet routes (outside ShellRoute)
GoRoute('/transactions/new', AddTransactionSheet),
GoRoute('/scan', OcrScanScreen),

// Pushed routes (inside their respective tab branches)
GoRoute('/transactions/:id', TransactionDetailScreen),
GoRoute('/budgets/:id', BudgetDetailScreen),
GoRoute('/more/accounts', AccountsListScreen),
GoRoute('/more/accounts/:id', AccountDetailScreen),
// ... all remaining pushed routes from navigation-arch.md §1

// Onboarding
GoRoute('/onboarding', OnboardingScreen),
```

Route configuration details:
- `ShellRoute` wraps all tab routes with `TabShell` widget
- `StatefulShellRoute.indexedStack` preserves tab state
- All routes use `pageBuilder` with `CustomTransitionPage` matching design.md animation specs
- Page push: 300ms `cubic-bezier(0.4, 0, 0.2, 1)`
- Sheet enter: 250ms `cubic-bezier(0.32, 0.72, 0, 1)`

### 10.2 TabShell widget (`lib/presentation/shared/layouts/tab_shell.dart`)
- Scaffold with `BottomNavigationBar`
- 4 tabs: Dashboard, Transactions, Budgets, More
- Icons from phosphor_flutter: `House`, `List`, `ChartPie`, `SquaresFour`
- Tab bar height: 64px per `design.md`
- Labels: "Dashboard", "Transactions", "Budgets", "More"
- Active tab: primary-600 color + semibold label
- Inactive tab: text-tertiary color + regular label

### 10.3 Add Island
- Positioned right of the 4th tab, above the tab bar
- 56×44px pill shape, primary-600 background, `Plus` icon in white
- Slightly elevated above tab bar (shadow-island)
- Taps open `QuickActionsSheet`

### 10.4 QuickActionsSheet (`lib/presentation/sheets/quick_actions_sheet.dart`)
Bottom sheet with 3 quick actions:
1. **Add Transaction (Manual)** — navigates to `/transactions/new` with manual form
2. **Add Transaction (NL)** — navigates to `/transactions/new` with NL text input
3. **Scan Receipt** — navigates to `/scan`

Close by swipe-down or tap outside.

### 10.5 App widget (`lib/app.dart`)
```dart
class App extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // ...
    );
  }
}
```

### 10.6 Main entry (`lib/main.dart`)
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.open();
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const App(),
    ),
  );
}
```

### 10.7 Tab state preservation
- Use `StatefulShellRoute.indexedStack` to preserve scroll position, filters, and provider state across tab switches
- Tab-scoped providers must not be disposed on tab switch (KeepAliveLink)

## Acceptance Criteria

- [ ] All 31 routes are registered in go_router config
- [ ] Tab switching preserves scroll position and state (StatefulShellRoute)
- [ ] Deep link paths resolve to correct screens
- [ ] Add Island is rendered above tab bar, rightmost position
- [ ] Add Island → QuickActionsSheet opens with 3 options
- [ ] AppBar shows correct elements per tab (Dashboard: sync + search; Transactions: filter + search; Budgets: month nav + [+]; More: none)
- [ ] Route transitions use correct animation curves and durations
- [ ] Browser back button / Android back button navigates correctly in route stack
- [ ] Tab bar matches design spec (64px, icon+label stacked, active/inactive colors)
- [ ] Widgets load with no null provider errors (placeholder screens acceptable)
- [ ] `app_router.dart` has no unused route constants

## Files Likely Affected

- `lib/main.dart` (new)
- `lib/app.dart` (new)
- `lib/core/router/app_router.dart` (new)
- `lib/presentation/shared/layouts/tab_shell.dart` (new)
- `lib/presentation/sheets/quick_actions_sheet.dart` (new)
- `lib/presentation/screens/dashboard/dashboard_screen.dart` (placeholder, extended in Task 11)
- `lib/presentation/screens/transactions/transactions_screen.dart` (placeholder)
- `lib/presentation/screens/budgets/budgets_screen.dart` (placeholder)
- `lib/presentation/screens/more/more_screen.dart` (placeholder)
- `lib/application/providers/theme_provider.dart` (extended)

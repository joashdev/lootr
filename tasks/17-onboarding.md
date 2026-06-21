# Task 17 — Presentation — Onboarding

**Status:** [x]

---

## Objective

Implement the onboarding flow (4-step walkthrough) shown on first launch. Introduces the app's core concepts, sets initial preferences, and loads demo data.

References: `docs/navigation-arch.md` §7.6, `docs/product-strategy.md` (V1 scope)

## Dependencies

- 10 — Navigation Shell & Tab Bar
- 02 — Design System & Theme

## Deliverables

### 17.1 OnboardingScreen (`lib/presentation/screens/onboarding/onboarding_screen.dart`)
Full-screen modal at `/onboarding`. 4 steps with page indicator.

**Step 1 — Welcome:**
- App logo / hero illustration
- "Welcome to Lootr"
- "Your personal finance tracker. Private, offline-first, always in control."
- "Next" button

**Step 2 — Track:**
- Illustration of transaction entry
- "Track every peso"
- "Quick-add transactions with text or voice. No bank connections needed."
- "Next" button

**Step 3 — Plan:**
- Illustration of budgets / goals
- "Plan your spending"
- "Set budgets, track goals, and see where your money goes."
- "Next" button

**Step 4 — Setup:**
- Display name input
- Currency selector (dropdown, default PHP)
- "Load demo data" toggle (on by default)
- "Get Started" primary button

### 17.2 Onboarding state management
- `onboardingProvider` — `StateProvider<OnboardingState>` persisted via SharedPreferences
- States: `notStarted`, `inProgress(step)`, `completed`
- On completed: sets flag, navigates to `/` (main app)

### 17.3 First launch detection
- Check `onboardingProvider` state in `app.dart`
- If not completed → redirect to `/onboarding`
- If completed → show main app directly

### 17.4 Demo data trigger
- If "Load demo data" is on → `demoDataProvider.seed()` after completing onboarding
- Demo data includes: accounts, categories, payees, sample transactions, sample budgets

### 17.5 Skip option
- "Skip" text button in top right corner
- Confirms: "Start with empty app?"
- On confirm: completes onboarding, does not load demo data

## Acceptance Criteria

- [x] Onboarding shows on first launch, not on subsequent launches
- [x] 4 steps with correct content and illustrations
- [x] Page indicator shows current step (dots)
- [x] "Get Started" saves display name, currency, and demo data preference
- [x] "Load demo data" toggle seeds database when enabled
- [x] "Skip" bypasses to empty app without demo data
- [x] Back button disabled during onboarding (cannot leave)
- [x] Onboarding transitions to main app after completion

## Files Likely Affected

- `lib/presentation/screens/onboarding/onboarding_screen.dart` (new)
- `lib/presentation/screens/onboarding/widgets/onboarding_step.dart` (new)
- `lib/presentation/screens/onboarding/widgets/step_indicator.dart` (new)
- `lib/application/providers/onboarding_provider.dart` (extended)
- `lib/application/providers/demo_data_provider.dart` (extended)
- `lib/app.dart` (update — onboarding redirect logic)
- `lib/core/router/app_router.dart` (update — onboarding route)
- `test/presentation/onboarding/` (new)

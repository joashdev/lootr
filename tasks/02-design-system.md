# Task 02 — Design System & Theme

**Status:** [x] Done

---

## Objective

Implement the design tokens and ThemeData from `docs/design.md` as a Flutter `ThemeData` with light + dark mode support. Build shared UI components used by all screens.

References: `docs/design.md`, `docs/solutions-arch.md §10.5`

## Dependencies

- 01 — Project Setup & Scaffolding

## Deliverables

### 2.1 Color tokens (`lib/core/theme/colors.dart`)
- All color tokens from design.md §2: primary-50→700, success-50→600, warning-50→600, danger-50→600
- Neutral scale: bg, surface, surface-elevated, border, border-subtle, text-primary/secondary/tertiary
- Transaction direction colors: expense=#dc2626, income=#059669, transfer=#2563eb
- Light + dark mode maps as two `Map<String, Color>` constants

### 2.2 Typography tokens (`lib/core/theme/typography.dart`)
- Scale: display(40/700/1.1), h1(28/700/1.2), h2(21/600/1.3), h3(17/600/1.4), body(15/400/1.6), body-medium(15/500/1.6), caption(13/400/1.5), caption-medium(13/500/1.5), micro(11/600/1.4)
- System font stack: `'.SF Pro Display', '.SF Pro Text', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif`
- Mono: `'SF Mono', 'Fira Code', 'Cascadia Code', monospace`
- `AppTypography` class with `TextStyle` getters for each token

### 2.3 Spacing, radius, shadows (`lib/core/theme/`)
- `spacing.dart`: space-1(4)→space-12(48) as `double` constants
- `radius.dart`: radius-sm(6), radius-md(10), radius-lg(14), radius-xl(18), radius-full(9999)
- `shadows.dart`: shadow-sm, shadow-md, shadow-lg, shadow-island as `BoxShadow` lists

### 2.4 ThemeData (`lib/core/theme/theme.dart`)
- `AppTheme.light` — returns `ThemeData` using all tokens above
- `AppTheme.dark` — returns `ThemeData` using dark mode color map
- `ColorScheme` derived from primary/neutral tokens
- `TextTheme` populated from typography scale
- Page padding: 16px mobile, 24px tablet, 40px desktop (max-width 800px)
- Default animation curves from design.md §5

### 2.5 Shared components (`lib/presentation/shared/components/`)
Implement reusable widgets matching design.md component specs:

| Component | Spec |
|---|---|
| `PrimaryButton` | 44px height, primary-600 bg, white text, radius-md, semibold |
| `SecondaryButton` | 44px height, primary-50 bg, primary-700 text, radius-md |
| `GhostButton` | 44px height, transparent bg, text-secondary |
| `IconButton` | 44×44 tap target, 24px icon, text-secondary → text-primary on press |
| `StandardCard` | radius-lg, 16px padding, surface bg, shadow-sm |
| `HeroCard` | radius-xl, 20px padding, surface-elevated bg, shadow-md |
| `CompactRowCard` | radius-md, 12×16 padding, surface bg |
| `AppTextField` | radius-md, 14px height, border-subtle outline → primary on focus |
| `SearchInput` | radius-full, leading search icon, 14px height |
| `AmountInput` | monospace font, direction-colored text |
| `SectionHeader` | h3 style, sticky (used in lists) |
| `TransactionRow` | 40px circle avatar, h3 amount, caption category |
| `BudgetProgressBar` | 8px height, radius-full, primary-500 fill |
| `Sparkline` | 2px stroke, primary-500 |
| `FilterChip` | active: primary-600 bg, inactive: border-subtle outline |
| `StatusBadge` | micro font, color-coded bg (success/warning/danger) |
| `EmptyState` | centered, 120px illustration area, h2 headline, body subtext, primary CTA |
| `SheetHandle` | 40×4px, radius-full, centered at top of bottom sheets |

All components use `Theme.of(context)` — no hardcoded values.

## Acceptance Criteria

- [ ] All color/typography/spacing/radius tokens match `docs/design.md` exactly
- [ ] `AppTheme.light` and `AppTheme.dark` compile and render distinct themes
- [ ] Switching `ThemeMode` at runtime rebuilds all widgets correctly
- [ ] Every component has a widget test that renders it in both light and dark mode
- [ ] Components use semantic token names (no raw hex values in widget code)
- [ ] Page padding adapts to breakpoints (≥600px, ≥900px)

## Files Likely Affected

- `lib/core/theme/colors.dart` (new)
- `lib/core/theme/typography.dart` (new)
- `lib/core/theme/spacing.dart` (new)
- `lib/core/theme/radius.dart` (new)
- `lib/core/theme/shadows.dart` (new)
- `lib/core/theme/theme.dart` (new)
- `lib/presentation/shared/components/buttons/` (new)
- `lib/presentation/shared/components/cards/` (new)
- `lib/presentation/shared/components/inputs/` (new)
- `lib/presentation/shared/components/badges/` (new)
- `lib/presentation/shared/components/progress/` (new)
- `lib/presentation/shared/components/lists/` (new)
- `lib/presentation/shared/components/empty_state.dart` (new)
- `lib/presentation/shared/components/sheet_handle.dart` (new)
- `lib/core/constants/enums.dart` (update — SyncIconState, Direction enums referenced by components)
- `test/theme/` (new)
- `test/components/` (new)

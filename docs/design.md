# Design System — Personal Finance App

Token-level spec for the UI. References: `product-strategy.md` (principles), `navigation-arch.md` (components, screens), `domain-model.md` (design references).

---

## 1. Philosophy

- **Calm, not clinical.** Finance apps feel like spreadsheets. This one feels like a well-designed note-taking app.
- **Clarity over density.** One idea per screen. White space is a feature.
- **Color is semantic, not decorative.** Green means on-track, amber means watch it, red means overspent. No other meaning attached.
- **Typography does the heavy lifting.** Size and weight create hierarchy before color ever does.
- **Spotlight moments earn contrast.** Borrow the confidence of premium fintech editorials only for hero moments; the default surface remains quiet and useful.

---

## 2. Color Palette

### Primary

| Token | Hex | Light | Dark |
|---|---|---|---|
| `primary-50` | `#eeeffe` | Background highlights | — |
| `primary-100` | `#dfe2fc` | Hover states | — |
| `primary-500` | `#6e76d8` | Links, active states | `#8c93eb` |
| `primary-600` | `#5c64cc` | **Primary accent**, Add island bg, CTAs | `#6e76d8` |
| `primary-700` | `#4d56b7` | Pressed states | `#5c64cc` |

> **Primary direction:** We borrow Revolut's confidence in indigo-led branding, but soften it into a quieter blue-violet so the app feels premium without becoming loud or salesy.

### Semantic

| Token | Hex | Use | Dark |
|---|---|---|---|
| `success-50` | `#ecfdf5` | Success backgrounds | `#064e3b` |
| `success-500` | `#10b981` | On-track indicators | `#34d399` |
| `success-600` | `#059669` | **On-track text**, positive amounts | `#10b981` |
| `warning-50` | `#fffbeb` | Warning backgrounds | `#78350f` |
| `warning-500` | `#f59e0b` | Warning indicators | `#fbbf24` |
| `warning-600` | `#d97706` | **Warning text**, close-to-limit | `#f59e0b` |
| `danger-50` | `#fff4ef` | Error backgrounds | `#5e2f24` |
| `danger-500` | `#e98b73` | Error indicators | `#f0a189` |
| `danger-600` | `#d97757` | **Overspent text**, negative amounts | `#e98b73` |

> **Soft danger for no-guilt finance:** We deliberately avoid alarm red. Overspending is shown with terracotta/salmon tones that still read as caution without scolding the user.

### Neutral

| Token | Hex | Light | Dark |
|---|---|---|---|
| `bg` | `#fafafa` | Page background | `#0f0f11` |
| `surface` | `#ffffff` | Cards, sheets, modals | `#1a1a1e` |
| `surface-elevated` | `#ffffff` | Elevated cards (shadow) | `#242428` |
| `border` | `#e2e4e8` | Dividers, input borders | `#2e2e33` |
| `border-subtle` | `#f2f4f7` | Section dividers | `#1f1f23` |
| `text-primary` | `#1b1b1f` | Headings, primary text | `#f0f0f5` |
| `text-secondary` | `#63666e` | Labels, hints, timestamps | `#9ca3af` |
| `text-tertiary` | `#a1a5ad` | Placeholders, disabled | `#6b7280` |

### Transaction direction colors

| Direction | Light | Dark |
|---|---|---|
| Expense | `danger-600` (`#d97757`) | `danger-500` (`#e98b73`) |
| Income | `success-600` (`#059669`) | `success-500` (`#10b981`) |
| Transfer | `primary-600` (`#5c64cc`) | `primary-500` (`#6e76d8`) |

---

## 3. Typography

Font family: system font stack.

- Sans: `Geist`
- Monospace: `Geist Mono`

Use `Geist` for all UI copy and headings. Use `Geist Mono` for amounts and code-like values. This borrows some of Revolut's branded typographic confidence while staying cleaner and more product-oriented than a marketing display face.

### Scale

| Token | Size | Weight | Line Height | Use |
|---|---|---|---|---|
| `display` | 40px | 700 | 1.1 | Safe-to-Spend hero number |
| `h1` | 28px | 700 | 1.2 | Screen titles |
| `h2` | 21px | 600 | 1.3 | Section headers, card titles |
| `h3` | 17px | 600 | 1.4 | List item titles, row labels |
| `body` | 15px | 400 | 1.6 | Body text, descriptions |
| `body-medium` | 15px | 500 | 1.6 | Emphasized body |
| `caption` | 13px | 400 | 1.5 | Secondary labels, timestamps |
| `caption-medium` | 13px | 500 | 1.5 | Category labels, account names |
| `micro` | 11px | 600 | 1.4 | Badges, tags, uppercase labels |

### Tracking

- `display`: `-1.2px`
- `h1`: `-0.6px`
- `h2`: `-0.3px`
- `h3`: `-0.2px`
- `body-medium`: `-0.1px`
- `caption-medium`: `-0.1px`
- `micro`: `0.4px`

Use subtle negative tracking on primary headings and amount displays to reduce the generic Material feel and create a denser, more premium rhythm.

### Amount display

Amounts use tabular figures (monospace) to prevent jitter when numbers change.

| Context | Size | Weight | Color |
|---|---|---|---|
| Hero amount (Safe-to-Spend) | `display` (40px) | 700 | `text-primary` |
| Row amount | `h3` (17px) | 600 | Direction color |
| Secondary amount | `body` (15px) | 500 | `text-secondary` |
| Budget amount | `caption` (13px) | 500 | `text-tertiary` |

---

## 4. Spacing Scale

Base unit: **4px**.

| Token | Value |
|---|---|
| `space-1` | 4px |
| `space-2` | 8px |
| `space-3` | 12px |
| `space-4` | 16px |
| `space-5` | 20px |
| `space-6` | 24px |
| `space-8` | 32px |
| `space-10` | 40px |
| `space-12` | 48px |

### Page padding

- Mobile: `16px` horizontal
- Tablet: `24px` horizontal
- Desktop: `40px` horizontal (max-width 800px centered)

### Card padding

- Standard card: `16px` all sides
- Compact card: `12px` all sides
- Sheet padding: `20px` horizontal, `16px` vertical

---

## 5. Border Radius

| Token | Value | Use |
|---|---|---|
| `radius-sm` | 6px | Buttons, chips, small elements |
| `radius-md` | 10px | Input fields, small cards |
| `radius-lg` | 14px | Standard cards |
| `radius-xl` | 18px | Modals, sheets, large cards |
| `radius-full` | 9999px | Pills, avatars, circular buttons |

---

## 6. Shadows & Elevation

| Token | Value | Use |
|---|---|---|
| `shadow-sm` | `0 1px 2px rgba(0,0,0,0.04)` | Subtle card lift |
| `shadow-md` | `0 4px 12px rgba(0,0,0,0.06)` | Cards, bottom sheets |
| `shadow-lg` | `0 8px 24px rgba(0,0,0,0.08)` | Modals, elevated elements |
| `shadow-island` | `0 -2px 10px rgba(0,0,0,0.1)` | Add island elevation |

---

## 7. Component Library

### 7.1 Buttons

#### Primary button
- Background: `primary-600`
- Text: white, `body-medium` weight
- Padding: `12px 20px`
- Radius: `radius-full` (pill)
- Pressed: `primary-700`
- Disabled: `primary-100` bg, `primary-500` text

#### Secondary button
- Background: `surface`
- Border: 1px `border`
- Text: `text-primary`, `body-medium`
- Padding: `12px 20px`
- Radius: `radius-full`
- Pressed: `bg` background

#### Ghost button
- Background: transparent
- Text: `primary-600`, `body-medium`
- Padding: `8px 12px`
- Radius: `radius-sm`
- Pressed: `primary-50` background

#### Icon button
- Size: `40px × 40px`
- Background: `surface`
- Border: 1px `border-subtle`
- Icon: `20px`, `text-secondary` color by default
- Radius: `radius-md`
- Use semantic overrides for status icons (sync success/warning/error)
- Pressed: retains card surface treatment, uses ink feedback inside the rounded square

### 7.2 Cards

#### Standard card
- Background: `surface`
- Radius: `radius-lg` (14px)
- Border: 1px `border-subtle`
- Padding: `16px`
- Shadow: minimal in light mode, none required in dark mode
- Default posture is quiet and structural, not floating

#### Hero card
- Background: layered `surface` with a restrained primary-tinted gradient wash
- Radius: `radius-lg` (14px)
- Border: 1px `border-subtle`
- Shadow: `shadow-sm` in light mode, none in dark mode
- Padding: `24px`
- Accent is concentrated in one corner/edge only; avoid loud full-card color blocks
- Use stronger editorial composition here than on ordinary cards: one large value, one short descriptor, one compact status cue

#### Compact row card
- Background: `surface`
- Radius: `radius-md` (10px)
- Border: 1px `border-subtle`
- Padding: `12px 16px` by default, optionally tighter for dense summary cards
- Used in lists (transactions, budgets)

### 7.3 Inputs

#### Text input
- Background: `surface`
- Border: 1px `border`
- Radius: `radius-md`
- Padding: `12px 16px`
- Font: `body`
- Placeholder: `text-tertiary`
- Focus: border color → `primary-500`, subtle `primary-50` bg

#### Search input
- Background: `bg`
- Border: none
- Radius: `radius-full`
- Padding: `10px 16px`
- Left icon: search (`text-tertiary`)
- Focus: `surface` bg, `shadow-sm`

#### Amount input
- Font: monospace, `h3` size
- Prefix: currency symbol (`₱`, `$`, etc.)
- Color: direction color (red/green/blue)

### 7.4 Bottom Sheet

- Background: `surface`
- Radius: `radius-xl` top corners only
- Shadow: `shadow-lg`
- Handle bar: `40px × 4px`, `text-tertiary` color, centered top
- Padding: `20px` horizontal, `16px` top (below handle), `32px` bottom (safe area)
- Max height: 85% of screen
- Dismiss: swipe down, tap scrim

### 7.5 Tab Bar

- Background: `surface`
- Height: `64px` + safe area
- Border top: 1px `border-subtle`
- 4 tabs: equal width, icon + label stacked
- Active tab: `primary-600` icon + label
- Inactive tab: `text-tertiary` icon + label
- Label: `micro` size, `caption-medium` weight

#### Add island
- Position: rightmost, separated from tabs
- Background: `primary-600`
- Icon: plus, white, `28px`
- Size: `56px × 44px` (wider than tall)
- Radius: `radius-lg` on left side, flush with right edge
- Shadow: `shadow-island`
- Margin left: `8px` gap from More tab
- Margin right: `8px` from screen edge

### 7.6 Progress Bars

#### Budget progress bar
- Height: `8px`
- Radius: `radius-full`
- Background track: `bg`
- Fill color: semantic (emerald/amber/red)
- Animation: smooth width transition `300ms ease`

#### Income vs expense strip
- Container: standard card
- Track shell: `surfaceContainerLow`, `radius-lg`, `4px` inner padding
- Bar height: `8px`
- Summary copy: one-line compact sentence using semantic amount colors
- Purpose: quick ratio read, not a detailed chart

#### Sparkline
- Stroke width: `2px`
- Color: `primary-500`
- Fill: gradient from `primary-500` at 10% opacity to transparent
- No grid, no axes — just the line

### 7.7 Badges & Chips

#### Filter chip (active)
- Background: `primary-50`
- Border: 1px `primary-200`
- Text: `primary-700`, `caption-medium`
- Padding: `6px 12px`
- Radius: `radius-full`

#### Filter chip (inactive)
- Background: `surface`
- Border: 1px `border`
- Text: `text-secondary`, `caption`
- Padding: `6px 12px`
- Radius: `radius-full`

#### Status badge
- Background: semantic color at 10% opacity
- Text: semantic color, `micro` size, uppercase
- Padding: `4px 8px`
- Radius: `radius-sm`

### 7.8 Lists

#### Transaction row
- Background: transparent inside a parent section card
- Padding: `12px 0` when used in section cards, `12px 16px` when freestanding
- Layout: flex row
  - Left: avatar/icon (`40px` circle)
  - Center: payee name (`body-medium`), category + account (`caption`)
  - Right: amount (`mono`, 15–17px, direction color), time (`caption-medium`)
- Separator: `1px` `border-subtle` between rows

Grouped dashboard lists should prefer one outer section card with internal dividers instead of stacking many mini-cards.

#### Section header (grouped list)
- Text: `caption-medium`, `text-secondary`
- Padding: `8px 16px`
- Background: `bg` (sticky)

### 7.9 Empty State

- Centered vertically and horizontally
- Illustration: `120px` friendly vector
- Headline: `h2`, `text-primary`
- Subtext: `body`, `text-secondary`
- Primary CTA: primary button
- Secondary CTA: ghost button (optional)
- Spacing between elements: `space-4`

---

## 8. Layout Grid

### Dashboard composition

Dashboard sections follow a fixed top-to-bottom hierarchy:

1. Safe-to-Spend hero
2. Net worth sparkline
3. Account summary cards
4. Income vs expense strip
5. Budget progress rings
6. Spending by category
7. Recent transactions
8. Upcoming recurring
9. Insights (only when present)

Rhythm rules:

- Use `space-4` (`16px`) between dashboard sections by default
- Prefer one strong hero followed by quieter structural cards
- Avoid consecutive “card inside card inside card” stacks
- Let typography and spacing carry hierarchy before adding more color
- Borrow from Revolut only at the composition level: stronger spotlight moments, not louder default chrome

### Mobile (default)
- Single column
- Page padding: `16px`
- Card gap: `12px`
- Content max-width: 100%

### Tablet (≥ 600px)
- Dashboard: 2-column card grid
- Transactions: master-detail split (list 40%, detail 60%)
- Budgets: 2-column grid
- More: 2-column section grid
- Page padding: `24px`

### Desktop (≥ 900px)
- Centered container, max-width `800px`
- Page padding: `40px`

---

## 9. Dark Mode

System preference by default. Toggle in Settings → Appearance.

### Mapping

| Light Token | Dark Token |
|---|---|
| `bg` (`#fafafa`) | `#0f0f11` |
| `surface` (`#ffffff`) | `#1a1a1e` |
| `surface-elevated` (`#ffffff`) | `#242428` |
| `border` (`#e2e4e8`) | `#2e2e33` |
| `text-primary` (`#1b1b1f`) | `#f0f0f5` |
| `text-secondary` (`#63666e`) | `#9ca3af` |
| `text-tertiary` (`#a1a5ad`) | `#6b7280` |

Semantic colors stay the same hex values in dark mode for consistency, but backgrounds use darker variants.

### Dark mode specifics
- Cards have 1px `border-subtle` instead of relying on shadow
- Shadows are reduced (less visible on dark bg)
- Primary accents appear as restrained tinted washes, not neon surfaces
- Illustrations use inverted or dark-adapted versions

---

## 10. Iconography

- Library: `phosphor-icons` or `lucide-react` (Flutter: `phosphor_flutter`)
- Weight: `regular` (default), `bold` for active states
- Size: `20px` (tab bar), `24px` (buttons), `16px` (inline)
- Color: inherits from text token

### Key icons

| Context | Icon |
|---|---|
| Dashboard tab | `House` |
| Transactions tab | `List` |
| Budgets tab | `ChartPie` |
| More tab | `SquaresFour` |
| Add island | `Plus` |
| Search | `MagnifyingGlass` |
| Filter | `SlidersHorizontal` or `Funnel` |
| Sync status | `CloudCheck`, `CloudUpload`, `TriangleAlert`, `LoaderCircle` |
| Close sheet | `X` |
| Back | `CaretLeft` |
| Edit | `Pencil` |
| Delete | `Trash` |
| Mic (voice) | `Microphone` |
| Camera (scan) | `Camera` |
| Bolt (quick) | `Lightning` |

---

## 11. Animation & Motion

### Principles
- **Fast:** Most transitions ≤ 300ms
- **Purposeful:** Motion guides attention, never decorative
- **Subtle:** No bounces, no elastic snaps

### Patterns

| Interaction | Duration | Easing |
|---|---|---|
| Bottom sheet enter | 250ms | `cubic-bezier(0.32, 0.72, 0, 1)` |
| Bottom sheet dismiss | 200ms | `cubic-bezier(0.32, 0.72, 0, 1)` |
| Page push | 300ms | `cubic-bezier(0.4, 0, 0.2, 1)` |
| Tab switch | 150ms | `ease-in-out` |
| Progress bar fill | 300ms | `ease-out` |
| Button press | 100ms | `ease-out` |
| Card hover (web) | 150ms | `ease-out` |
| Snackbar enter | 200ms | `ease-out` |
| Snackbar exit | 150ms | `ease-in` |

### Reduced motion
- Respect `prefers-reduced-motion`
- Disable all non-essential animations
- Keep instant state changes

---

## 12. Accessibility

### Minimums
- Touch target: `44×44dp` minimum (Apple HIG), `48×48dp` preferred (Material)
- Color contrast: WCAG AA minimum (4.5:1 for text, 3:1 for UI components)
- Font scaling: supports up to 200% system font size
- Focus indicators: visible focus rings on all interactive elements (web)

### Screen readers
- All icons have semantic labels
- Charts have `aria-label` with data summary
- Bottom sheets announce "Sheet opened" + title
- Transaction rows: "[Payee], [Category], [Amount], [Date]"

### Color independence
- Never use color as the sole indicator
- Pair with: icon, text label, or pattern
- Example: budget progress bars show percentage text even when color indicates status

---

## 13. Asset Guidelines

### Illustrations (empty states)
- Style: Simple, friendly vector illustrations. Flat design, no photorealism.
- Color: Uses primary accent + neutrals only. No complex gradients.
- Size: `120px` display size, SVG format
- Examples: empty wallet, empty envelope, empty chart, friendly character

### Avatars
- Payee initials: circular, `40px`, `bg` background, `text-secondary` text
- Category icons: circular, `36px`, colored background (category color at 15% opacity), white icon

---

## 14. Platform Notes

### iOS
- Use `Cupertino` for page transitions (slide from right)
- Bottom sheets use iOS-style spring animation
- Status bar: light content on dark nav, dark content on light nav
- Safe area insets respected

### Android
- Use `Material` for page transitions (fade + scale)
- Bottom sheets use Material motion
- Status bar: follows theme (light/dark)
- Edge-to-edge content with gesture navigation padding

### Web (future)
- Max-width container centered
- Hover states on cards and buttons
- Keyboard navigation with visible focus rings
- Responsive breakpoints at 600px and 900px

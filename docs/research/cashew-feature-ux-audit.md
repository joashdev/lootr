# Cashew Feature and UI/UX Audit

Primary-source research for Lootr’s product comparison and V1 planning.

**Source snapshot:** local Cashew repository, branch `main`, commit `9cfbe50c16d95429891d44faf5f2c77a3abdb93b` (2026-03-08).

**Method:** static inspection of Cashew’s first-party README, Flutter pages/widgets, default preferences, Drift schema, and platform database implementations. “Implemented” below means that a user-facing page, widget, persistence field, or behavior exists in this source snapshot; it does not prove that every platform path is bug-free or that every feature is free rather than premium-gated.

**Citation convention:** paths beginning with `Cashew/` are relative to the external-source checkout root. Line ranges are 1-based and refer to the source snapshot above.

---

## 1. Executive assessment

Cashew is a mature, broad personal-finance tracker built around an unusually deep transaction model and an unusually configurable interface. A long-time user will recognize it less by any single “hero” feature than by four combined traits:

1. **Fast entry with remembered context.** The amount entry is calculator-capable and keyboard-aware; titles can be remembered and associated with categories; account, budget, goal, loan, date, type, and notes remain close to the transaction form. Evidence: `Cashew/budget/lib/widgets/selectAmount.dart:153-285`; `Cashew/budget/lib/pages/addTransactionPage.dart:3001-3057`.
2. **One transaction record supports many real-life states.** Upcoming, subscription, repetitive, lent, and borrowed are explicit transaction types with paid/skipped state, recurrence, end dates, notifications, goals, and account relationships. Evidence: `Cashew/budget/lib/database/tables.dart:42-84,273-339`.
3. **Progressive power.** Defaults expose a relatively ordinary home and transaction list, while filters, multiple charts, home modules, navigation shortcuts, batch operations, custom currencies, number formatting, themes, and automation sit behind secondary pages, sheets, long presses, and settings. Evidence: `Cashew/budget/lib/struct/defaultPreferences.dart:24-123,155-231`; `Cashew/budget/lib/pages/settingsPage.dart:426-625`.
4. **Local data with escape hatches, not a strict local-only posture.** Native data is stored in an on-device SQLite file and web data in IndexedDB/local storage; the user can export CSV or the full database. Google Drive backup/sync and optional Gmail access add cloud capability and privacy surface area. Evidence: `Cashew/budget/lib/database/platform/native.dart:10-45`; `Cashew/budget/lib/database/platform/web.dart:9-55`; `Cashew/budget/lib/widgets/exportCSV.dart:74-176`; `Cashew/budget/lib/widgets/accountAndBackup.dart:112-164`.

The best V1 lessons for Lootr are therefore not “copy Cashew’s breadth.” They are:

- preserve a short, obvious entry path while making advanced attributes available without leaving the flow;
- remember user choices and reduce repeated categorization work;
- let summaries drill into the exact transactions behind them;
- make recurrence an explicit lifecycle with **pay**, **skip**, and original-due-date history;
- provide trustworthy import, export, and full-fidelity backup before asking a user to move years of records;
- add bounded personalization (home sections and their order) while resisting a settings surface as large as Cashew’s.

---

## 2. Implemented end-user feature inventory

### 2.1 Transactions and daily capture

| Capability | What a Cashew user experiences | Primary-source evidence | Confidence |
|---|---|---|---|
| Expense and income entries | The form can change polarity and presents income/expense selection. Lent/borrowed selection flips consistently when polarity changes. | `Cashew/budget/lib/pages/addTransactionPage.dart:351-364`; `Cashew/budget/lib/pages/addBudgetPage.dart:703-713` | High |
| Rich transaction fields | A persisted transaction includes title, signed amount, note, category/subcategory, account, date, due date, type, recurrence, end date, notification flag, paid/skipped state, goal/loan references, transfer pair, and budget exclusions. | `Cashew/budget/lib/database/tables.dart:273-339` | High |
| Calculator amount entry | Physical keyboard and number pad input support digits, multiplication, division, addition, subtraction, decimal input, copy/paste, backspace, and Enter-to-accept; expressions are evaluated before return. | `Cashew/budget/lib/widgets/selectAmount.dart:153-285` | High |
| Configurable number pad | Number-pad arrangement, extra-zero button, haptics, decimal precision, and locale/custom formatting exist as preferences. | `Cashew/budget/lib/struct/defaultPreferences.dart:217-231`; `Cashew/budget/lib/pages/settingsPage.dart:1711-1765` | High |
| Remembered titles / smart category association | Saved titles map to categories, can match exact or partial strings, and are automatically created/moved to the top after entry. | `Cashew/budget/lib/database/tables.dart:390-408`; `Cashew/budget/lib/pages/addTransactionPage.dart:3001-3057` | High |
| Categories and subcategories | Categories have custom names, colors, image/emoji icons, ordering, income defaults, and parent-category relationships. | `Cashew/budget/lib/database/tables.dart:342-373` | High |
| Account selection inline | Accounts appear as colored chips in the transaction form; more than three collapse behind a picker; long press opens account editing and an add control is present. | `Cashew/budget/lib/pages/addTransactionPage.dart:1400-1475` | High |
| Budget, goal, and loan attribution | An entry can be explicitly added to a budget, goal, or long-term loan, with mutual-exclusion handling for goals versus loans. | `Cashew/budget/lib/pages/addTransactionPage.dart:299-343,1478-1499` | High |
| More-options disclosure | Secondary controls such as inclusion in balance and budget exclusion are hidden behind a “More options” expansion when not already relevant. | `Cashew/budget/lib/pages/addTransactionPage.dart:1528-1668` | High |
| Duplicate and duplicate-for-now | An existing transaction has a duplicate button; long press duplicates using the current date. Batch duplication is also supported for a limited number of selected entries. | `Cashew/budget/lib/pages/addTransactionPage.dart:1614-1647`; `Cashew/budget/lib/widgets/selectedTransactionsAppBar.dart:261-307` | High |
| Transfers / paired transactions | The schema has paired transaction keys, and edit/delete code asks whether both transfer sides should be updated. Accounts can be initialized/corrected through paired balance-correction behavior. | `Cashew/budget/lib/database/tables.dart:275-279`; `Cashew/budget/lib/pages/addTransactionPage.dart:504-523`; `Cashew/budget/lib/pages/addWalletPage.dart:92-104` | High |
| Notes with links | Notes are stored up to 500 characters; the add form uses a link-highlighting controller and extracted-link actions. | `Cashew/budget/lib/database/tables.dart:33-35,280-283`; `Cashew/budget/lib/pages/addTransactionPage.dart:723-735,4284-4364` | Medium-high |
| Add-source provenance | Transactions can record how they were added, and debug/advanced display can expose this provenance and the transaction ID. | `Cashew/budget/lib/database/tables.dart:318-320`; `Cashew/budget/lib/pages/addTransactionPage.dart:1671-1699` | High |

### 2.2 Recurring, scheduled, subscription, and loan behavior

Cashew distinguishes five special types: upcoming, subscription, repetitive, credit (lent), and debt (borrowed). These are not merely tags; their UI and lifecycle differ. Evidence: `Cashew/budget/lib/database/tables.dart:44-55`; `Cashew/README.md:121-127`.

| Capability | User-visible behavior | Primary-source evidence |
|---|---|---|
| Scheduled/upcoming entries | Upcoming entries live on a dedicated upcoming/overdue page with add, search, status filtering, and date-aware presentation. | `Cashew/budget/lib/pages/upcomingOverdueTransactionsPage.dart:36-88` |
| Subscription summary | Dedicated subscription page can normalize totals to monthly, yearly, or total and shows each recurrence interval and upcoming date. | `Cashew/budget/lib/pages/subscriptionsPage.dart:31-183,186-315` |
| Repetition period and end date | Recurring entries persist period length, daily/weekly/monthly/yearly recurrence, and optional end date. | `Cashew/budget/lib/database/tables.dart:303-309`; `Cashew/budget/lib/pages/addTransactionPage.dart:1203-1320` |
| Explicit pay / deposit / skip | The due-item confirmation offers pay/deposit, skip, or cancel and shows occurrences remaining when calculable. | `Cashew/budget/lib/struct/upcomingTransactionsFunctions.dart:214-288` |
| Audit-friendly due date | Paying stores the original due date, optionally uses the original date instead of “now,” marks the current occurrence paid, and creates the next occurrence. | `Cashew/budget/lib/database/tables.dart:298-317`; `Cashew/budget/lib/struct/upcomingTransactionsFunctions.dart:291-323` |
| Duplicate-resistant recurrence | Future occurrences get predictable derived IDs, specifically to prevent duplicates across sync clients. | `Cashew/budget/lib/struct/upcomingTransactionsFunctions.dart:192-212` |
| Automatic pay controls | Separate defaults exist for automatically paying upcoming, repetitive, and subscription entries. | `Cashew/budget/lib/struct/defaultPreferences.dart:116-121` |
| One-time and long-term loans | Credit/debt pages split one-time transactions from long-term loan objectives, show “you get/you owe,” and support search and lent/borrowed filtering. | `Cashew/budget/lib/pages/creditDebtTransactionsPage.dart:38-60,89-177,179-310` |
| Local reminders and deep links | Daily/upcoming notifications can open add, open a specific transaction, or open upcoming/overdue; notification settings control time and reminder policy. | `Cashew/budget/lib/struct/initializeNotifications.dart:16-144`; `Cashew/budget/lib/struct/defaultPreferences.dart:148-153` |

### 2.3 Accounts and currencies

| Capability | What is implemented | Primary-source evidence |
|---|---|---|
| Multiple named accounts | Accounts (“wallets” internally) have a name, color, ordering, currency, decimal precision, and per-account home-widget inclusion. | `Cashew/README.md:262-268`; `Cashew/budget/lib/database/tables.dart:250-271` |
| Initial account balance | Creating an account can create a balance correction for its initial balance. | `Cashew/budget/lib/pages/addWalletPage.dart:92-104,265-295` |
| Per-account currency and precision | Account creation selects a currency and supports 0–12 decimal places. | `Cashew/budget/lib/pages/addWalletPage.dart:58-68,224-263` |
| Searchable currency picker | Currency search matches country, currency name, or code; the UI shows popular and custom currencies first, then “view all.” | `Cashew/budget/lib/widgets/currencyPicker.dart:36-120,122-263` |
| Exchange-rate management | The picker links to an exchange-rate page; users can override rates and define custom currencies/rates. | `Cashew/budget/lib/widgets/currencyPicker.dart:151-180`; `Cashew/budget/lib/pages/exchangeRatesPage.dart:240-320`; `Cashew/budget/lib/struct/defaultPreferences.dart:161-162,189` |
| Cross-account conversion | README describes home-level account/currency switching and automatic conversions while retaining the original account amount. Source preferences and account schema support cached exchange data and selected account state. | `Cashew/README.md:129-132`; `Cashew/budget/lib/struct/defaultPreferences.dart:30,161-170` |
| Balance transfer tab | A dedicated preference enables the transactions balance-transfer tab. | `Cashew/budget/lib/struct/defaultPreferences.dart:206-210` |

### 2.4 Budgets

Cashew’s budget is a reusable query plus a spending limit, not only “category X has N per month.”

| Capability | What is implemented | Primary-source evidence |
|---|---|---|
| Flexible periods | Custom, daily, weekly, monthly, and yearly periods, with period length and start/end dates. | `Cashew/budget/lib/pages/addBudgetPage.dart:68-105,107-126`; `Cashew/budget/lib/database/tables.dart:423-456` |
| Expense and savings budgets | Budget creation explicitly labels the two polarities “expense budget” and “savings budget.” | `Cashew/budget/lib/pages/addBudgetPage.dart:703-713` |
| Inclusive or exclusive category scope | A budget can include selected categories, exclude selected categories, span selected accounts, or use only explicitly added transactions. | `Cashew/budget/lib/database/tables.dart:430-444`; `Cashew/budget/lib/pages/addBudgetPage.dart:169-199` |
| Fine-grained inclusion policy | Budget filters determine handling of transactions added to other budgets/goals, shared items, income, debt/credit, and balance corrections. | `Cashew/budget/lib/database/tables.dart:73-115,453-460` |
| Category-specific limits | A separate relation stores a limit for a category, budget, and account; the budget pie view links directly to editing spending goals. | `Cashew/budget/lib/database/tables.dart:375-388`; `Cashew/budget/lib/pages/budgetPage.dart:203-223` |
| Interactive budget detail | The detail page computes the current period, total spent, category totals, pie selection, time progress, and filtered transactions. | `Cashew/budget/lib/pages/budgetPage.dart:162-225,228-320` |
| History across periods | Past-budget history builds streams for consecutive budget periods, supports category watch lines, and opens historical periods. | `Cashew/budget/lib/pages/pastBudgetsPage.dart:39-169,178-253` |
| Pin, archive, duplicate | Budgets persist pinned/archive state, ordering, and can be duplicated when custom. | `Cashew/budget/lib/database/tables.dart:439-474`; `Cashew/budget/lib/pages/addBudgetPage.dart:611-650` |
| Shared budgets | The schema and add flow support owner/member state and shared members; online access is required for shared updates. | `Cashew/budget/lib/database/tables.dart:461-469`; `Cashew/budget/lib/pages/addBudgetPage.dart:232-283` |

### 2.5 Goals and loans

| Capability | What is implemented | Primary-source evidence |
|---|---|---|
| Spending and saving goals | A goal stores target amount, income/expense direction, optional end date, account, color, image/emoji, pin/archive state, and order. | `Cashew/budget/lib/database/tables.dart:513-539` |
| Transaction-funded progress | Transactions reference goals and long-term loans directly; goal pages stream progress from linked transactions. | `Cashew/budget/lib/database/tables.dart:331-334`; `Cashew/budget/lib/pages/objectivePage.dart:149-176,269-320` |
| Completion feedback | Goal completion plays confetti once and presents a circular progress visualization. | `Cashew/budget/lib/pages/objectivePage.dart:75-110,269-318` |
| Loan-specific initialization | Creating a conventional long-term loan asks for the first transaction’s category and creates an initial linked transaction. | `Cashew/budget/lib/pages/addObjectivePage.dart:218-267` |
| Spending/saving and lent/borrowed semantics | The same objective system supports goals versus loans and changes polarity/labels accordingly. | `Cashew/budget/lib/database/tables.dart:52-55`; `Cashew/README.md:266-272` |

### 2.6 Search, filters, and bulk actions

Cashew’s search model is one of its strongest “power user without desktop software” features.

- **Filter dimensions:** account, category, subcategory including “none,” included budget, excluded budget, goal, loan, expense/income, positive cash flow, paid status, special transaction type, budget inclusion behavior, add method, amount range, date range, general search, title contains, and note contains. Evidence: `Cashew/budget/lib/pages/transactionFilters.dart:26-90`.
- **Persistent filter state:** search and transaction-list filters serialize into settings and reload on page entry. Evidence: `Cashew/budget/lib/pages/transactionFilters.dart:185-375`; `Cashew/budget/lib/pages/transactionsSearchPage.dart:50-61,80-100`; `Cashew/budget/lib/pages/transactionsListPage.dart:64-112`.
- **Smart query interpretation:** a numeric query becomes an amount range, while localized month-name queries can become date searches. Evidence: `Cashew/budget/lib/pages/transactionFilters.dart:378-469`.
- **Filter visibility:** active filter buttons receive a selected color and applied filters render as chips above results. Evidence: `Cashew/budget/lib/pages/transactionsSearchPage.dart:227-303`; `Cashew/budget/lib/pages/transactionsListPage.dart:132-158,199-209`.
- **Month-first browsing:** transactions use an effectively infinite month pager, arrow navigation, and a synchronized month selector. Evidence: `Cashew/budget/lib/pages/transactionsListPage.dart:115-122,159-270`.
- **Batch selection:** long press begins selection, pointer-drag can select or deselect multiple rows with haptic feedback, and a contextual app bar reports count and total. Evidence: `Cashew/budget/lib/widgets/transactionEntry/swipeToSelectTransactions.dart:6-74`; `Cashew/budget/lib/widgets/selectedTransactionsAppBar.dart:76-246`.
- **Batch operations:** delete, duplicate, settle/collect, reassign accounts, and attach budgets/goals/loans are conditionally available from the selection menu. Evidence: `Cashew/budget/lib/widgets/selectedTransactionsAppBar.dart:309-805`.
- **Share/copy:** selected transaction details and total can be shared or copied; long press changes share to copy. Evidence: `Cashew/budget/lib/widgets/selectedTransactionsAppBar.dart:38-71,139-225`.

### 2.7 Dashboard, charts, and reports

The home screen can contain:

- account switcher;
- account list;
- pinned budgets;
- goals;
- overdue/upcoming;
- income and expenses;
- net worth;
- credit/debt;
- long-term loans;
- spending line graph;
- category pie chart;
- calendar-style spending heat map;
- recent transactions.

Evidence: `Cashew/budget/lib/pages/homePage/homePage.dart:178-219`; defaults and ordering are in `Cashew/budget/lib/struct/defaultPreferences.dart:44-106`.

Reporting interactions are more valuable than the raw chart count:

- **Line graph:** default 30 days, all time, custom start date, or a specific budget; cumulative versus per-day rendering is configurable. Evidence: `Cashew/budget/lib/pages/editHomePage.dart:230-319`; `Cashew/budget/lib/pages/homePage/homePageLineGraph.dart:16-93,203-211`.
- **Pie chart:** incoming/outgoing mode, account scope, expandable subcategories, tap category to open the corresponding filtered transaction search, and long press to change settings. Evidence: `Cashew/budget/lib/pages/homePage/homePagePieChart.dart:28-63,212-253,260-351`.
- **Income/expense summary:** outgoing and incoming totals open filtered transaction search; long press opens period settings. Evidence: `Cashew/budget/lib/pages/homePage/homePageAllSpendingSummary.dart:18-117`.
- **Net worth:** account-scoped totals, period-cycle selection, and navigation to account details with the same filter context. Evidence: `Cashew/budget/lib/pages/homePage/homePageNetWorth.dart:22-116,134-268`.
- **Heat map:** day cells are interactive and tooltipped, and the component derives daily totals rather than cumulative totals. Evidence: `Cashew/budget/lib/pages/homePage/homePageHeatmap.dart:22-74,197-257`.
- **Budget report:** category pie selection is connected to category lists and filtered transaction records, while history compares multiple periods and chosen categories. Evidence: `Cashew/budget/lib/pages/budgetPage.dart:162-223`; `Cashew/budget/lib/pages/pastBudgetsPage.dart:114-169,196-253`.

### 2.8 Import, export, backup, and sync

| Capability | What is implemented | Primary-source evidence |
|---|---|---|
| CSV export | Exports paid transactions for all time or a chosen date range and chosen accounts. Columns include account, amount, currency, title, note, date, income flag, type, category/subcategory, visual metadata, budget, and goal. | `Cashew/budget/lib/widgets/exportCSV.dart:74-176,205-319` |
| CSV import with mapping | Detects headers, lets users map required date/amount/category/account and optional title/note, supports a template, decodes non-web files with charset detection, and reports row errors. | `Cashew/budget/lib/widgets/importCSV.dart:54-191,436-501,596-658` |
| Flexible import reconciliation | Import matches or creates categories and accounts, tries ISO/common/custom date formats, supports Mint debit/credit polarity, records imported provenance, and batches transactions/titles. | `Cashew/budget/lib/widgets/importCSV.dart:879-1107,1110-1165` |
| Google Sheets import | Converts a shared Sheet URL to CSV, fetches it, and feeds the same mapping flow; a template link is exposed. | `Cashew/budget/lib/widgets/importCSV.dart:522-594,631-655` |
| Full database export | Backs up settings into the database, reads the database bytes, and saves a `.sql` file to the device. | `Cashew/budget/lib/widgets/exportDB.dart:11-64` |
| Full database restore | Accepts `.sql`/`.sqlite`, warns before overwrite, prevents sync during replacement, writes database bytes, resets sync metadata, and requires app restart/refresh. | `Cashew/budget/lib/widgets/importDB.dart:15-121`; `Cashew/budget/lib/database/platform/native.dart:39-45` |
| Google Drive backup | Google authentication requests Drive app-data access; backups can be made automatically by frequency and old backups pruned by limit. | `Cashew/budget/lib/widgets/accountAndBackup.dart:112-164,302-340,390-420`; `Cashew/budget/lib/struct/defaultPreferences.dart:18-23,133-143` |
| Cross-device sync | Each device uploads a predictable sync backup; sync compares device files and maintains per-client last-sync timestamps. | `Cashew/budget/lib/struct/syncClient.dart:25-71,74-153,201-260` |

Important migration limitation: Cashew’s regular CSV exporter only selects `paid == true` transactions and does not export every persistence field. A Cashew-to-Lootr migration that must preserve scheduled/unpaid/skipped/recurring relationships, transfer pairs, goals, budgets, and settings should treat the full SQLite/database export as the lossless source and CSV as a human-readable fallback. Evidence: `Cashew/budget/lib/widgets/exportCSV.dart:84-95,109-140`; compare with the richer transaction schema at `Cashew/budget/lib/database/tables.dart:273-339`.

### 2.9 Personalization and settings

Cashew’s personalization depth is a product feature in its own right:

- light/dark/system themes, Material You/system color, and custom accent color (`Cashew/budget/lib/pages/settingsPage.dart:435-508`);
- configurable home modules, separate mobile/full-screen visibility, and explicit order/left/right columns (`Cashew/budget/lib/struct/defaultPreferences.dart:44-106`);
- home editing exposes accounts, budgets, goals, upcoming, loans, income/expense, net worth, graphs, pie chart, heat map, and transactions as independently enabled modules (`Cashew/budget/lib/pages/editHomePage.dart:77-239`);
- three customizable bottom-navigation shortcuts plus More (`Cashew/budget/lib/widgets/bottomNavBar.dart:70-105,250-311,343-371`);
- responsive bottom navigation on small screens, sidebar from 700 px, and double-column layout at larger widths (`Cashew/budget/lib/widgets/navigationSidebar.dart:22-63`);
- rounded versus outlined icons, several fonts, full versus minimal animation, number count-up toggle, increased text contrast, haptic controls, first day of week, 12/24-hour behavior, custom number delimiters/decimal/currency order, and percentage precision (`Cashew/budget/lib/struct/defaultPreferences.dart:24-42,174-231`; `Cashew/budget/lib/pages/settingsPage.dart:950-1128,1711-1803`);
- language selection and a large translation asset set, surfaced as a first-level preference (`Cashew/budget/lib/pages/settingsPage.dart:531-554`; `Cashew/README.md:173-178`).

### 2.10 Onboarding and discoverability

The onboarding is three pages rather than a feature tour:

1. introduction with a preview/demo option;
2. actual first-budget creation plus primary-currency change;
3. optional Google sign-in, with a continue-without-sign-in path.

It initializes the default database before budget creation and can generate demo data. Desktop keyboard arrows navigate pages and Escape exits where appropriate. Evidence: `Cashew/budget/lib/pages/onBoardingPage.dart:29-190,230-268,269-417,418-575`.

Discoverability strengths:

- core destinations are explicit in bottom navigation or the wide-screen sidebar; sidebar entries include transactions, budgets, goals, subscriptions, scheduled, loans, and all spending (`Cashew/budget/lib/widgets/navigationSidebar.dart:259-296`);
- the home has a visible edit-home tooltip/action (`Cashew/budget/lib/pages/homePage/homePage.dart:276-286`);
- settings are grouped into theme, preferences, tools/extras, import/export, and backups (`Cashew/budget/lib/pages/settingsPage.dart:435-625`);
- active filters remain visible as selected controls and chips (`Cashew/budget/lib/pages/transactionsSearchPage.dart:227-303`);
- add buttons are contextual—subscription and scheduled pages open the add flow with the correct type preselected (`Cashew/budget/lib/pages/subscriptionsPage.dart:67-78`; `Cashew/budget/lib/pages/upcomingOverdueTransactionsPage.dart:72-85`);
- tooltips are used on charts, FABs, transaction types, colors, and home editing (repository-wide examples listed by `rg "Tooltip\\(" budget/lib`).

Discoverability weaknesses:

- many expert actions depend on long press: edit chips, copy values, change chart settings, duplicate “for now,” edit list settings, or change navigation shortcuts. Long press is efficient after learned but generally invisible before learned. Evidence: `Cashew/budget/lib/pages/addTransactionPage.dart:1406-1415,1634-1639`; `Cashew/budget/lib/pages/homePage/homePage.dart:125-133`; `Cashew/budget/lib/widgets/bottomNavBar.dart:343-371`.
- the sheer number of settings makes the app highly personal but raises configuration and support cost; several defaults are explicitly marked “still in testing” or feature flags in the preferences file. Evidence: `Cashew/budget/lib/struct/defaultPreferences.dart:36-43,127-132,178-204`.
- some functionality is represented both as a transaction type and a dedicated destination (subscriptions, scheduled, loans), which aids frequent use but increases conceptual surface area.

### 2.11 Accessibility, adaptive behavior, and feedback

Positive evidence:

- the reusable tappable primitive declares button semantics, handles mouse cursor state, long press, and right-click parity on web (`Cashew/budget/lib/widgets/tappable.dart:185-235`);
- Android navigation uses Flutter navigation destination semantics and always-visible labels (`Cashew/budget/lib/widgets/bottomNavBar.dart:218-311`);
- tooltips are widely used for icon-only actions;
- an increased-text-contrast toggle exists, and app animations can be reduced to “minimal” (`Cashew/budget/lib/pages/settingsPage.dart:1003-1065`);
- keyboard shortcuts cover global escape/navigation, calculator entry, copy/paste, and onboarding arrows (`Cashew/budget/lib/struct/keyboardIntents.dart:6-60`; `Cashew/budget/lib/widgets/selectAmount.dart:153-285`; `Cashew/budget/lib/pages/onBoardingPage.dart:141-155`);
- responsive layouts switch from bottom navigation to sidebar and then double-column content (`Cashew/budget/lib/widgets/navigationSidebar.dart:22-63`);
- tactile and visual feedback is layered: optional haptics, pressed-opacity animation, animated selection, colored active filters, snackbars, and goal confetti.

Limitations:

- static search found only a small number of explicit `Semantics` wrappers outside Flutter’s stock components, and the generic tappable marks an element as a button without supplying a semantic label. Screen-reader quality cannot be assumed from this source alone.
- several chart/icon/header paths force a text scale of `1.0`, which can undermine large-text accessibility: e.g. `Cashew/budget/lib/widgets/lineGraph.dart:188-237`, `Cashew/budget/lib/widgets/categoryIcon.dart:290`, and `Cashew/budget/lib/pages/homePage/homePageUsername.dart:83`.
- color carries substantial meaning for income/expense, paid/overdue, categories, and selection. Icons, labels, and arrows often supplement it, but contrast and non-color comprehension require runtime testing.
- “minimal” animation exists while a fully disabled mode is present in the enum but excluded from the available settings items. Evidence: `Cashew/budget/lib/pages/settingsPage.dart:1003-1035`.

### 2.12 Offline and privacy posture

**What is demonstrably local/offline-capable**

- native persistence uses a local SQLite file through Drift; reads and writes use foreground/background executors (`Cashew/budget/lib/database/platform/native.dart:10-23`);
- web persistence uses IndexedDB when supported and local storage otherwise (`Cashew/budget/lib/database/platform/web.dart:9-39`);
- full database import/export and CSV import/export work directly with device files (`Cashew/budget/lib/widgets/exportDB.dart:11-64`; `Cashew/budget/lib/widgets/importDB.dart:15-121`);
- Google sign-in defaults to false, and email scanning defaults to false (`Cashew/budget/lib/struct/defaultPreferences.dart:127-139,178-180`);
- biometric/device-credential locking is available on supported non-web devices (`Cashew/budget/lib/struct/initializeBiometrics.dart:24-62,118-189`).

**What prevents calling Cashew strictly privacy-first**

- optional Google sign-in requests profile, email, and Drive app-data scopes; if Gmail automation is enabled it also requests Gmail read and modify scopes (`Cashew/budget/lib/widgets/accountAndBackup.dart:112-164`);
- cross-device sync and backups upload database files to Google Drive’s app-data area (`Cashew/budget/lib/struct/syncClient.dart:126-149,247-260`);
- shared budgets and transaction ownership metadata use server/cloud concepts (`Cashew/budget/lib/database/tables.dart:318-330,461-469`);
- the source contains optional email and notification scanning functionality, although disabled by default (`Cashew/budget/lib/pages/settingsPage.dart:572-591`; `Cashew/budget/lib/struct/defaultPreferences.dart:127-132,178-181`).

The fair conclusion is: **local-first core with opt-in cloud/automation**, not “all data always stays on device.”

### 2.13 Other utilities and automation

These are secondary to Cashew’s core ledger but help explain its mature feature breadth:

| Capability | What is implemented | Primary-source evidence |
|---|---|---|
| App/deep-link automation | Native and web links can prefill or directly create transactions from amount, title, note, date, account, category/subcategory, message text, or JSON. Direct creation records `MethodAdded.appLink`. | `Cashew/budget/lib/widgets/util/appLinks.dart:29-125,127-230,232-300` |
| OS home-screen quick actions | Native quick actions can add a transaction, transfer a balance, or open a specific budget. | `Cashew/budget/lib/struct/quickActions.dart:18-88` |
| Email/notification parsing templates | Scanner templates define identifying text and delimiters for title/amount plus default account/category. Optional Gmail scanning can create a transaction and remember which messages were processed. | `Cashew/budget/lib/database/tables.dart:488-511`; `Cashew/budget/lib/pages/autoTransactionsPageEmail.dart:95-133,395-601` |
| File/photo attachments | Camera, gallery, and file picker uploads go to a user’s Google Drive `Cashew` folder; the resulting Drive link is appended to transaction notes and can be opened, copied, or removed. | `Cashew/budget/lib/struct/uploadAttachment.dart:15-166`; `Cashew/budget/lib/pages/addTransactionPage.dart:4303-4319,4402-4606` |
| Bill splitter | A dedicated tool manages people, line items, equal/custom percentages, and reusable local splitter state. | `Cashew/budget/lib/pages/billSplitter.dart:39-180` |
| Activity log and restore | Recent created/modified and deleted transactions are merged into a chronological activity view. Up to 50 deleted transactions are cached in preferences and can be restored if their category still exists. | `Cashew/budget/lib/pages/activityPage.dart:25-134,136-218` |
| Shared budgets | Owners/members, cloud budget records, shared transactions, member filtering, leave/remove-member behavior, and synchronization metadata exist behind a feature setting. | `Cashew/budget/lib/struct/shareBudget.dart:19-214,222-474` |

---

## 3. UI/UX principles worth carrying into Lootr

### 3.1 Make the common path short and the complete model nearby

Cashew does not force every field into the initial capture step. Title and amount can lead the flow; less common controls expand through chips, bottom sheets, and “More options.” Yet account, budget, goal, loan, recurrence, and notes remain in the same transaction context. This is a strong model for Lootr: keep quick-add quick, but make correction and advanced attribution feel like extending the same action rather than entering a separate admin workflow.

Adopt:

- one dominant save action with a label that tells the user what is missing (“Set name,” “Set amount,” then “Save” is used in Cashew’s budget flow at `Cashew/budget/lib/pages/addBudgetPage.dart:667-697`);
- contextual defaults and preselected type when entering from a dedicated page;
- collapsible advanced fields that automatically reappear when existing data makes them relevant.

Avoid:

- hidden long-press as the only route to a consequential action;
- exposing every Cashew transaction type before Lootr’s core mental model is stable.

### 3.2 Remember intent, not just data

Cashew remembers title-to-category associations, filter state, last tabs, account selection, chart settings, home order, and navigation shortcuts. This converts repeated bookkeeping into a progressively personalized tool.

For Lootr V1, remember only choices with clear repeat value:

- last-used account and transaction polarity;
- merchant/payee title → category suggestion, with transparent override;
- filter state per list;
- selected report period;
- enabled/reordered home modules.

Do not automatically mutate saved financial records based on remembered behavior. Use suggestions and visible defaults.

### 3.3 Let every summary explain itself

Cashew’s category pie, totals, and income/expense cards can open a filtered list representing the underlying records. This is more important than adding more chart types. A financial summary earns trust when the user can answer “which transactions made this number?”

Lootr should define a reusable drill-down contract:

```
summary context
    → explicit filter description
    → canonical transaction list
    → editable transaction
    → back returns to the same summary state
```

Prioritize this for budget totals, category totals, income/expense, and account balances before heat maps or elaborate chart customization.

### 3.4 Treat time as a first-class navigation dimension

Cashew’s infinite month pager, period-cycle pickers, historical budgets, original due dates, and pay/skip recurrence behavior reflect how users actually review money: “this month,” “last cycle,” “what is due,” and “what happened on the original date.”

Adopt:

- month/cycle navigation that preserves filters;
- explicit due versus paid dates for scheduled items;
- recurrent-item state transitions rather than silently generating indistinguishable transactions;
- one consistent period picker shared by reports.

### 3.5 Use layered feedback, but keep the tone calm

Cashew combines selected-state color, icons, labels, animation, optional haptics, snackbars, and goal confetti. Lootr’s calm product direction should keep the layered feedback while using celebration sparingly.

Adopt:

- instant selected-state feedback;
- undoable snackbar after destructive or high-frequency changes;
- optional haptic confirmation for save/selection;
- neutral, factual overdue and limit language.

Defer or soften:

- confetti as a default financial behavior;
- strong red/green polarity without labels or arrows.

### 3.6 Personalize information architecture within boundaries

Cashew’s configurable home and navigation are valuable because personal finance priorities differ: one user watches budgets, another net worth, another upcoming bills. But fully customizable navigation and dozens of display preferences create a product inside the settings page.

For Lootr V1:

- allow hide/show and reorder of a small, curated set of home cards;
- preserve fixed primary navigation;
- keep one canonical transaction list;
- allow each report card to remember account/period scope.

This captures most of Cashew’s usefulness without creating a combinatorial QA matrix.

### 3.7 Design responsive parity, not stretched mobile

Cashew changes navigation mode at width thresholds and uses double-column layouts on larger displays. The principle to adopt is that the same information architecture should become more efficient on larger screens, not merely wider.

For Lootr:

- mobile: bottom navigation, sheets, single-column forms;
- tablet/desktop: persistent side rail and master/detail or two-column composition;
- maintain the same terminology, filters, and actions across form factors.

### 3.8 Build migration confidence into the product

Cashew exposes a CSV template, column mapping, common/custom date parsing, progress, skipped-row errors, and a full database escape hatch. For a user moving their own long-lived Cashew data, migration UX is part of onboarding, not a developer utility.

Lootr should show:

- source file and detected Cashew version/schema;
- entity counts before import;
- mapping/conflict decisions;
- row/entity warnings with downloadable diagnostics;
- post-import reconciliation totals;
- a non-destructive dry run;
- ability to discard the imported workspace and retry;
- an export from Lootr from day one.

---

## 4. V1 adoption recommendations

### 4.1 V1-critical: adopt now

| Pattern/capability | Why it earns V1 scope | Recommended Lootr interpretation |
|---|---|---|
| Fast manual amount entry with calculator operations | Every transaction uses it; small friction compounds daily. | Keep Lootr’s natural-language quick add, but provide a first-class deterministic amount pad/calculator fallback. |
| Remembered payee/title suggestions | Reduces repeated category work without bank integration or cloud AI. | On-device suggestion only; show the proposed category and allow one-tap override. |
| Account-aware entry and balance transfer | Multi-account reality is foundational and already fits Lootr’s domain direction. | Keep transfers explicit and auditable; make the destination/source selection compact. |
| Persistent search/filter with visible chips | Users need to retrieve and verify historical records, especially after migration. | Start with date, account, category, payee/title, amount, income/expense, and transfer; add dimensions only when domain-backed. |
| Month/cycle browsing | Familiar, low-learning-cost review model. | Canonical month selector plus custom date range; preserve active filters. |
| CSV and full-fidelity import/export | Required for Cashew migration trust and user ownership. | Lossless Cashew importer plus generic CSV; export normalized CSV and Lootr backup. |
| Report-to-transactions drill-down | Makes balances and charts explainable. | Every tappable number opens the unified list with explicit filters. |
| Bounded home customization | Lets a long-time Cashew user keep their familiar priorities. | Hide/show/reorder 4–6 cards; no arbitrary navigation replacement in V1. |
| Recurring lifecycle fundamentals | Upcoming bills and subscriptions are common and migration must preserve them. | Recurrence rule, next due date, pay/skip, optional end date, notification, original due date. |
| Local lock and privacy-explicit controls | Sensitive data plus offline-first positioning demands it. | Biometric/device lock, clear local/cloud status, and no account required for V1 core. |

### 4.2 V1 if already supported by Lootr’s model or schedule

- flexible budgets with monthly/weekly/custom date ranges;
- category-scoped budgets and explicit added-only/event budgets;
- budget history across completed cycles;
- savings/spending goals linked to transactions;
- multi-currency accounts with preserved original currency amount and a clear rate source;
- local notifications for due items;
- duplicate transaction and duplicate-for-today;
- reduced motion, increased contrast, and robust screen-reader labels;
- responsive wide-screen side rail and two-column layouts.

These are valuable, but each should be admitted only when migration, testing, and the canonical transaction flow remain solid.

### 4.3 Deliberately defer beyond V1

- Google Drive sync and merge semantics;
- shared/collaborative budgets;
- Gmail or notification scraping;
- arbitrary custom currencies and manual exchange-rate editing;
- one-time plus long-term loan subproducts unless personally essential;
- bill splitter;
- heat map;
- configurable fonts, icon families, number-pad layouts, animation speed, and dozens of display toggles;
- arbitrary bottom-navigation replacement;
- per-device sync backup merging;
- goal confetti and elaborate cosmetic controls.

These features demonstrate Cashew’s maturity but would expand privacy review, platform QA, domain complexity, and settings burden before Lootr’s core promise is proven.

---

## 5. Potential Cashew lessons not to copy literally

1. **Do not make hidden gestures the only affordance.** Long press can remain an accelerator, but expose the same action in a visible overflow menu and teach the shortcut after first use.
2. **Do not let customization fragment the product.** A small set of stable layouts is easier to reason about, document, test, and migrate.
3. **Do not conflate backup with synchronization.** Cashew uses database-file backups as part of cross-device sync. Lootr should preserve its own explicit sync state machine and conflict model rather than inherit file-level assumptions.
4. **Do not claim privacy from local persistence alone.** Cloud scopes, attachment/email automation, sharing, telemetry, and backups must be explained independently.
5. **Do not force text scaling off for charts.** Design charts and category icons to reflow or expose accessible summaries instead of pinning `textScaleFactor` to 1.
6. **Do not make automation silently authoritative.** Auto-pay and remembered categories are convenient, but Lootr’s stated philosophy is stronger when automation suggests or records explicit state transitions and never surprises the ledger.
7. **Do not reproduce Cashew’s terminology collisions.** The source itself notes internal “Wallet” versus front-end “Account” and “Objective” versus “Goal.” Lootr should keep one canonical term at domain, API, UI, import, and documentation boundaries. Evidence: `Cashew/README.md:262-268`.

---

## 6. Ambiguities and limitations

- This is a static source audit, not a runtime walkthrough. Conditional branches, platform plugins, permissions, premium checks, and Firebase/Google behavior were not executed.
- The README is treated as first-party product documentation, but implementation files take precedence when they differ.
- “Premium” gates appear in budget history, goals, transaction entry, and other paths. This audit identifies implemented capability, not free-tier availability.
- Shared budgets, cloud sync, Google Drive backup, Gmail automation, notification scanning, and attachments depend on services or permissions that were not exercised.
- The source snapshot has a broad debug/feature-flag preference set. A code path’s presence does not guarantee that it is publicly enabled.
- Accessibility conclusions are limited to static widget structure. Screen reader order, focus traversal, contrast ratios, dynamic type overflow, touch-target size, and reduced-motion behavior require device testing.
- Currency exchange accuracy, refresh cadence, and offline cache age were not validated; the source establishes cached/custom rate mechanisms, not their market accuracy.
- CSV import/export is intentionally not lossless. Exact Cashew migration should be based on schema-aware SQLite extraction and reconciliation, with CSV used for validation and fallback.
- Attachments are Google Drive files represented as links inside the transaction note rather than first-class rows in the core transaction table. Migration can preserve the URL text but cannot guarantee continued file access, ownership, permissions, or offline availability without a separate Drive-aware plan.
- Cashew is licensed software. Lootr should adopt general interaction principles and independently implement them; it should not copy Cashew branding, illustrations, icon assets, translation text, or source code.

---

## 7. Primary source index

- `Cashew/README.md:111-162` — first-party feature overview.
- `Cashew/budget/lib/database/tables.dart:29-115,250-539` — persisted domain model and enum semantics.
- `Cashew/budget/lib/struct/defaultPreferences.dart:15-331` — default feature flags, home composition, personalization, notifications, report state, accessibility controls.
- `Cashew/budget/lib/pages/addTransactionPage.dart` — capture/edit interactions and title association.
- `Cashew/budget/lib/pages/transactionFilters.dart:26-469` — complete search/filter state and smart parsing.
- `Cashew/budget/lib/pages/transactionsSearchPage.dart:29-303` and `transactionsListPage.dart:28-319` — search/list UX.
- `Cashew/budget/lib/pages/addBudgetPage.dart` and `budgetPage.dart` — budget creation and detail behavior.
- `Cashew/budget/lib/pages/pastBudgetsPage.dart:39-253` — budget history.
- `Cashew/budget/lib/pages/addObjectivePage.dart:45-307` and `objectivePage.dart:37-320` — goals/loans.
- `Cashew/budget/lib/pages/homePage/` — dashboard modules and report drill-down.
- `Cashew/budget/lib/pages/editHomePage.dart:41-319` — configurable home.
- `Cashew/budget/lib/pages/settingsPage.dart:426-625,950-1803` — settings and accessibility/personalization.
- `Cashew/budget/lib/widgets/importCSV.dart` and `exportCSV.dart` — tabular migration surface.
- `Cashew/budget/lib/widgets/importDB.dart` and `exportDB.dart` — full database portability.
- `Cashew/budget/lib/database/platform/native.dart:10-45` and `web.dart:9-55` — local persistence.
- `Cashew/budget/lib/widgets/accountAndBackup.dart` and `struct/syncClient.dart` — Google backup and cross-device sync.
- `Cashew/budget/lib/widgets/util/appLinks.dart`, `struct/quickActions.dart`, and `pages/autoTransactionsPageEmail.dart` — automation paths.
- `Cashew/budget/lib/struct/uploadAttachment.dart` and `pages/activityPage.dart` — attachments and transaction history/restore.

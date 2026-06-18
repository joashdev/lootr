# Task 19 — Local Notifications

**Status:** [ ]

---

## Objective

Implement local notification scheduling for recurring templates, bill due dates, installment dates, and debt reminders. Notifications are fully offline — no cloud push in V1.

References: `docs/navigation-arch.md` §6, `docs/domain-model.md` (notifications domain)

## Dependencies

- 04 — Data Layer — Repositories
- 03 — Data Layer — Drift Schema (notifications table)

## Deliverables

### 19.1 NotificationScheduler (`lib/application/notifications/notification_scheduler.dart`)
Singleton service that manages all local notification scheduling.

**Schedule triggers:**
- Called after sync (postSyncHook)
- Called after creating/editing/deleting recurring templates
- Called after creating/editing debt records
- Called on app start (reschedule all after reboot)

**Notification types:**
| Type | Trigger | Content |
|---|---|---|
| `recurring_reminder` | `next_occurrence_at` of recurring template with `reminder_enabled=true` | "Pay {payee} ₱{amount} — {account}" |
| `bill_due` | Installment transaction's next due date | "Bill due: {note} ₱{amount}" |
| `installment_due` | Parent transaction's next installment date | "Installment due: {note}" |
| `debt_reminder` | Debt record due date | "{counterparty}: ₱{remaining} remaining" |
| `subscription_reminder` | Recurring template marked as subscription | "Subscription: {payee} ₱{amount}" |

### 19.2 Database integration
- Reads from `recurring_templates` table for upcoming occurrences
- Reads from `debt_records` table for active debt reminders
- Reads from `transactions` table for installment schedules
- Writes scheduled notifications to `notifications` table
- Marks `is_completed = true` when notification is delivered

### 19.3 Platform integration
- Request notification permissions (iOS: ask on first schedule; Android: on app start)
- Handle permission denied gracefully (notifications disabled silently)
- Android notification channel: "Lootr Reminders" with default importance
- iOS: use `flutter_local_notifications` with sound badge

### 19.4 Deep link handling
On notification tap, navigate to correct screen:

| Notification type | Deep link path |
|---|---|
| `bill_due` | `/transactions?filter=installment` |
| `installment_due` | `/transactions?filter=installment` |
| `recurring_reminder` | `/recurring/{template_id}` |
| `debt_reminder` | `/debts/{debt_id}` |
| `subscription_reminder` | `/recurring?filter=subscription` |

Wire into `go_router` deep link handling.

### 19.5 Notification settings
- Toggles per notification type (from `notification_settings_screen.dart`)
- Persisted in SharedPreferences
- Default: all enabled except subscription reminders

### 19.6 Notification cleanup
- Remove delivered notifications (is_completed=true) after 7 days
- Remove scheduled notifications for deleted templates/debts
- Limit to 64 pending notifications (iOS limit)

## Acceptance Criteria

- [ ] Recurring reminders are scheduled for templates with `reminder_enabled=true`
- [ ] Notification fires at correct date/time
- [ ] Tapping notification deep links to correct screen
- [ ] Notification settings toggles enable/disable per type
- [ ] Permissions are requested and handled gracefully
- [ ] `notifications` table is updated (is_completed=true) on delivery
- [ ] Rescheduling works after app restart
- [ ] Deleted templates/debts cancel their scheduled notifications
- [ ] iOS 64-notification limit is respected

## Files Likely Affected

- `lib/application/notifications/notification_scheduler.dart` (new)
- `lib/application/notifications/notification_deep_link.dart` (new)
- `lib/application/providers/notification_provider.dart` (new)
- `lib/core/router/app_router.dart` (update — deep link handling)
- `lib/data/repositories/recurring_repo.dart` (extended)
- `lib/data/repositories/debt_repo.dart` (extended)
- `lib/application/sync/sync_manager.dart` (extended — postSyncHook)
- `lib/presentation/screens/more/settings/notification_settings_screen.dart` (extended)
- `test/application/notifications/` (new)

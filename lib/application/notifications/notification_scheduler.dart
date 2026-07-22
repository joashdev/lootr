import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/recurring/subscription_template_classifier.dart';
import '../../data/database/app_database.dart';
import 'local_notifications_client.dart';
import 'notification_deep_link.dart';

int stableNotificationIntId(String value) {
  const offsetBasis = 0x811C9DC5;
  const fnvPrime = 0x01000193;

  var hash = offsetBasis;
  for (final byte in utf8.encode(value)) {
    hash ^= byte;
    hash = (hash * fnvPrime) & 0x7fffffff;
  }

  return hash == 0 ? 1 : hash;
}

class ScheduledNotificationRecord {
  const ScheduledNotificationRecord({
    required this.id,
    required this.notificationType,
    required this.relatedEntityId,
    required this.scheduledAt,
    required this.title,
    required this.body,
  });

  final String id;
  final String notificationType;
  final String relatedEntityId;
  final DateTime scheduledAt;
  final String title;
  final String body;
}

class NotificationScheduler {
  NotificationScheduler({
    required AppDatabase db,
    required LocalNotificationsClient client,
    required bool Function(String notificationType) isEnabled,
    required void Function(String path) onDeepLink,
  }) : // Keep public named arguments stable while storing them privately.
       // ignore: prefer_initializing_formals
       _db = db,
       // ignore: prefer_initializing_formals
       _client = client,
       // ignore: prefer_initializing_formals
       _isEnabled = isEnabled,
       // ignore: prefer_initializing_formals
       _onDeepLink = onDeepLink;

  static const maxPendingNotifications = 64;

  final AppDatabase _db;
  final LocalNotificationsClient _client;
  final bool Function(String notificationType) _isEnabled;
  final void Function(String path) _onDeepLink;

  bool _initialized = false;
  bool _iosPermissionRequested = false;
  bool _iosPermissionGranted = true;
  bool _androidPermissionGranted = true;
  Future<void>? _activeRebuild;

  Future<void> initialize() async {
    if (_initialized) return;

    await _client.initialize(_handleNotificationResponse);
    await _client.ensureReminderChannel();
    _androidPermissionGranted = await _client.requestAndroidPermission();

    final launchPayload = await _client.getLaunchPayload();
    await _handlePayload(launchPayload);

    _initialized = true;
  }

  Future<void> rebuildSchedule() async {
    await initializeIfNeeded();
    if (_activeRebuild != null) return _activeRebuild!;

    final completer = Completer<void>();
    _activeRebuild = completer.future;

    try {
      await _rebuildScheduleInternal();
      completer.complete();
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      rethrow;
    } finally {
      _activeRebuild = null;
    }
  }

  Future<void> initializeIfNeeded() async {
    if (_initialized) return;
    await initialize();
  }

  Future<void> _rebuildScheduleInternal() async {
    final now = DateTime.now();
    final pending = await _client.pendingNotifications();
    final pendingIds = pending.toSet();

    await _markDeliveredNotifications(now, pendingIds);
    await _purgeCompletedNotifications(now);

    if (!_androidPermissionGranted) {
      await _cancelAndForgetAllPending();
      return;
    }

    final desiredNotifications = await _buildDesiredNotifications(now);
    final limitedNotifications = desiredNotifications.take(
      maxPendingNotifications,
    );

    final activeRows = await (_db.select(
      _db.notifications,
    )..where((row) => row.isCompleted.equals(false))).get();
    final activeById = {for (final row in activeRows) row.id: row};
    final desiredIds = limitedNotifications.map((item) => item.id).toSet();

    for (final row in activeRows) {
      if (desiredIds.contains(row.id)) continue;
      await _client.cancel(stableNotificationIntId(row.id));
      await (_db.delete(
        _db.notifications,
      )..where((tbl) => tbl.id.equals(row.id))).go();
    }

    if (limitedNotifications.isEmpty) return;

    if (!await _ensureSchedulingPermissions()) {
      await _cancelAndForgetAllPending();
      return;
    }

    await _client.configureLocalTimeZone(await _resolveSchedulingTimeZone());

    for (final notification in limitedNotifications) {
      final existing = activeById[notification.id];
      final intId = stableNotificationIntId(notification.id);
      final needsReschedule =
          existing == null ||
          existing.scheduledAt != notification.scheduledAt ||
          existing.notificationType != notification.notificationType ||
          existing.relatedEntityId != notification.relatedEntityId ||
          !pendingIds.contains(intId);

      await _db
          .into(_db.notifications)
          .insertOnConflictUpdate(
            NotificationsCompanion(
              id: Value(notification.id),
              notificationType: Value(notification.notificationType),
              relatedEntityId: Value(notification.relatedEntityId),
              scheduledAt: Value(notification.scheduledAt),
              isCompleted: const Value(false),
              createdAt: Value(existing?.createdAt ?? now),
            ),
          );

      if (!needsReschedule) continue;

      await _client.cancel(intId);
      await _client.schedule(
        id: intId,
        scheduledAt: notification.scheduledAt,
        title: notification.title,
        body: notification.body,
        payload: NotificationDeepLinkPayload(
          notificationId: notification.id,
          path: notificationDeepLinkFor(
            notificationType: notification.notificationType,
            relatedEntityId: notification.relatedEntityId,
          ),
        ).encode(),
      );
    }
  }

  Future<void> _cancelAndForgetAllPending() async {
    final rows = await (_db.select(
      _db.notifications,
    )..where((row) => row.isCompleted.equals(false))).get();
    for (final row in rows) {
      await _client.cancel(stableNotificationIntId(row.id));
    }
    await (_db.delete(
      _db.notifications,
    )..where((row) => row.isCompleted.equals(false))).go();
  }

  Future<void> _markDeliveredNotifications(
    DateTime now,
    Set<int> pendingIds,
  ) async {
    final deliveredRows =
        await (_db.select(_db.notifications)..where(
              (row) =>
                  row.isCompleted.equals(false) &
                  row.scheduledAt.isSmallerOrEqualValue(now),
            ))
            .get();

    for (final row in deliveredRows) {
      if (pendingIds.contains(stableNotificationIntId(row.id))) continue;
      await (_db.update(_db.notifications)
            ..where((tbl) => tbl.id.equals(row.id)))
          .write(const NotificationsCompanion(isCompleted: Value(true)));
    }
  }

  Future<void> _purgeCompletedNotifications(DateTime now) async {
    final cutoff = now.subtract(const Duration(days: 7));
    await (_db.delete(_db.notifications)..where(
          (row) =>
              row.isCompleted.equals(true) &
              row.scheduledAt.isSmallerThanValue(cutoff),
        ))
        .go();
  }

  Future<bool> _ensureSchedulingPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (_iosPermissionRequested) return _iosPermissionGranted;
      _iosPermissionRequested = true;
      _iosPermissionGranted = await _client.requestIosPermissions();
      return _iosPermissionGranted;
    }

    return true;
  }

  Future<List<ScheduledNotificationRecord>> _buildDesiredNotifications(
    DateTime now,
  ) async {
    final accountMap = await _accountNames();
    final payeeMap = await _payeeNames();
    final categoryMap = await _categoryNames();
    final subscriptionTemplateIds = await _subscriptionTemplateIds(
      payeeMap: payeeMap,
      categoryMap: categoryMap,
    );

    final results = <ScheduledNotificationRecord>[
      ...await _buildRecurringNotifications(
        payeeMap: payeeMap,
        accountMap: accountMap,
        subscriptionTemplateIds: subscriptionTemplateIds,
        now: now,
      ),
      ...await _buildDebtNotifications(now: now),
      ...await _buildInstallmentNotifications(now: now),
    ];

    results.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return results;
  }

  Future<List<ScheduledNotificationRecord>> _buildRecurringNotifications({
    required Map<String, String> payeeMap,
    required Map<String, String> accountMap,
    required Set<String> subscriptionTemplateIds,
    required DateTime now,
  }) async {
    final templates =
        await (_db.select(_db.recurringTemplates)..where(
              (row) =>
                  row.deletedAt.isNull() &
                  row.reminderEnabled.equals(true) &
                  row.nextOccurrenceAt.isNotNull() &
                  row.nextOccurrenceAt.isBiggerOrEqualValue(now),
            ))
            .get();

    final results = <ScheduledNotificationRecord>[];

    for (final template in templates) {
      final notificationType = subscriptionTemplateIds.contains(template.id)
          ? 'subscription_reminder'
          : 'recurring_reminder';
      if (!_isEnabled(notificationType)) continue;

      final payee = payeeMap[template.payeeId] ?? 'Recurring';
      final account = accountMap[template.accountId] ?? 'Account';
      final body = notificationType == 'subscription_reminder'
          ? 'Subscription: $payee ${_formatPeso(template.amount)}'
          : 'Pay $payee ${_formatPeso(template.amount)} — $account';

      results.add(
        ScheduledNotificationRecord(
          id: _notificationRowId(
            notificationType: notificationType,
            relatedEntityId: template.id,
            scheduledAt: template.nextOccurrenceAt!,
          ),
          notificationType: notificationType,
          relatedEntityId: template.id,
          scheduledAt: template.nextOccurrenceAt!,
          title: 'Lootr Reminder',
          body: body,
        ),
      );
    }

    return results;
  }

  Future<List<ScheduledNotificationRecord>> _buildDebtNotifications({
    required DateTime now,
  }) async {
    if (!_isEnabled('debt_reminder')) return const [];

    final debts =
        await (_db.select(_db.debtRecords)..where(
              (row) =>
                  row.deletedAt.isNull() &
                  row.dueDate.isNotNull() &
                  row.remainingBalance.isBiggerThanValue(0) &
                  row.status.equals('settled').not() &
                  row.dueDate.isBiggerOrEqualValue(now),
            ))
            .get();

    return debts
        .map(
          (debt) => ScheduledNotificationRecord(
            id: _notificationRowId(
              notificationType: 'debt_reminder',
              relatedEntityId: debt.id,
              scheduledAt: debt.dueDate!,
            ),
            notificationType: 'debt_reminder',
            relatedEntityId: debt.id,
            scheduledAt: debt.dueDate!,
            title: 'Lootr Reminder',
            body:
                '${debt.counterpartyName}: ${_formatPeso(debt.remainingBalance)} remaining',
          ),
        )
        .toList();
  }

  Future<List<ScheduledNotificationRecord>> _buildInstallmentNotifications({
    required DateTime now,
  }) async {
    final childRows =
        await (_db.select(_db.transactions)..where(
              (row) =>
                  row.deletedAt.isNull() &
                  row.transactionMode.equals('installment') &
                  row.parentTransactionId.isNotNull() &
                  row.occurredAt.isBiggerOrEqualValue(now),
            ))
            .get();

    if (childRows.isEmpty) return const [];

    final parentIds = childRows
        .map((row) => row.parentTransactionId)
        .whereType<String>()
        .toSet();
    final parentRows = await (_db.select(
      _db.transactions,
    )..where((row) => row.id.isIn(parentIds) & row.deletedAt.isNull())).get();
    final parentById = {for (final row in parentRows) row.id: row};

    final results = <ScheduledNotificationRecord>[];

    if (_isEnabled('bill_due')) {
      for (final row in childRows) {
        final note =
            row.note ??
            parentById[row.parentTransactionId]?.note ??
            'Installment';
        results.add(
          ScheduledNotificationRecord(
            id: _notificationRowId(
              notificationType: 'bill_due',
              relatedEntityId: row.id,
              scheduledAt: row.occurredAt,
            ),
            notificationType: 'bill_due',
            relatedEntityId: row.id,
            scheduledAt: row.occurredAt,
            title: 'Lootr Reminder',
            body: 'Bill due: $note ${_formatPeso(row.amount)}',
          ),
        );
      }
    }

    if (_isEnabled('installment_due')) {
      final firstChildByParent = <String, TransactionData>{};
      for (final row in childRows) {
        final parentId = row.parentTransactionId;
        if (parentId == null) continue;
        final current = firstChildByParent[parentId];
        if (current == null || row.occurredAt.isBefore(current.occurredAt)) {
          firstChildByParent[parentId] = row;
        }
      }

      for (final entry in firstChildByParent.entries) {
        final parent = parentById[entry.key];
        final child = entry.value;
        final note = parent?.note ?? child.note ?? 'Installment';
        results.add(
          ScheduledNotificationRecord(
            id: _notificationRowId(
              notificationType: 'installment_due',
              relatedEntityId: entry.key,
              scheduledAt: child.occurredAt,
            ),
            notificationType: 'installment_due',
            relatedEntityId: entry.key,
            scheduledAt: child.occurredAt,
            title: 'Lootr Reminder',
            body: 'Installment due: $note',
          ),
        );
      }
    }

    return results;
  }

  Future<Map<String, String>> _accountNames() async {
    final rows = await (_db.select(
      _db.accounts,
    )..where((row) => row.deletedAt.isNull())).get();
    return {for (final row in rows) row.id: row.name};
  }

  Future<Map<String, String>> _payeeNames() async {
    final rows = await (_db.select(
      _db.payees,
    )..where((row) => row.deletedAt.isNull())).get();
    return {
      for (final row in rows) row.id: row.displayName ?? row.normalizedName,
    };
  }

  Future<Map<String, String>> _categoryNames() async {
    final rows = await (_db.select(
      _db.categories,
    )..where((row) => row.deletedAt.isNull())).get();
    return {for (final row in rows) row.id: row.name};
  }

  Future<Set<String>> _subscriptionTemplateIds({
    required Map<String, String> payeeMap,
    required Map<String, String> categoryMap,
  }) async {
    final rows =
        await (_db.select(_db.transactions)..where(
              (row) =>
                  row.deletedAt.isNull() &
                  row.recurringTemplateId.isNotNull() &
                  row.transactionSubtype.equals('subscription'),
            ))
            .get();

    final ids = rows
        .map((row) => row.recurringTemplateId)
        .whereType<String>()
        .toSet();

    final templates = await (_db.select(
      _db.recurringTemplates,
    )..where((row) => row.deletedAt.isNull())).get();

    for (final template in templates) {
      if (isSubscriptionRecurringTemplate(
        payeeName: template.payeeId == null
            ? null
            : payeeMap[template.payeeId!],
        categoryName: template.categoryId == null
            ? null
            : categoryMap[template.categoryId!],
        hasSubscriptionHistory: ids.contains(template.id),
      )) {
        ids.add(template.id);
      }
    }

    return ids;
  }

  Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    await _handlePayload(response.payload);
  }

  Future<void> _handlePayload(String? rawPayload) async {
    final payload = NotificationDeepLinkPayload.tryParse(rawPayload);
    if (payload == null) return;

    await (_db.update(_db.notifications)
          ..where((row) => row.id.equals(payload.notificationId)))
        .write(const NotificationsCompanion(isCompleted: Value(true)));

    _onDeepLink(payload.path);
  }

  Future<String?> _resolveSchedulingTimeZone() async {
    final user = await (_db.select(_db.users)..limit(1)).getSingleOrNull();
    final timezone = user?.timezone?.trim();
    if (timezone == null || timezone.isEmpty) {
      return null;
    }

    return timezone;
  }

  String _notificationRowId({
    required String notificationType,
    required String relatedEntityId,
    required DateTime scheduledAt,
  }) {
    return '$notificationType:$relatedEntityId:${scheduledAt.toIso8601String()}';
  }

  String _formatPeso(double amount) {
    final whole = amount.truncateToDouble() == amount;
    final formatted = whole
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '₱$formatted';
  }
}

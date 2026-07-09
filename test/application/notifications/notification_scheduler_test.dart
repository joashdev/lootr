import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/application/notifications/local_notifications_client.dart';
import 'package:lootr/application/notifications/notification_deep_link.dart';
import 'package:lootr/application/notifications/notification_scheduler.dart';
import 'package:lootr/data/database/app_database.dart';

class _FakeLocalNotificationsClient implements LocalNotificationsClient {
  final List<_ScheduledCall> scheduled = [];
  final List<int> cancelled = [];
  final List<int> pending = [];

  bool androidPermission = true;
  bool iosPermission = true;
  String? launchPayload;
  String? configuredTimeZoneName;

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    pending.remove(id);
  }

  @override
  Future<void> ensureReminderChannel() async {}

  @override
  Future<String?> getLaunchPayload() async => launchPayload;

  @override
  Future<void> initialize(onDidReceiveNotificationResponse) async {}

  @override
  Future<void> configureLocalTimeZone(String? timeZoneName) async {
    configuredTimeZoneName = timeZoneName;
  }

  @override
  Future<List<int>> pendingNotifications() async => List.of(pending);

  @override
  Future<bool> requestAndroidPermission() async => androidPermission;

  @override
  Future<bool> requestIosPermissions() async => iosPermission;

  @override
  Future<void> schedule({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  }) async {
    scheduled.add(
      _ScheduledCall(
        id: id,
        scheduledAt: scheduledAt,
        title: title,
        body: body,
        payload: payload,
      ),
    );
    pending.remove(id);
    pending.add(id);
  }
}

class _ScheduledCall {
  const _ScheduledCall({
    required this.id,
    required this.scheduledAt,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final DateTime scheduledAt;
  final String title;
  final String body;
  final String payload;
}

void main() {
  late AppDatabase db;
  late _FakeLocalNotificationsClient client;
  late List<String> openedPaths;

  setUp(() async {
    db = AppDatabase.inMemory();
    client = _FakeLocalNotificationsClient();
    openedPaths = [];

    await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
    await db.accounts.insertOne(
      AccountsCompanion.insert(
        id: 'acc-1',
        ownerUserId: 'usr-1',
        name: 'BDO Savings',
        accountType: 'bank',
      ),
    );
    await db.payees.insertOne(
      PayeesCompanion.insert(
        id: 'pay-1',
        normalizedName: 'acme-music',
        displayName: const Value('Acme Music'),
      ),
    );
    await db.categories.insertOne(
      CategoriesCompanion.insert(
        id: 'cat-1',
        name: 'Subscriptions',
        categoryGroup: 'expense',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  NotificationScheduler makeScheduler({
    bool recurringEnabled = true,
    bool billEnabled = true,
    bool installmentEnabled = true,
    bool debtEnabled = true,
    bool subscriptionEnabled = true,
  }) {
    final enabled = {
      'recurring_reminder': recurringEnabled,
      'bill_due': billEnabled,
      'installment_due': installmentEnabled,
      'debt_reminder': debtEnabled,
      'subscription_reminder': subscriptionEnabled,
    };

    return NotificationScheduler(
      db: db,
      client: client,
      isEnabled: (type) => enabled[type] ?? false,
      onDeepLink: openedPaths.add,
    );
  }

  test(
    'schedules recurring and subscription reminders into plugin and table',
    () async {
      final scheduledAt = DateTime.now().add(const Duration(days: 2));

      await db.recurringTemplates.insertOne(
        RecurringTemplatesCompanion.insert(
          id: 'rec-1',
          accountId: 'acc-1',
          categoryId: const Value('cat-1'),
          payeeId: const Value('pay-1'),
          amount: 499.0,
          recurrenceRule: 'monthly',
          nextOccurrenceAt: Value(scheduledAt),
        ),
      );
      await db.transactions.insertOne(
        TransactionsCompanion.insert(
          id: 'txn-1',
          accountId: 'acc-1',
          payeeId: const Value('pay-1'),
          categoryId: const Value('cat-1'),
          recurringTemplateId: const Value('rec-1'),
          amount: 499.0,
          transactionDirection: 'expense',
          transactionMode: 'recurring',
          transactionSubtype: const Value('subscription'),
          occurredAt: DateTime.now(),
        ),
      );

      final scheduler = makeScheduler();
      await scheduler.initialize();
      await scheduler.rebuildSchedule();

      expect(client.scheduled, hasLength(1));
      expect(client.scheduled.single.body, 'Subscription: Acme Music ₱499');

      final rows = await db.select(db.notifications).get();
      expect(rows, hasLength(1));
      expect(rows.single.notificationType, 'subscription_reminder');

      final payload = NotificationDeepLinkPayload.tryParse(
        client.scheduled.single.payload,
      );
      expect(payload?.path, '/recurring?filter=subscription');
    },
  );

  test('schedules reminder-only recurring templates', () async {
    final scheduledAt = DateTime.now().add(const Duration(days: 1));

    await db.recurringTemplates.insertOne(
      RecurringTemplatesCompanion.insert(
        id: 'rec-reminder-only',
        accountId: 'acc-1',
        payeeId: const Value('pay-1'),
        amount: 250,
        recurrenceRule: 'monthly',
        autoCreateDisabled: const Value(true),
        reminderEnabled: const Value(true),
        nextOccurrenceAt: Value(scheduledAt),
      ),
    );

    final scheduler = makeScheduler();
    await scheduler.initialize();
    await scheduler.rebuildSchedule();

    expect(client.scheduled, hasLength(1));
    expect(client.scheduled.single.body, 'Pay Acme Music ₱250 — BDO Savings');
    expect(
      client.scheduled.single.id,
      stableNotificationIntId(
        'recurring_reminder:rec-reminder-only:${scheduledAt.toIso8601String()}',
      ),
    );
  });

  test('schedules debt, bill due, and installment due reminders', () async {
    final dueAt = DateTime.now().add(const Duration(days: 3));

    await db.debtRecords.insertOne(
      DebtRecordsCompanion.insert(
        id: 'debt-1',
        ownerUserId: 'usr-1',
        counterpartyName: 'Pat',
        debtDirection: 'borrowed',
        amount: 2500,
        remainingBalance: 1250,
        dueDate: Value(dueAt),
        status: 'active',
      ),
    );

    await db.transactions.insertOne(
      TransactionsCompanion.insert(
        id: 'parent-1',
        accountId: 'acc-1',
        amount: 6000,
        transactionDirection: 'expense',
        transactionMode: 'installment',
        note: const Value('Laptop BNPL'),
        occurredAt: DateTime.now(),
      ),
    );
    await db.transactions.insertOne(
      TransactionsCompanion.insert(
        id: 'child-1',
        accountId: 'acc-1',
        parentTransactionId: const Value('parent-1'),
        amount: 1500,
        transactionDirection: 'expense',
        transactionMode: 'installment',
        note: const Value('Month 1 of 4'),
        occurredAt: dueAt,
      ),
    );

    final scheduler = makeScheduler();
    await scheduler.initialize();
    await scheduler.rebuildSchedule();

    final bodies = client.scheduled.map((item) => item.body).toList();
    expect(bodies, contains('Pat: ₱1250 remaining'));
    expect(bodies, contains('Bill due: Month 1 of 4 ₱1500'));
    expect(bodies, contains('Installment due: Laptop BNPL'));
  });

  test(
    'marks delivered notifications completed and removes deleted sources',
    () async {
      final dueAt = DateTime.now().subtract(const Duration(hours: 1));

      await db.recurringTemplates.insertOne(
        RecurringTemplatesCompanion.insert(
          id: 'rec-delivered',
          accountId: 'acc-1',
          amount: 100,
          recurrenceRule: 'monthly',
          nextOccurrenceAt: Value(dueAt),
        ),
      );

      await db.notifications.insertOne(
        NotificationData(
          id: 'recurring_reminder:rec-delivered:${dueAt.toIso8601String()}',
          notificationType: 'recurring_reminder',
          relatedEntityId: 'rec-delivered',
          scheduledAt: dueAt,
          isCompleted: false,
          createdAt: dueAt,
        ),
      );

      final scheduler = makeScheduler();
      await scheduler.initialize();
      await scheduler.rebuildSchedule();

      final deliveredRow = await (db.select(
        db.notifications,
      )..limit(1)).getSingle();
      expect(deliveredRow.isCompleted, isTrue);

      await db.recurringTemplates.insertOne(
        RecurringTemplatesCompanion.insert(
          id: 'rec-delete',
          accountId: 'acc-1',
          amount: 150,
          recurrenceRule: 'monthly',
          nextOccurrenceAt: Value(DateTime.now().add(const Duration(days: 1))),
        ),
      );
      await scheduler.rebuildSchedule();
      client.scheduled.clear();

      await (db.update(
        db.recurringTemplates,
      )..where((row) => row.id.equals('rec-delete'))).write(
        RecurringTemplatesCompanion(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await scheduler.rebuildSchedule();

      final activeRows = await (_dbPending(db)).get();
      expect(
        activeRows.where((row) => row.relatedEntityId == 'rec-delete'),
        isEmpty,
      );
      expect(client.cancelled, isNotEmpty);
    },
  );

  test(
    'rebuild reschedules active notifications missing from the OS queue',
    () async {
      final scheduledAt = DateTime.now().add(const Duration(days: 2));
      final notificationId =
          'recurring_reminder:rec-reboot:${scheduledAt.toIso8601String()}';

      await db.recurringTemplates.insertOne(
        RecurringTemplatesCompanion.insert(
          id: 'rec-reboot',
          accountId: 'acc-1',
          payeeId: const Value('pay-1'),
          amount: 180,
          recurrenceRule: 'monthly',
          nextOccurrenceAt: Value(scheduledAt),
        ),
      );
      await db.notifications.insertOne(
        NotificationData(
          id: notificationId,
          notificationType: 'recurring_reminder',
          relatedEntityId: 'rec-reboot',
          scheduledAt: scheduledAt,
          isCompleted: false,
          createdAt: DateTime.now(),
        ),
      );

      final scheduler = makeScheduler();
      await scheduler.initialize();
      await scheduler.rebuildSchedule();

      expect(client.scheduled, hasLength(1));
      expect(
        client.scheduled.single.id,
        stableNotificationIntId(notificationId),
      );
    },
  );

  test('keeps only the earliest 64 pending notifications', () async {
    final now = DateTime.now();

    for (var i = 0; i < 70; i++) {
      await db.recurringTemplates.insertOne(
        RecurringTemplatesCompanion.insert(
          id: 'rec-$i',
          accountId: 'acc-1',
          amount: 10 + i.toDouble(),
          recurrenceRule: 'daily',
          nextOccurrenceAt: Value(now.add(Duration(hours: i + 1))),
        ),
      );
    }

    final scheduler = makeScheduler();
    await scheduler.initialize();
    await scheduler.rebuildSchedule();

    final rows = await (_dbPending(db)).get();
    expect(client.scheduled, hasLength(64));
    expect(rows, hasLength(64));
  });

  test('uses the stored user timezone when scheduling notifications', () async {
    final scheduledAt = DateTime.now().add(const Duration(days: 1));

    await (db.update(db.users)..where((row) => row.id.equals('usr-1'))).write(
      const UsersCompanion(timezone: Value('America/New_York')),
    );
    await db.recurringTemplates.insertOne(
      RecurringTemplatesCompanion.insert(
        id: 'rec-timezone',
        accountId: 'acc-1',
        amount: 125,
        recurrenceRule: 'monthly',
        nextOccurrenceAt: Value(scheduledAt),
      ),
    );

    final scheduler = makeScheduler();
    await scheduler.initialize();
    await scheduler.rebuildSchedule();

    expect(client.configuredTimeZoneName, 'America/New_York');
  });
}

Selectable<NotificationData> _dbPending(AppDatabase db) {
  return db.select(db.notifications)
    ..where((row) => row.isCompleted.equals(false));
}

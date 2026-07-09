import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

abstract class LocalNotificationsClient {
  Future<void> initialize(
    DidReceiveNotificationResponseCallback onDidReceiveNotificationResponse,
  );

  Future<void> configureLocalTimeZone(String? timeZoneName);
  Future<String?> getLaunchPayload();
  Future<bool> requestAndroidPermission();
  Future<bool> requestIosPermissions();
  Future<void> ensureReminderChannel();
  Future<void> schedule({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  });
  Future<void> cancel(int id);
  Future<List<int>> pendingNotifications();
}

class FlutterLocalNotificationsClient implements LocalNotificationsClient {
  static const reminderChannelId = 'lootr_reminders';
  static const reminderChannelName = 'Lootr Reminders';
  static const reminderChannelDescription =
      'Recurring, debt, bill, and installment reminders.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _timeZonesInitialized = false;
  String? _configuredLocationName;

  FlutterLocalNotificationsClient([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize(
    DidReceiveNotificationResponseCallback onDidReceiveNotificationResponse,
  ) async {
    if (_initialized) return;

    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          defaultPresentAlert: true,
          defaultPresentBadge: true,
          defaultPresentSound: true,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          defaultPresentAlert: true,
          defaultPresentBadge: true,
          defaultPresentSound: true,
        ),
        linux: LinuxInitializationSettings(defaultActionName: 'Open'),
      );

      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      );
      _initialized = true;
    } catch (_) {
      _initialized = true;
    }
  }

  @override
  Future<void> configureLocalTimeZone(String? timeZoneName) async {
    _ensureTimeZonesInitialized();

    final location = _resolveLocation(timeZoneName);
    if (_configuredLocationName == location.name) {
      return;
    }

    tz.setLocalLocation(location);
    _configuredLocationName = location.name;
  }

  @override
  Future<String?> getLaunchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return details?.notificationResponse?.payload;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> requestAndroidPermission() async {
    try {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> requestIosPermissions() async {
    try {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> ensureReminderChannel() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              reminderChannelId,
              reminderChannelName,
              description: reminderChannelDescription,
              importance: Importance.defaultImportance,
            ),
          );
    } catch (_) {}
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (_configuredLocationName == null) {
      await configureLocalTimeZone(null);
    }
    final scheduledDate = tz.TZDateTime.from(scheduledAt, tz.local);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        reminderChannelId,
        reminderChannelName,
        channelDescription: reminderChannelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
        payload: payload,
      );
    } catch (_) {}
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  @override
  Future<List<int>> pendingNotifications() async {
    try {
      final requests = await _plugin.pendingNotificationRequests();
      return requests.map((request) => request.id).toList();
    } catch (_) {
      return const [];
    }
  }

  void _ensureTimeZonesInitialized() {
    if (_timeZonesInitialized) {
      return;
    }

    tz_data.initializeTimeZones();
    _timeZonesInitialized = true;
  }

  tz.Location _resolveLocation(String? timeZoneName) {
    for (final candidate in <String?>[
      _normalizeTimeZoneName(timeZoneName),
      _normalizeTimeZoneName(DateTime.now().timeZoneName),
      'UTC',
    ]) {
      if (candidate == null) {
        continue;
      }

      try {
        return tz.getLocation(candidate);
      } catch (_) {}
    }

    return tz.UTC;
  }

  String? _normalizeTimeZoneName(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}

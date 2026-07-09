import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lootr/application/notifications/local_notifications_client.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/notification_provider.dart';
import 'package:lootr/application/providers/onboarding_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/presentation/screens/more/settings/notification_settings_screen.dart';

class _NoopLocalNotificationsClient implements LocalNotificationsClient {
  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> configureLocalTimeZone(String? timeZoneName) async {}

  @override
  Future<void> ensureReminderChannel() async {}

  @override
  Future<String?> getLaunchPayload() async => null;

  @override
  Future<void> initialize(onDidReceiveNotificationResponse) async {}

  @override
  Future<List<int>> pendingNotifications() async => const [];

  @override
  Future<bool> requestAndroidPermission() async => true;

  @override
  Future<bool> requestIosPermissions() async => true;

  @override
  Future<void> schedule({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  }) async {}
}

void main() {
  testWidgets('toggling a setting persists to SharedPreferences', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.inMemory();
    addTearDown(() => db.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith((ref) => db),
          localNotificationsClientProvider.overrideWithValue(
            _NoopLocalNotificationsClient(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const NotificationSettingsScreen(),
        ),
      ),
    );

    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();

    expect(prefs.getBool('notifications.bill_due'), isFalse);
  });
}

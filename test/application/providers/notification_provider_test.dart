import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lootr/application/providers/notification_provider.dart';
import 'package:lootr/application/providers/onboarding_provider.dart';

void main() {
  test(
    'notification settings fall back to defaults without SharedPreferences',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(notificationSettingsProvider),
        isA<NotificationSettingsState>(),
      );
      expect(container.read(notificationSettingsProvider).billDue, isTrue);

      await container
          .read(notificationSettingsProvider.notifier)
          .setEnabled('bill_due', false);

      expect(container.read(notificationSettingsProvider).billDue, isFalse);
    },
  );

  test(
    'notification settings default to all enabled except subscriptions',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final settings = container.read(notificationSettingsProvider);
      expect(settings.recurringReminder, isTrue);
      expect(settings.billDue, isTrue);
      expect(settings.installmentDue, isTrue);
      expect(settings.debtReminder, isTrue);
      expect(settings.subscriptionReminder, isFalse);
    },
  );

  test('notification settings persist toggles', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container
        .read(notificationSettingsProvider.notifier)
        .setEnabled('bill_due', false);
    await container
        .read(notificationSettingsProvider.notifier)
        .setEnabled('subscription_reminder', true);

    expect(container.read(notificationSettingsProvider).billDue, isFalse);
    expect(
      container.read(notificationSettingsProvider).subscriptionReminder,
      isTrue,
    );
    expect(prefs.getBool('notifications.bill_due'), isFalse);
    expect(prefs.getBool('notifications.subscription_reminder'), isTrue);
  });
}

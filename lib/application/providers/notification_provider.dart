import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../notifications/local_notifications_client.dart';
import '../notifications/notification_scheduler.dart';
import 'database_provider.dart';
import 'onboarding_provider.dart';

class NotificationSettingsState {
  const NotificationSettingsState({
    required this.recurringReminder,
    required this.billDue,
    required this.installmentDue,
    required this.debtReminder,
    required this.subscriptionReminder,
  });

  static const defaults = NotificationSettingsState(
    recurringReminder: true,
    billDue: true,
    installmentDue: true,
    debtReminder: true,
    subscriptionReminder: false,
  );

  factory NotificationSettingsState.fromPrefs(SharedPreferences prefs) {
    return NotificationSettingsState(
      recurringReminder: prefs.getBool(_prefsKey('recurring_reminder')) ?? true,
      billDue: prefs.getBool(_prefsKey('bill_due')) ?? true,
      installmentDue: prefs.getBool(_prefsKey('installment_due')) ?? true,
      debtReminder: prefs.getBool(_prefsKey('debt_reminder')) ?? true,
      subscriptionReminder:
          prefs.getBool(_prefsKey('subscription_reminder')) ?? false,
    );
  }

  final bool recurringReminder;
  final bool billDue;
  final bool installmentDue;
  final bool debtReminder;
  final bool subscriptionReminder;

  bool isEnabled(String notificationType) {
    switch (notificationType) {
      case 'recurring_reminder':
        return recurringReminder;
      case 'bill_due':
        return billDue;
      case 'installment_due':
        return installmentDue;
      case 'debt_reminder':
        return debtReminder;
      case 'subscription_reminder':
        return subscriptionReminder;
      default:
        return false;
    }
  }

  NotificationSettingsState copyWith({
    bool? recurringReminder,
    bool? billDue,
    bool? installmentDue,
    bool? debtReminder,
    bool? subscriptionReminder,
  }) {
    return NotificationSettingsState(
      recurringReminder: recurringReminder ?? this.recurringReminder,
      billDue: billDue ?? this.billDue,
      installmentDue: installmentDue ?? this.installmentDue,
      debtReminder: debtReminder ?? this.debtReminder,
      subscriptionReminder: subscriptionReminder ?? this.subscriptionReminder,
    );
  }
}

String _prefsKey(String notificationType) => 'notifications.$notificationType';

class NotificationSettingsNotifier extends Notifier<NotificationSettingsState> {
  SharedPreferences? _prefsOrNull() {
    try {
      return ref.read(sharedPreferencesProvider);
    } on UnimplementedError {
      return null;
    } catch (error) {
      if (error.toString().contains(
        'sharedPreferencesProvider must be overridden before use',
      )) {
        return null;
      }

      rethrow;
    }
  }

  @override
  NotificationSettingsState build() {
    final prefs = _prefsOrNull();
    if (prefs == null) {
      return NotificationSettingsState.defaults;
    }

    return NotificationSettingsState.fromPrefs(prefs);
  }

  Future<void> setEnabled(String notificationType, bool value) async {
    await _prefsOrNull()?.setBool(_prefsKey(notificationType), value);

    switch (notificationType) {
      case 'recurring_reminder':
        state = state.copyWith(recurringReminder: value);
        break;
      case 'bill_due':
        state = state.copyWith(billDue: value);
        break;
      case 'installment_due':
        state = state.copyWith(installmentDue: value);
        break;
      case 'debt_reminder':
        state = state.copyWith(debtReminder: value);
        break;
      case 'subscription_reminder':
        state = state.copyWith(subscriptionReminder: value);
        break;
      default:
        break;
    }
  }
}

final notificationDeepLinkProvider = StateProvider<String?>((ref) => null);

final localNotificationsClientProvider = Provider<LocalNotificationsClient>(
  (ref) => FlutterLocalNotificationsClient(),
);

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>(
      NotificationSettingsNotifier.new,
    );

final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  final scheduler = NotificationScheduler(
    db: ref.watch(databaseProvider),
    client: ref.watch(localNotificationsClientProvider),
    isEnabled: (notificationType) {
      return ref.read(notificationSettingsProvider).isEnabled(notificationType);
    },
    onDeepLink: (path) {
      ref.read(notificationDeepLinkProvider.notifier).state = path;
    },
  );

  return scheduler;
});

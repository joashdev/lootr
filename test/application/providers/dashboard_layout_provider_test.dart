import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/dashboard_layout_provider.dart';
import 'package:lootr/application/providers/onboarding_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences preferences;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
  });

  test('persists bounded visibility and module order', () async {
    final notifier = container.read(dashboardLayoutProvider.notifier);

    expect(
      container.read(dashboardLayoutProvider).visible,
      DashboardModule.values,
    );

    await notifier.setVisible(DashboardModule.spending, false);
    await notifier.setVisible(DashboardModule.accounts, false);
    final refused = await notifier.setVisible(DashboardModule.budgets, false);
    await notifier.reorderItem(5, 0);

    expect(refused, isFalse);
    expect(
      container.read(dashboardLayoutProvider).visible,
      hasLength(DashboardLayoutNotifier.minimumVisible),
    );
    expect(
      container.read(dashboardLayoutProvider).order.first,
      DashboardModule.activity,
    );

    final restoredContainer = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(restoredContainer.dispose);
    final restored = restoredContainer.read(dashboardLayoutProvider);
    expect(restored.visible, hasLength(4));
    expect(restored.order.first, DashboardModule.activity);
  });

  test('restore defaults makes all six modules visible', () async {
    final notifier = container.read(dashboardLayoutProvider.notifier);
    await notifier.setVisible(DashboardModule.spending, false);
    await notifier.restoreDefaults();

    final state = container.read(dashboardLayoutProvider);
    expect(state.order, DashboardModule.values);
    expect(state.visible, DashboardModule.values);
  });
}

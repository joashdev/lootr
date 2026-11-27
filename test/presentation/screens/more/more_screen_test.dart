import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lootr/application/providers/ai_settings_provider.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/migration_providers.dart';
import 'package:lootr/application/providers/more_tab_provider.dart';
import 'package:lootr/application/providers/onboarding_provider.dart';
import 'package:lootr/core/router/app_router.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/presentation/screens/more/more_screen.dart';

class _CompletedOnboarding extends OnboardingNotifier {
  @override
  OnboardingState build() =>
      const OnboardingState(status: OnboardingStatus.completed);
}

void main() {
  testWidgets('every enabled More tile opens its destination', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((_) => db),
        onboardingProvider.overrideWith(_CompletedOnboarding.new),
        sharedPreferencesProvider.overrideWithValue(prefs),
        migrationRunsProvider.overrideWith((_) => Stream.value([])),
        aiEnabledProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider)..go('/more');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byType(MoreScreen),
      matching: find.byType(Scrollable),
    );
    for (final group in container.read(moreTabProvider)) {
      for (final item in group.items) {
        final tile = find.widgetWithText(ListTile, item.label);
        if (tile.hitTestable().evaluate().isEmpty) {
          await tester.scrollUntilVisible(tile, 180, scrollable: scrollable);
          await tester.pumpAndSettle();
        }
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(
          router.routerDelegate.currentConfiguration.last.matchedLocation,
          item.route,
          reason: item.label,
        );
        router.pop();
        await tester.pumpAndSettle();
      }
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 30));
  });

  testWidgets(
    'stacks financial links and explains disabled Insights at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [aiEnabledProvider.overrideWithValue(false)],
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const MoreScreen(),
          ),
        ),
      );
      final accounts = find.widgetWithText(ListTile, 'Accounts');
      final debts = find.widgetWithText(ListTile, 'Debts & Lending');
      expect(
        tester.getTopLeft(debts).dy,
        greaterThan(tester.getTopLeft(accounts).dy),
      );
      final tile = find.widgetWithText(ListTile, 'Insights');
      await tester.scrollUntilVisible(tile, 150);
      expect(tester.widget<ListTile>(tile).enabled, isFalse);
      expect(find.text('Enable in AI & Data'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

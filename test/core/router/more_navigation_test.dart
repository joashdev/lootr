import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/onboarding_provider.dart';
import 'package:lootr/core/router/app_router.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/presentation/screens/more/more_screen.dart';
import 'package:lootr/presentation/screens/more/settings/about_screen.dart';

class _CompletedOnboarding extends OnboardingNotifier {
  @override
  OnboardingState build() =>
      const OnboardingState(status: OnboardingStatus.completed);
}

void main() {
  testWidgets('More scrolls About clear of the floating nav and safe area', (
    tester,
  ) async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        onboardingProvider.overrideWith(_CompletedOnboarding.new),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    router.go('/more');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(bottom: 36),
              viewPadding: const EdgeInsets.only(bottom: 36),
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final moreList = find.descendant(
      of: find.byType(MoreScreen),
      matching: find.byType(ListView),
    );
    await tester.fling(moreList, const Offset(0, -600), 2200);
    await tester.pumpAndSettle();

    final aboutTile = find.widgetWithText(InkWell, 'About');
    final moreTab = find.widgetWithText(InkWell, 'More');
    expect(
      tester.getBottomLeft(aboutTile).dy,
      lessThan(tester.getTopLeft(moreTab).dy),
    );
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.endsWith('/ic_launcher.png'),
      ),
      findsOneWidget,
    );
  });
}

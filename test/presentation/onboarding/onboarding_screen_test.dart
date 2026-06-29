import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/onboarding_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/user_repo.dart';
import 'package:lootr/data/seed/category_seeds.dart';
import 'package:lootr/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:lootr/presentation/screens/onboarding/widgets/step_indicator.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.inMemory();
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.categories, CategorySeeds.toCompanions());
    });
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp({String location = '/onboarding'}) {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Text('MAIN APP HOME')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) => db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
  }

  Future<void> advanceToLastStep(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('shows first step welcome content with step indicator', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Lootr'), findsOneWidget);
    expect(find.byType(StepIndicator), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('Next advances through all four steps to Get Started', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Lootr'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Track every peso'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Plan your spending'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Set up your profile'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.byKey(const ValueKey('demo-data-toggle')), findsOneWidget);
  });

  testWidgets('Get Started saves profile, seeds demo data, navigates home', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await advanceToLastStep(tester);

    await tester.enterText(find.byType(TextField), 'Alice');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('MAIN APP HOME'), findsOneWidget);

    final user = await db.userRepoCheck();
    expect(user?.displayName, 'Alice');
    expect(user?.currencyCode, 'PHP');

    final accounts = await db.select(db.accounts).get();
    expect(accounts, isNotEmpty);
  });

  testWidgets('demo toggle off skips seeding but still completes', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await advanceToLastStep(tester);

    final toggle = find.byKey(const ValueKey('demo-data-toggle'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Test');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('MAIN APP HOME'), findsOneWidget);
    final accounts = await db.select(db.accounts).get();
    expect(accounts, isEmpty);
  });

  testWidgets('Skip jumps straight to setup with demo data off', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Set up your profile'), findsOneWidget);
    expect(find.byKey(const ValueKey('demo-data-toggle')), findsOneWidget);

    final switchWidget = tester.widget<Switch>(
      find.byKey(const ValueKey('demo-data-toggle')),
    );
    expect(switchWidget.value, isFalse);
  });

  testWidgets('completion persists onboarding completed flag', (tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) => db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(onboardingProvider).completed, isFalse);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Test');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    final container2 = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) => db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container2.dispose);
    expect(container2.read(onboardingProvider).completed, isTrue);
  });

  testWidgets('display name is saved with uppercase first letter', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await advanceToLastStep(tester);

    await tester.enterText(find.byType(TextField), 'alice');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    final user = await db.userRepoCheck();
    expect(user?.displayName, 'Alice');
  });
}

extension on AppDatabase {
  Future<UserData?> userRepoCheck() {
    return UserRepo(this).getCurrentUser();
  }
}

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lootr/app.dart';
import 'package:lootr/application/notifications/local_notifications_client.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/notification_provider.dart';
import 'package:lootr/application/providers/onboarding_provider.dart';
import 'package:lootr/application/providers/theme_provider.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/category_repo.dart';
import 'package:lootr/data/seed/demo_data_loader.dart';

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
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester) async {
    try {
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    } catch (_) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    await binding.takeScreenshot('adopted-v1/$name');
  }

  testWidgets('adopted V1 workflows render from synthetic persisted state', (
    tester,
  ) async {
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }

    SharedPreferences.setMockInitialValues({
      'onboarding_status': 'completed',
      'theme_mode': 'light',
    });
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.inMemory();
    addTearDown(db.close);

    await CategoryRepo(db).seedCategories();
    await db.users.insertOne(
      UsersCompanion.insert(
        id: 'smoke-user',
        email: const Value('smoke@lootr.invalid'),
        displayName: const Value('Alex'),
      ),
    );
    await DemoDataLoader().load(db, userId: 'smoke-user');
    final dueAt = DateTime.now().subtract(const Duration(days: 1));
    await db.recurringOccurrences.insertOne(
      RecurringOccurrencesCompanion.insert(
        id: 'smoke-occurrence-netflix',
        recurringTemplateId: 'demo-rec-netflix',
        status: 'due',
        originalDueAt: dueAt,
        dueAt: dueAt,
        amountAtoms: '54900',
        amountScale: 2,
        currencyCode: 'PHP',
      ),
    );

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWith((ref) => db),
        localNotificationsClientProvider.overrideWithValue(
          _NoopLocalNotificationsClient(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await settle(tester);

    await shot(tester, '01-dashboard-light');

    await tester.tap(find.text('Transactions').last);
    await shot(tester, '02-transactions-period-and-search');

    await tester.tap(find.text('Budgets').last);
    await shot(tester, '03-budgets-period-and-progress');

    await tester.tap(find.text('More').last);
    await shot(tester, '04-more-visible-actions');

    await tester.scrollUntilVisible(
      find.text('Category Rules'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Category Rules'));
    await shot(tester, '05-category-rules');

    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.text('More').last);
    await tester.scrollUntilVisible(
      find.text('Recurring'),
      -220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Recurring'));
    await settle(tester);
    await tester.tap(find.text('Netflix'));
    await shot(tester, '06-recurring-lifecycle');

    // A due occurrence opens the transaction form with its immutable amount
    // prefilled. Cancelling must leave the occurrence actionable.
    await tester.tap(find.text('Pay'));
    await settle(tester);
    expect(find.text('Add Transaction'), findsWidgets);
    final recurringAmount = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller?.text)
        .whereType<String>();
    expect(recurringAmount, contains('549.00'));
    await tester.tap(find.byIcon(Icons.close).last);
    await settle(tester);
    expect(
      (await (db.select(db.recurringOccurrences)
                ..where((row) => row.id.equals('smoke-occurrence-netflix')))
              .getSingle())
          .status,
      'due',
    );

    // Confirm the alternate lifecycle action and assert persisted state, not
    // only the rendered screenshot.
    await tester.tap(find.text('Skip'));
    await settle(tester);
    expect(find.text('Skip this occurrence?'), findsOneWidget);
    await tester.tap(find.text('Skip').last);
    await settle(tester);
    expect(
      (await (db.select(db.recurringOccurrences)
                ..where((row) => row.id.equals('smoke-occurrence-netflix')))
              .getSingle())
          .status,
      'skipped',
    );
    expect(find.text('Skipped'), findsOneWidget);

    await tester.pageBack();
    await settle(tester);
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    final addIsland = find.bySemanticsLabel(
      'Add transaction, transfer, or scan receipt',
    );
    expect(addIsland, findsOneWidget);
    await tester.ensureVisible(addIsland);
    await tester.tap(addIsland);
    await shot(tester, '07-unified-add-quick');

    await tester.tap(find.text('Manual').last);
    await shot(tester, '08-unified-add-manual');

    final activeBefore = (await db.select(db.transactions).get())
        .where((row) => row.deletedAt == null)
        .length;
    final amountField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == '0.00',
    );
    expect(amountField, findsOneWidget);
    await tester.enterText(amountField, '123.45');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    final accountSelector = find.byType(DropdownButton<String>);
    expect(accountSelector, findsOneWidget);
    await tester.ensureVisible(accountSelector);
    await settle(tester);
    await tester.tap(accountSelector);
    await settle(tester);
    await tester.tap(find.text('BDO Savings').last);
    await settle(tester);
    final addTransactionAction = find.text('Add Transaction').last;
    await tester.ensureVisible(addTransactionAction);
    await settle(tester);
    await tester.tap(addTransactionAction);
    await settle(tester);
    expect(find.text('Transaction saved'), findsOneWidget);
    expect(find.text('UNDO'), findsOneWidget);
    expect(
      (await db.select(db.transactions).get())
          .where((row) => row.deletedAt == null)
          .length,
      activeBefore + 1,
    );
    await tester.tap(find.text('UNDO'));
    await settle(tester);
    expect(
      (await db.select(db.transactions).get())
          .where((row) => row.deletedAt == null)
          .length,
      activeBefore,
    );

    await settle(tester);
    await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    expect(prefs.getString('theme_mode'), 'dark');
    await tester.tap(find.text('Home').last);
    await shot(tester, '09-dashboard-dark');

    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.tap(find.text('Transactions').last);
    await shot(tester, '10-transactions-dark-large-text');
  });
}

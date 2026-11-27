import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lootr/application/notifications/notification_scheduler.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/notification_provider.dart';
import 'package:lootr/application/providers/period_context_provider.dart';
import 'package:lootr/application/providers/sync_providers.dart';
import 'package:lootr/application/providers/transaction_list_intent_provider.dart';
import 'package:lootr/application/providers/transaction_filters_provider.dart';
import 'package:lootr/application/sync/sync_manager.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/value_objects/transaction_list_intent.dart';
import 'package:lootr/domain/entities/transaction.dart';
import 'package:lootr/presentation/screens/transactions/transaction_detail_screen.dart';
import 'package:lootr/presentation/shared/components/inputs/search_input.dart';
import 'package:lootr/presentation/screens/transactions/transactions_screen.dart';

class _MockScheduler extends Mock implements NotificationScheduler {}

class _MockSyncManager extends Mock implements SyncManager {}

class _TransactionsHost extends StatelessWidget {
  const _TransactionsHost({required this.routeFilter});

  final ValueNotifier<String?> routeFilter;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: routeFilter,
      builder: (context, filter, _) {
        return TransactionsScreen(initialModeFilter: filter);
      },
    );
  }
}

void main() {
  Future<void> flushStreamCloseTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
  }

  testWidgets(
    'updates the mode filter when the route query changes on a mounted screen',
    (tester) async {
      final db = AppDatabase.inMemory();
      addTearDown(() => db.close());

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);

      final routeFilter = ValueNotifier<String?>('one_time');
      addTearDown(routeFilter.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: _TransactionsHost(routeFilter: routeFilter),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(container.read(transactionFiltersProvider).mode, 'one_time');

      routeFilter.value = 'installment';
      await tester.pump();
      await tester.pump();

      expect(container.read(transactionFiltersProvider).mode, 'installment');
      await flushStreamCloseTimers(tester);
    },
  );

  testWidgets(
    'clears the route-applied mode filter when the deep-link query disappears',
    (tester) async {
      final db = AppDatabase.inMemory();
      addTearDown(() => db.close());

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(container.dispose);

      final routeFilter = ValueNotifier<String?>('installment');
      addTearDown(routeFilter.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: _TransactionsHost(routeFilter: routeFilter),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(container.read(transactionFiltersProvider).mode, 'installment');

      routeFilter.value = null;
      await tester.pump();
      await tester.pump();

      expect(container.read(transactionFiltersProvider).mode, isNull);
      await flushStreamCloseTimers(tester);
    },
  );

  testWidgets('restores a persisted search as a visible populated field', (
    tester,
  ) async {
    final db = AppDatabase.inMemory();
    addTearDown(() => db.close());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) => db)],
    );
    addTearDown(container.dispose);
    container.read(transactionSearchQueryProvider.notifier).setQuery('coffee');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const TransactionsScreen(),
        ),
      ),
    );
    await tester.pump();

    final search = tester.widget<SearchInput>(find.byType(SearchInput));
    expect(search.controller?.text, 'coffee');
    await flushStreamCloseTimers(tester);
  });

  testWidgets('visible Select action enters accessible selection mode', (
    tester,
  ) async {
    final db = AppDatabase.inMemory();
    addTearDown(() => db.close());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) => db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const TransactionsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Select transactions'));
    await tester.pump();

    expect(container.read(transactionListIntentProvider).isSelecting, isTrue);
    expect(find.text('Select transactions'), findsOneWidget);
    expect(find.byTooltip('Recategorize selected'), findsOneWidget);
    expect(find.byTooltip('Move selected to account'), findsOneWidget);
    expect(find.byTooltip('Delete selected'), findsOneWidget);
    await flushStreamCloseTimers(tester);
  });

  testWidgets('oldest-first keeps date groups in ascending order', (
    tester,
  ) async {
    final db = AppDatabase.inMemory();
    addTearDown(() => db.close());
    await db.users.insertOne(
      UsersCompanion.insert(id: 'usr-1', currencyCode: const Value('PHP')),
    );
    await db.accounts.insertOne(
      AccountsCompanion.insert(
        id: 'acc-1',
        ownerUserId: 'usr-1',
        name: 'Cash',
        accountType: 'cash',
      ),
    );
    await db.transactions.insertAll([
      TransactionsCompanion.insert(
        id: 'txn-newer',
        accountId: 'acc-1',
        amount: 20,
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        occurredAt: DateTime(2026, 7, 2, 12),
      ),
      TransactionsCompanion.insert(
        id: 'txn-older',
        accountId: 'acc-1',
        amount: 10,
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        occurredAt: DateTime(2026, 7, 1, 12),
      ),
    ]);

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) => db)],
    );
    addTearDown(container.dispose);
    container
        .read(periodContextProvider.notifier)
        .selectMonth(DateTime(2026, 7));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const TransactionsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Sort transactions'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(
        CheckedPopupMenuItem<TransactionSort>,
        'Oldest first',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      container.read(transactionListIntentProvider).sort,
      TransactionSort.oldestFirst,
    );
    expect(
      tester.getTopLeft(find.text('Jul 1')).dy,
      lessThan(tester.getTopLeft(find.text('Jul 2')).dy),
    );
    await flushStreamCloseTimers(tester);
  });

  group('ledger actions against persisted transactions', () {
    final month = DateTime(2026, 7);
    late AppDatabase db;
    late ProviderContainer container;
    late _MockSyncManager syncManager;

    setUp(() async {
      db = AppDatabase.inMemory();
      addTearDown(db.close);
      await db.users.insertOne(
        UsersCompanion.insert(id: 'user', currencyCode: const Value('PHP')),
      );
      await db.accounts.insertAll([
        AccountsCompanion.insert(
          id: 'cash',
          ownerUserId: 'user',
          name: 'Cash',
          accountType: 'cash',
          currencyCode: const Value('PHP'),
        ),
        AccountsCompanion.insert(
          id: 'bank',
          ownerUserId: 'user',
          name: 'Checking',
          accountType: 'bank',
          currencyCode: const Value('PHP'),
        ),
      ]);
      await db.categories.insertOne(
        CategoriesCompanion.insert(
          id: 'food',
          name: 'Food',
          categoryGroup: 'expense',
        ),
      );
      await db.transactions.insertAll([
        for (final (id, title, direction) in [
          ('coffee', 'Coffee shop', 'expense'),
          ('refund', 'Coffee refund', 'income'),
          ('books', 'Bookshop', 'expense'),
        ])
          TransactionsCompanion.insert(
            id: id,
            title: Value(title),
            accountId: 'cash',
            amount: 10,
            currencyCode: const Value('PHP'),
            transactionDirection: direction,
            transactionMode: 'one_time',
            occurredAt: month,
          ),
      ]);
      final scheduler = _MockScheduler();
      when(scheduler.rebuildSchedule).thenAnswer((_) async {});
      syncManager = _MockSyncManager();
      when(syncManager.sync).thenAnswer((_) async {});
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notificationSchedulerProvider.overrideWithValue(scheduler),
          syncManagerProvider.overrideWithValue(syncManager),
        ],
      );
      addTearDown(container.dispose);
      container.read(periodContextProvider.notifier).selectMonth(month);
    });

    Future<void> openLedger(WidgetTester tester, ThemeData theme) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: theme, home: const TransactionsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('search and filters can be changed independently', (
      tester,
    ) async {
      await openLedger(tester, AppTheme.light);
      final search = find.byType(TextField);
      expect(tester.widget<TextField>(search).decoration?.hintText, 'Search');
      await tester.enterText(search, 'coffee');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Coffee shop'), findsOneWidget);
      expect(find.text('Coffee refund'), findsOneWidget);
      expect(find.text('Bookshop'), findsNothing);

      await tester.tap(find.byTooltip('Filter transactions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Income').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply 1 filter'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller?.text, 'coffee');
      expect(find.text('Coffee shop'), findsNothing);
      expect(find.text('Coffee refund'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove Income filter'));
      await tester.pumpAndSettle();
      expect(find.text('Coffee shop'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Bookshop'), findsOneWidget);

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('No transactions this period'), findsOneWidget);
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('Coffee shop'), findsOneWidget);
      await flushStreamCloseTimers(tester);
    });

    testWidgets(
      'grouped rows still support detail, swipe and pull to refresh',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/transactions',
          routes: [
            GoRoute(
              path: '/transactions',
              builder: (_, _) => const TransactionsScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (_, state) => Scaffold(
                    body: Text('Edit ${(state.extra as Transaction).title}'),
                  ),
                ),
                GoRoute(
                  path: ':id',
                  builder: (_, state) =>
                      TransactionDetailScreen(id: state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DecoratedSliver), findsOneWidget);

        final coffeeRow = find.byKey(const ValueKey('coffee'));
        await tester.tap(coffeeRow);
        await tester.pumpAndSettle();
        expect(find.byType(TransactionDetailScreen), findsOneWidget);
        expect(find.text('Coffee shop'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();

        await tester.drag(coffeeRow, const Offset(400, 0));
        await tester.pumpAndSettle();
        expect(find.text('Edit Coffee shop'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();

        await tester.drag(coffeeRow, const Offset(-400, 0));
        await tester.pumpAndSettle();
        expect(find.text('Delete Transaction'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(coffeeRow, findsOneWidget);

        await tester.drag(coffeeRow, const Offset(-400, 0));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Delete'),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        // The Drift watcher can still have work on the real event loop.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        final deleted = await (db.select(
          db.transactions,
        )..where((row) => row.id.equals('coffee'))).getSingle();
        expect(deleted.deletedAt, isNotNull);
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pumpAndSettle();
        expect(coffeeRow, findsNothing);
        await tester.tap(find.text('UNDO'));
        await tester.pumpAndSettle();
        expect(coffeeRow, findsOneWidget);

        await tester.drag(coffeeRow, const Offset(0, 380));
        await tester.pumpAndSettle();
        verify(syncManager.sync).called(1);
        await tester.pump(const Duration(seconds: 5));
        await flushStreamCloseTimers(tester);
      },
    );

    testWidgets('bulk actions update the ledger and Undo restores deletion', (
      tester,
    ) async {
      Future<TransactionData> coffee() => (db.select(
        db.transactions,
      )..where((row) => row.id.equals('coffee'))).getSingle();

      await openLedger(tester, AppTheme.light);
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coffee shop'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.byTooltip('Recategorize selected'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      expect((await coffee()).categoryId, 'food');

      await tester.longPress(find.text('Coffee shop'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Move selected to account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Checking · PHP'));
      await tester.pumpAndSettle();
      expect((await coffee()).accountId, 'bank');

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Coffee shop'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete selected'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pumpAndSettle();
      expect((await coffee()).deletedAt, isNotNull);
      expect(find.text('Coffee shop'), findsNothing);

      await tester.tap(find.text('UNDO'));
      await tester.pumpAndSettle();
      expect((await coffee()).deletedAt, isNull);
      expect(find.text('Coffee shop'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await flushStreamCloseTimers(tester);
    });

    testWidgets('compact dark ledger keeps actions reachable at 200% text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openLedger(tester, AppTheme.dark);
      expect(
        find.byTooltip('Filter transactions').hitTestable(),
        findsOneWidget,
      );
      expect(find.byTooltip('Sort transactions').hitTestable(), findsOneWidget);
      expect(find.text('Select').hitTestable(), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'no results');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Clear search'));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coffee shop'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Delete selected').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Exit selection mode'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await flushStreamCloseTimers(tester);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull;

import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/period_context_provider.dart';
import 'package:lootr/application/providers/transaction_list_intent_provider.dart';
import 'package:lootr/application/providers/transaction_filters_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/value_objects/transaction_list_intent.dart';
import 'package:lootr/presentation/shared/components/inputs/search_input.dart';
import 'package:lootr/presentation/screens/transactions/transactions_screen.dart';

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
    container
        .read(transactionListIntentProvider.notifier)
        .setSort(TransactionSort.oldestFirst);

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

    expect(
      tester.getTopLeft(find.text('Jul 1')).dy,
      lessThan(tester.getTopLeft(find.text('Jul 2')).dy),
    );
    await flushStreamCloseTimers(tester);
  });
}

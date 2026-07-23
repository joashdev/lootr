import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/transaction_list_intent_provider.dart';
import 'package:lootr/application/providers/transaction_filters_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
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
}

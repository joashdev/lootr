import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/application/providers/budgets_tab_provider.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/presentation/screens/budgets/budget_detail_screen.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.now();

  setUp(() async {
    db = AppDatabase.inMemory();

    await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
    await db.categories.insertOne(
      CategoriesCompanion.insert(
        id: 'cat-food',
        name: 'Food',
        categoryGroup: 'expense',
      ),
    );
    await db.accounts.insertOne(
      AccountsCompanion.insert(
        id: 'acc-1',
        ownerUserId: 'usr-1',
        name: 'Cash',
        accountType: 'cash',
      ),
    );
    await db.budgets.insertOne(
      BudgetsCompanion.insert(
        id: 'bud-food',
        ownerUserId: 'usr-1',
        categoryId: 'cat-food',
        amount: 500,
        month: now.month,
        year: now.year,
      ),
    );
    await db.transactions.insertOne(
      TransactionsCompanion.insert(
        id: 'txn-1',
        accountId: 'acc-1',
        amount: 120,
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        occurredAt: DateTime(now.year, now.month, 1),
        categoryId: const Value('cat-food'),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// Drift schedules a zero-duration timer when its query streams are closed
  /// (provider disposal at the end of the test). Flush it so the test does not
  /// fail with "pending timers".
  Future<void> flushStreamCloseTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // pump with an explicit duration: drift's close notification is a
    // zero-duration Timer, which only fires once fake time elapses.
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    bool listAlive = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWith((ref) => db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: listAlive
              ? Consumer(
                  builder: (context, ref, _) {
                    // Keep the budgets-list stream alive underneath, like
                    // when the detail screen is pushed from the budgets tab.
                    ref.watch(budgetsTabProvider);
                    return const BudgetDetailScreen(id: 'bud-food');
                  },
                )
              : const BudgetDetailScreen(id: 'bud-food'),
        ),
      ),
    );
  }

  Future<void> expectLoadsWithoutHanging(WidgetTester tester) async {
    // First frame may show the loading spinner.
    await tester.pump();

    // Allow streams to emit; bounded pumps instead of pumpAndSettle so a
    // regression fails fast rather than timing out.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (tester.any(find.text('Food'))) break;
    }

    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'Budget detail must not hang on an endless loading spinner',
    );
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  }

  group('BudgetDetailScreen', () {
    testWidgets('loads detail instead of hanging on spinner (regression)', (
      tester,
    ) async {
      await pumpScreen(tester);
      await expectLoadsWithoutHanging(tester);
      await flushStreamCloseTimers(tester);
    });

    testWidgets('loads while budgets list streams are alive (regression)', (
      tester,
    ) async {
      await pumpScreen(tester, listAlive: true);
      await expectLoadsWithoutHanging(tester);
      await flushStreamCloseTimers(tester);
    });

    testWidgets('keeps updating after a new transaction is added', (
      tester,
    ) async {
      await pumpScreen(tester);
      await expectLoadsWithoutHanging(tester);
      expect(find.text('₱120'), findsWidgets);

      // A table change after the first load must flow through; the old
      // provider deadlocked here waiting on an already-listened stream.
      await db.transactions.insertOne(
        TransactionsCompanion.insert(
          id: 'txn-2',
          accountId: 'acc-1',
          amount: 80,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(now.year, now.month, 2),
          categoryId: const Value('cat-food'),
        ),
      );

      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (tester.any(find.text('₱200'))) break;
      }

      expect(
        find.text('₱200'),
        findsWidgets,
        reason: 'Spent total must update when a matching transaction lands',
      );
      await flushStreamCloseTimers(tester);
    });
  });
}

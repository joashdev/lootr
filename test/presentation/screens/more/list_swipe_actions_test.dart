import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/value_objects/field_types.dart';
import 'package:lootr/presentation/screens/more/accounts_screen.dart';
import 'package:lootr/presentation/screens/more/debts_screen.dart';
import 'package:lootr/presentation/screens/more/goals_screen.dart';
import 'package:lootr/presentation/screens/more/recurring_screen.dart';
import 'package:lootr/presentation/shared/components/swipe_action_row.dart';

Widget _wrapWithProviders(AppDatabase db, Widget screen) {
  return ProviderScope(
    overrides: [databaseProvider.overrideWith((ref) => db)],
    child: MaterialApp(theme: AppTheme.light, home: screen),
  );
}

/// Drags [finder] left far enough to trip the Dismissible delete action.
Future<void> _swipeLeft(WidgetTester tester, Finder finder) async {
  await tester.drag(finder, const Offset(-400, 0));
  await tester.pumpAndSettle();
}

/// Drags [finder] right far enough to trip the Dismissible edit action.
Future<void> _swipeRight(WidgetTester tester, Finder finder) async {
  await tester.drag(finder, const Offset(400, 0));
  await tester.pumpAndSettle();
}

/// Lets the confirmation snackbar's timer expire so no timers are pending
/// when the test ends.
Future<void> _expireSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// Disposes the widget tree so the screens' drift stream subscriptions are
/// cancelled, then settles the zero-length timer drift schedules on stream
/// cancellation (`StreamQueryStore.markAsClosed`). Without this the test ends
/// with a pending timer and the binding's invariant check fails.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.inMemory();
    await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
    await db.accounts.insertOne(
      AccountsCompanion.insert(
        id: 'acc-1',
        ownerUserId: 'usr-1',
        name: 'Wallet',
        accountType: AccountType.cash,
        balance: const Value(500),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('AccountsScreen swipe actions', () {
    testWidgets('rows are wrapped in a swipe affordance', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(db, const AccountsScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(SwipeActionRow), findsOneWidget);
      expect(find.text('Wallet'), findsOneWidget);

      await _disposeTree(tester);
    });

    testWidgets('swipe left asks to archive and cancel keeps the account', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapWithProviders(db, const AccountsScreen()));
      await tester.pumpAndSettle();

      await _swipeLeft(tester, find.text('Wallet'));
      expect(find.text('Archive account?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final row = await db.select(db.accounts).getSingle();
      expect(row.isArchived, isFalse);
      expect(find.text('Wallet'), findsOneWidget);

      await _disposeTree(tester);
    });

    testWidgets('confirming archive marks account archived', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(db, const AccountsScreen()));
      await tester.pumpAndSettle();

      await _swipeLeft(tester, find.text('Wallet'));
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();

      final row = await db.select(db.accounts).getSingle();
      expect(row.isArchived, isTrue);
      expect(find.text('Account archived.'), findsOneWidget);
      // watchAll() excludes archived accounts, so the row leaves the list.
      expect(find.text('Wallet'), findsNothing);

      await _expireSnackBar(tester);
      await _disposeTree(tester);
    });

    testWidgets('swipe right opens the edit account sheet', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(db, const AccountsScreen()));
      await tester.pumpAndSettle();

      await _swipeRight(tester, find.text('Wallet'));
      expect(find.text('Edit Account'), findsOneWidget);

      await _disposeTree(tester);
    });
  });

  group('GoalsScreen swipe actions', () {
    setUp(() async {
      await db.goals.insertOne(
        GoalsCompanion.insert(
          id: 'goal-1',
          ownerUserId: 'usr-1',
          name: 'Beach Trip',
          goalType: GoalType.savings,
          targetAmount: 10000,
          currentAmount: const Value(2500),
        ),
      );
    });

    testWidgets('rows are wrapped in a swipe affordance', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(db, const GoalsScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(SwipeActionRow), findsOneWidget);
      expect(find.text('Beach Trip'), findsOneWidget);

      await _disposeTree(tester);
    });

    testWidgets('swipe left asks to delete and cancel keeps the goal', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapWithProviders(db, const GoalsScreen()));
      await tester.pumpAndSettle();

      await _swipeLeft(tester, find.text('Beach Trip'));
      expect(find.text('Delete Goal?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final row = await db.select(db.goals).getSingle();
      expect(row.deletedAt, isNull);
      expect(find.text('Beach Trip'), findsOneWidget);

      await _disposeTree(tester);
    });

    testWidgets('confirming delete removes the goal row', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(db, const GoalsScreen()));
      await tester.pumpAndSettle();

      await _swipeLeft(tester, find.text('Beach Trip'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      final row = await db.select(db.goals).getSingle();
      expect(row.deletedAt, isNotNull);
      expect(find.text('Goal deleted.'), findsOneWidget);
      expect(find.text('Beach Trip'), findsNothing);

      await _expireSnackBar(tester);
      await _disposeTree(tester);
    });

    testWidgets('swipe right opens the edit goal sheet', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(db, const GoalsScreen()));
      await tester.pumpAndSettle();

      await _swipeRight(tester, find.text('Beach Trip'));
      expect(find.text('Edit Goal'), findsOneWidget);

      await _disposeTree(tester);
    });
  });

  group('DebtsScreen swipe actions', () {
    setUp(() async {
      await db.debtRecords.insertOne(
        DebtRecordsCompanion.insert(
          id: 'debt-1',
          ownerUserId: 'usr-1',
          counterpartyName: 'Maria',
          debtDirection: DebtDirection.borrowed,
          amount: 5000,
          remainingBalance: 5000,
          status: DebtStatus.active,
        ),
      );
    });

    testWidgets('rows are wrapped in a swipe affordance', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(db, const DebtsScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(SwipeActionRow), findsOneWidget);
      expect(find.text('Maria'), findsOneWidget);

      await _disposeTree(tester);
    });

    testWidgets('swipe left asks to delete and cancel keeps the debt', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapWithProviders(db, const DebtsScreen()));
      await tester.pumpAndSettle();

      await _swipeLeft(tester, find.text('Maria'));
      expect(find.text('Delete Debt?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final row = await db.select(db.debtRecords).getSingle();
      expect(row.deletedAt, isNull);
      expect(find.text('Maria'), findsOneWidget);

      await _disposeTree(tester);
    });

    testWidgets('confirming delete removes the debt row', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(db, const DebtsScreen()));
      await tester.pumpAndSettle();

      await _swipeLeft(tester, find.text('Maria'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      final row = await db.select(db.debtRecords).getSingle();
      expect(row.deletedAt, isNotNull);
      expect(find.text('Debt deleted.'), findsOneWidget);
      expect(find.text('Maria'), findsNothing);

      await _expireSnackBar(tester);
      await _disposeTree(tester);
    });

    testWidgets('swipe right opens the edit debt sheet', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(db, const DebtsScreen()));
      await tester.pumpAndSettle();

      await _swipeRight(tester, find.text('Maria'));
      expect(find.text('Edit Debt'), findsOneWidget);

      await _disposeTree(tester);
    });
  });

  group('RecurringScreen swipe actions', () {
    setUp(() async {
      await db.recurringTemplates.insertOne(
        RecurringTemplatesCompanion.insert(
          id: 'rec-1',
          accountId: 'acc-1',
          amount: 900.0,
          recurrenceRule: 'monthly',
          nextOccurrenceAt: Value(DateTime.now().add(const Duration(days: 3))),
        ),
      );
    });

    testWidgets('rows are wrapped in a swipe affordance', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(db, const RecurringScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(SwipeActionRow), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);

      await _disposeTree(tester);
    });

    testWidgets('swipe left asks to delete and cancel keeps the item', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapWithProviders(db, const RecurringScreen()));
      await tester.pumpAndSettle();

      await _swipeLeft(tester, find.text('Monthly'));
      expect(find.text('Delete Recurring?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final row = await db.select(db.recurringTemplates).getSingle();
      expect(row.deletedAt, isNull);
      expect(find.text('Monthly'), findsOneWidget);

      await _disposeTree(tester);
    });

    testWidgets('confirming delete removes the recurring row', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(db, const RecurringScreen()));
      await tester.pumpAndSettle();

      await _swipeLeft(tester, find.text('Monthly'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      final row = await db.select(db.recurringTemplates).getSingle();
      expect(row.deletedAt, isNotNull);
      expect(find.text('Recurring item deleted.'), findsOneWidget);
      expect(find.text('Monthly'), findsNothing);

      await _expireSnackBar(tester);
      await _disposeTree(tester);
    });

    testWidgets('swipe right opens the edit recurring sheet', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(db, const RecurringScreen()));
      await tester.pumpAndSettle();

      await _swipeRight(tester, find.text('Monthly'));
      expect(find.text('Edit Recurring Item'), findsOneWidget);

      await _disposeTree(tester);
    });
  });
}

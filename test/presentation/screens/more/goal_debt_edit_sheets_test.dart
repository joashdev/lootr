import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/entities/debt_record.dart';
import 'package:lootr/domain/entities/goal.dart';
import 'package:lootr/domain/value_objects/field_types.dart';
import 'package:lootr/presentation/screens/more/more_form_sheets.dart';

/// Hosts a button that opens one of the more_form_sheets bottom sheets so the
/// sheet gets a real Navigator/WidgetRef, mirroring detail-screen usage.
class _SheetHost extends ConsumerWidget {
  const _SheetHost({required this.onOpen});

  final Future<void> Function(BuildContext context, WidgetRef ref) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ElevatedButton(
        onPressed: () => onOpen(context, ref),
        child: const Text('open-sheet'),
      ),
    );
  }
}

Widget _wrapWithProviders(AppDatabase db, Widget child) {
  return ProviderScope(
    overrides: [databaseProvider.overrideWith((ref) => db)],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('open-sheet'));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save Changes'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save Changes'));
  await tester.pumpAndSettle();
}

/// Lets the confirmation snackbar's timer expire so no timers are pending
/// when the test ends.
Future<void> _expireSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.inMemory();
    await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
  });

  tearDown(() async {
    await db.close();
  });

  group('showGoalSheet edit mode', () {
    final goal = Goal(
      id: 'goal-1',
      ownerUserId: 'usr-1',
      name: 'Beach Trip',
      goalType: GoalType.savings,
      targetAmount: 10000,
      currentAmount: 2500,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

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

    testWidgets('opens prefilled with Edit Goal title', (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          db,
          _SheetHost(
            onOpen: (context, ref) =>
                showGoalSheet(context, ref, initial: goal),
          ),
        ),
      );
      await _openSheet(tester);

      expect(find.text('Edit Goal'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Beach Trip'), findsOneWidget);
      expect(find.text('10000.00'), findsOneWidget);
      expect(find.text('2500.00'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('saving updates the existing goal row', (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          db,
          _SheetHost(
            onOpen: (context, ref) =>
                showGoalSheet(context, ref, initial: goal),
          ),
        ),
      );
      await _openSheet(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Beach Trip'),
        'Rainy Day Fund',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '10000.00'),
        '15000',
      );
      await _save(tester);

      final rows = await db.select(db.goals).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, 'goal-1');
      expect(rows.single.name, 'Rainy Day Fund');
      expect(rows.single.targetAmount, 15000);
      expect(rows.single.currentAmount, 2500);
      expect(find.text('Goal updated.'), findsOneWidget);
      await _expireSnackBar(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  });

  group('showDebtSheet edit mode', () {
    final debt = DebtRecord(
      id: 'debt-1',
      ownerUserId: 'usr-1',
      counterpartyName: 'Maria',
      debtDirection: DebtDirection.borrowed,
      amount: 5000,
      remainingBalance: 2000,
      note: 'Lunch money',
      status: DebtStatus.partiallyPaid,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    setUp(() async {
      await db.debtRecords.insertOne(
        DebtRecordsCompanion.insert(
          id: 'debt-1',
          ownerUserId: 'usr-1',
          counterpartyName: 'Maria',
          debtDirection: DebtDirection.borrowed,
          amount: 5000,
          remainingBalance: 2000,
          note: const Value('Lunch money'),
          status: DebtStatus.partiallyPaid,
        ),
      );
    });

    testWidgets('opens prefilled with Edit Debt title', (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          db,
          _SheetHost(
            onOpen: (context, ref) =>
                showDebtSheet(context, ref, initial: debt),
          ),
        ),
      );
      await _openSheet(tester);

      expect(find.text('Edit Debt'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Maria'), findsOneWidget);
      expect(find.text('5000.00'), findsOneWidget);
      expect(find.text('2000.00'), findsOneWidget);
      expect(find.text('Lunch money'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('saving updates the existing debt row', (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          db,
          _SheetHost(
            onOpen: (context, ref) =>
                showDebtSheet(context, ref, initial: debt),
          ),
        ),
      );
      await _openSheet(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Maria'),
        'Maria Santos',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '2000.00'),
        '0',
      );
      await _save(tester);

      final rows = await db.select(db.debtRecords).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, 'debt-1');
      expect(rows.single.counterpartyName, 'Maria Santos');
      expect(rows.single.amount, 5000);
      expect(rows.single.remainingBalance, 0);
      expect(rows.single.status, DebtStatus.settled);
      expect(find.text('Debt updated.'), findsOneWidget);
      await _expireSnackBar(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  });
}

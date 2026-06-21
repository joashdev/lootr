import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/entities/budget.dart';
import 'package:lootr/presentation/sheets/budget_create_sheet.dart';

Widget _wrapWithProviders(AppDatabase db, Widget child) {
  return ProviderScope(
    overrides: [databaseProvider.overrideWith((ref) => db)],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  late AppDatabase db;

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
    await db.categories.insertOne(
      CategoriesCompanion.insert(
        id: 'cat-fuel',
        name: 'Fuel',
        categoryGroup: 'expense',
      ),
    );
    await db.categories.insertOne(
      CategoriesCompanion.insert(
        id: 'cat-income',
        name: 'Salary',
        categoryGroup: 'income',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('BudgetCreateSheet', () {
    testWidgets('uses category autocomplete filtered from categoriesProvider', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithProviders(db, const BudgetCreateSheet()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('budget-category-input')),
        'Fo',
      );
      await tester.pumpAndSettle();

      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Fuel'), findsNothing);
      expect(find.text('Salary'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('prefills the selected category when editing', (tester) async {
      final budget = Budget(
        id: 'bud-1',
        ownerUserId: 'usr-1',
        categoryId: 'cat-food',
        amount: 1200,
        month: 6,
        year: 2026,
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );

      await tester.pumpWidget(
        _wrapWithProviders(db, BudgetCreateSheet(budget: budget)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Food'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  });
}

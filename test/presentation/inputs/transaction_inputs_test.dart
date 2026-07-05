import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/core/constants/enums.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/domain/entities/account.dart';
import 'package:lootr/domain/entities/category.dart';
import 'package:lootr/domain/entities/payee.dart';
import 'package:lootr/presentation/shared/components/inputs/account_dropdown.dart';
import 'package:lootr/presentation/shared/components/inputs/amount_input.dart';
import 'package:lootr/presentation/shared/components/inputs/category_autocomplete.dart';
import 'package:lootr/presentation/shared/components/inputs/payee_autocomplete.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );

Account _account() => Account(
      id: 'acc-1',
      ownerUserId: 'user-1',
      name: 'Checking',
      accountType: 'bank',
      balance: 1234.5,
      currencyCode: 'PHP',
      isArchived: false,
      isHidden: false,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('AmountInput', () {
    testWidgets('renders label and reports onChanged', (tester) async {
      String? captured;
      await tester.pumpWidget(
        _wrap(
          AmountInput(
            direction: TransactionDirection.expense,
            label: 'Amount',
            onChanged: (value) => captured = value,
          ),
        ),
      );

      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('₱'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '42');
      expect(captured, '42');
    });
  });

  group('AccountDropdown', () {
    testWidgets('shows balance for each account', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AccountDropdown(
            accounts: [_account()],
            selectedAccountId: 'acc-1',
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Checking'), findsOneWidget);
      expect(find.textContaining('1,234.50'), findsOneWidget);
    });
  });

  group('CategoryAutocomplete', () {
    testWidgets('filters by group', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CategoryAutocomplete(
            categories: [
              Category(
                id: 'cat-1',
                name: 'Food',
                categoryGroup: 'expense',
                createdAt: DateTime(2026, 1, 1),
                updatedAt: DateTime(2026, 1, 1),
              ),
            ],
            selectedCategoryId: null,
            groupFilter: 'expense',
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Search category'), findsOneWidget);
    });

    testWidgets('populates field from selectedCategoryId when no initialText',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          CategoryAutocomplete(
            categories: [
              Category(
                id: 'cat-1',
                name: 'Food & Dining',
                categoryGroup: 'expense',
                icon: 'fork-knife',
                color: '#EF4444',
                createdAt: DateTime(2026, 1, 1),
                updatedAt: DateTime(2026, 1, 1),
              ),
            ],
            selectedCategoryId: 'cat-1',
            groupFilter: 'expense',
            onChanged: (_) {},
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, 'Food & Dining');
      // Selected category shows its visual instead of the search icon.
      expect(find.byIcon(Icons.search), findsNothing);
    });

    testWidgets(
        'shows selected category name even when its group is filtered out',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          CategoryAutocomplete(
            categories: [
              Category(
                id: 'cat-income',
                name: 'Salary',
                categoryGroup: 'income',
                createdAt: DateTime(2026, 1, 1),
                updatedAt: DateTime(2026, 1, 1),
              ),
            ],
            selectedCategoryId: 'cat-income',
            groupFilter: 'expense',
            onChanged: (_) {},
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, 'Salary');
    });
  });

  group('PayeeAutocomplete', () {
    testWidgets('reports typed text', (tester) async {
      String? typed;
      await tester.pumpWidget(
        _wrap(
          PayeeAutocomplete(
            payees: [
              Payee(
                id: 'payee-1',
                normalizedName: 'brew lab',
                displayName: 'Brew Lab',
                createdAt: DateTime(2026, 1, 1),
                updatedAt: DateTime(2026, 1, 1),
              ),
            ],
            selectedPayeeId: null,
            onChanged: (_) {},
            onTextChanged: (value) => typed = value,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'New Shop');
      expect(typed, 'New Shop');
    });

    testWidgets('populates field from selectedPayeeId when no initialText',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          PayeeAutocomplete(
            payees: [
              Payee(
                id: 'payee-1',
                normalizedName: 'brew lab',
                displayName: 'Brew Lab',
                createdAt: DateTime(2026, 1, 1),
                updatedAt: DateTime(2026, 1, 1),
              ),
            ],
            selectedPayeeId: 'payee-1',
            onChanged: (_) {},
            onTextChanged: (_) {},
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, 'Brew Lab');
    });
  });
}

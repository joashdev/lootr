import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/accounts_provider.dart';
import 'package:lootr/application/providers/categories_provider.dart';
import 'package:lootr/application/providers/debts_provider.dart';
import 'package:lootr/application/providers/filtered_transactions_provider.dart';
import 'package:lootr/application/providers/payees_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/domain/entities/account.dart';
import 'package:lootr/domain/entities/category.dart';
import 'package:lootr/domain/entities/debt_record.dart';
import 'package:lootr/domain/entities/payee.dart';
import 'package:lootr/domain/entities/transaction.dart';
import 'package:lootr/domain/entities/transfer.dart';
import 'package:lootr/presentation/sheets/add_transaction_sheet.dart';

Widget _wrap(
  Widget child, {
  List<Account> accounts = const [],
  List<Category> categories = const [],
  List<Payee> payees = const [],
}) {
  return ProviderScope(
    overrides: [
      accountsProvider.overrideWith((ref) => Stream.value(accounts)),
      categoriesProvider.overrideWith((ref) => Stream.value(categories)),
      payeesProvider.overrideWith((ref) => Stream.value(payees)),
      debtsProvider.overrideWith((ref) => Stream.value(const <DebtRecord>[])),
      filteredTransactionsProvider.overrideWith(
        (ref) => Stream.value(const <Transaction>[]),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
}

Account _account() => Account(
  id: 'acc-1',
  ownerUserId: 'user-1',
  name: 'Checking',
  accountType: 'bank',
  balance: 1200,
  currencyCode: 'PHP',
  isArchived: false,
  isHidden: false,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Account _secondAccount() => Account(
  id: 'acc-2',
  ownerUserId: 'user-1',
  name: 'Savings',
  accountType: 'savings',
  balance: 800,
  currencyCode: 'PHP',
  isArchived: false,
  isHidden: false,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Category _category() => Category(
  id: 'cat-1',
  name: 'Coffee',
  categoryGroup: 'expense',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Payee _payee() => Payee(
  id: 'payee-1',
  normalizedName: 'brew lab',
  displayName: 'Brew Lab',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Transaction _transaction({String direction = 'expense'}) => Transaction(
  id: 'txn-1',
  accountId: 'acc-1',
  categoryId: 'cat-1',
  payeeId: 'payee-1',
  amount: 99.5,
  direction: direction,
  mode: 'recurring',
  note: 'Morning coffee',
  occurredAt: DateTime(2026, 2, 14, 8, 30),
  createdAt: DateTime(2026, 2, 14, 8, 30),
  updatedAt: DateTime(2026, 2, 14, 8, 30),
);

Transfer _transfer() => Transfer(
  id: 'xfer-1',
  sourceAccountId: 'acc-1',
  destinationAccountId: 'acc-2',
  amount: 250,
  feeAmount: 10,
  note: 'Move savings',
  occurredAt: DateTime(2026, 2, 14, 8, 30),
  createdAt: DateTime(2026, 2, 14, 8, 30),
  updatedAt: DateTime(2026, 2, 14, 8, 30),
);

void main() {
  group('AddTransactionSheet', () {
    testWidgets('renders add mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AddTransactionSheet(),
          accounts: [_account()],
          categories: [_category()],
          payees: [_payee()],
        ),
      );
      await tester.pump();

      expect(find.text('Add Transaction'), findsWidgets);
      expect(find.text('Amount'), findsOneWidget);
    });

    testWidgets('renders prefilled edit mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AddTransactionSheet(initialTransaction: _transaction()),
          accounts: [_account()],
          categories: [_category()],
          payees: [_payee()],
        ),
      );
      await tester.pump();

      expect(find.text('Edit Transaction'), findsOneWidget);
      expect(find.text('Mode: Recurring'), findsOneWidget);
      expect(find.text('Morning coffee'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('renders prefilled transfer edit mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AddTransactionSheet(initialTransfer: _transfer()),
          accounts: [_account(), _secondAccount()],
        ),
      );
      await tester.pump();

      expect(find.text('Edit Transfer'), findsOneWidget);
      expect(find.text('Transfer Amount'), findsOneWidget);
      expect(find.text('Save Transfer'), findsOneWidget);
      expect(find.text('Move savings'), findsOneWidget);
    });
  });
}

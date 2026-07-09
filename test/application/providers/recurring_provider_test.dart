import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/application/providers/categories_provider.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/payees_provider.dart';
import 'package:lootr/application/providers/recurring_provider.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/entities/category.dart';
import 'package:lootr/domain/entities/payee.dart';

void main() {
  test(
    'subscriptionRecurringTemplateIdsProvider uses category and history signals',
    () async {
      final db = AppDatabase.inMemory();
      addTearDown(() => db.close());

      await db.users.insertOne(UsersCompanion.insert(id: 'usr-1'));
      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'acc-1',
          ownerUserId: 'usr-1',
          name: 'BDO',
          accountType: 'bank',
        ),
      );
      await db.payees.insertOne(
        PayeesCompanion.insert(
          id: 'pay-1',
          normalizedName: 'acme-music',
          displayName: const Value('Acme Music'),
        ),
      );
      await db.payees.insertOne(
        PayeesCompanion.insert(
          id: 'pay-2',
          normalizedName: 'water-utility',
          displayName: const Value('Water Utility'),
        ),
      );
      await db.categories.insertOne(
        CategoriesCompanion.insert(
          id: 'cat-sub',
          name: 'Subscriptions',
          categoryGroup: 'expense',
        ),
      );
      await db.categories.insertOne(
        CategoriesCompanion.insert(
          id: 'cat-home',
          name: 'Home',
          categoryGroup: 'expense',
        ),
      );
      await db.recurringTemplates.insertOne(
        RecurringTemplatesCompanion.insert(
          id: 'rec-category',
          accountId: 'acc-1',
          payeeId: const Value('pay-1'),
          categoryId: const Value('cat-sub'),
          amount: 499,
          recurrenceRule: 'monthly',
          nextOccurrenceAt: Value(DateTime(2026, 8, 1, 9)),
        ),
      );
      await db.recurringTemplates.insertOne(
        RecurringTemplatesCompanion.insert(
          id: 'rec-history',
          accountId: 'acc-1',
          payeeId: const Value('pay-2'),
          categoryId: const Value('cat-home'),
          amount: 299,
          recurrenceRule: 'monthly',
          nextOccurrenceAt: Value(DateTime(2026, 8, 2, 9)),
        ),
      );
      await db.recurringTemplates.insertOne(
        RecurringTemplatesCompanion.insert(
          id: 'rec-normal',
          accountId: 'acc-1',
          amount: 1200,
          recurrenceRule: 'monthly',
          nextOccurrenceAt: Value(DateTime(2026, 8, 3, 9)),
        ),
      );
      await db.transactions.insertOne(
        TransactionsCompanion.insert(
          id: 'txn-1',
          accountId: 'acc-1',
          payeeId: const Value('pay-2'),
          categoryId: const Value('cat-home'),
          recurringTemplateId: const Value('rec-history'),
          amount: 299,
          transactionDirection: 'expense',
          transactionMode: 'recurring',
          transactionSubtype: const Value('subscription'),
          occurredAt: DateTime(2026, 7, 1, 9),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) => db),
          payeesProvider.overrideWith(
            (ref) => Stream.value([
              Payee(
                id: 'pay-1',
                normalizedName: 'acme-music',
                displayName: 'Acme Music',
                createdAt: DateTime(2026, 1, 1),
                updatedAt: DateTime(2026, 1, 1),
              ),
              Payee(
                id: 'pay-2',
                normalizedName: 'water-utility',
                displayName: 'Water Utility',
                createdAt: DateTime(2026, 1, 1),
                updatedAt: DateTime(2026, 1, 1),
              ),
            ]),
          ),
          categoriesProvider.overrideWith(
            (ref) => Stream.value([
              Category(
                id: 'cat-sub',
                name: 'Subscriptions',
                categoryGroup: 'expense',
                createdAt: DateTime(2026, 1, 1),
                updatedAt: DateTime(2026, 1, 1),
              ),
              Category(
                id: 'cat-home',
                name: 'Home',
                categoryGroup: 'expense',
                createdAt: DateTime(2026, 1, 1),
                updatedAt: DateTime(2026, 1, 1),
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final completer = Completer<Set<String>>();
      final subscription = container.listen(
        subscriptionRecurringTemplateIdsProvider,
        (previous, next) {
          if (next.hasValue && !completer.isCompleted) {
            completer.complete(next.requireValue);
          }
        },
      );
      addTearDown(subscription.close);

      final ids = await completer.future.timeout(const Duration(seconds: 5));

      expect(ids, contains('rec-category'));
      expect(ids, contains('rec-history'));
      expect(ids, isNot(contains('rec-normal')));
    },
  );
}

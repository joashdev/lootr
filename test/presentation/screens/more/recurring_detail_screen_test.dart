import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lootr/application/notifications/local_notifications_client.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/notification_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/presentation/screens/more/recurring_detail_screen.dart';
import 'package:lootr/presentation/sheets/add_transaction_sheet.dart';

class _NoopNotifications implements LocalNotificationsClient {
  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> configureLocalTimeZone(String? timeZoneName) async {}

  @override
  Future<void> ensureReminderChannel() async {}

  @override
  Future<String?> getLaunchPayload() async => null;

  @override
  Future<void> initialize(onDidReceiveNotificationResponse) async {}

  @override
  Future<List<int>> pendingNotifications() async => const [];

  @override
  Future<bool> requestAndroidPermission() async => true;

  @override
  Future<bool> requestIosPermissions() async => true;

  @override
  Future<void> schedule({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  }) async {}
}

void main() {
  testWidgets(
    'Pay opens prefilled Add without resolving and paid exposes ledger link',
    (tester) async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      await db.users.insertOne(UsersCompanion.insert(id: 'user'));
      await db.accounts.insertOne(
        AccountsCompanion.insert(
          id: 'account',
          ownerUserId: 'user',
          name: 'Wallet',
          accountType: 'cash',
          balanceAtoms: const Value('100000'),
          currencyCode: const Value('USD'),
          currencyPrecision: const Value(2),
        ),
      );
      await db.recurringTemplates.insertOne(
        RecurringTemplatesCompanion.insert(
          id: 'series',
          accountId: 'account',
          amount: 25,
          amountAtoms: const Value('2500'),
          amountScale: const Value(2),
          currencyCode: const Value('USD'),
          transactionDirection: const Value('expense'),
          recurrenceRule: 'monthly',
          nextOccurrenceAt: Value(DateTime(2026, 7, 20)),
        ),
      );
      await db.recurringOccurrences.insertOne(
        RecurringOccurrencesCompanion.insert(
          id: 'occurrence',
          recurringTemplateId: 'series',
          status: 'due',
          originalDueAt: DateTime(2026, 7, 20),
          dueAt: DateTime(2026, 7, 20),
          amountAtoms: '2500',
          amountScale: 2,
          currencyCode: 'USD',
        ),
      );

      final router = GoRouter(
        initialLocation: '/recurring',
        routes: [
          GoRoute(
            path: '/recurring',
            builder: (_, _) => const RecurringDetailScreen(id: 'series'),
          ),
          GoRoute(
            path: '/transactions/new',
            pageBuilder: (_, state) {
              final args = state.extra! as AddTransactionSheetArgs;
              return MaterialPage<void>(
                fullscreenDialog: true,
                child: AddTransactionSheet(
                  recurringPayment: args.recurringPayment,
                ),
              );
            },
          ),
          GoRoute(
            path: '/transactions/:id',
            builder: (_, state) => Scaffold(
              body: Text('Transaction ${state.pathParameters['id']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith((ref) => db),
            localNotificationsClientProvider.overrideWithValue(
              _NoopNotifications(),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pay'));
      await tester.pumpAndSettle();
      expect(find.text('Add Transaction'), findsWidgets);
      expect(find.text('25.00'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(
        (await db.recurringOccurrences.select().getSingle()).status,
        'due',
      );
      expect(await db.transactions.select().get(), isEmpty);

      await db.transactions.insertOne(
        TransactionsCompanion.insert(
          id: 'transaction',
          accountId: 'account',
          recurringTemplateId: const Value('series'),
          amount: 25,
          amountAtoms: const Value('2500'),
          amountScale: const Value(2),
          currencyCode: const Value('USD'),
          transactionDirection: 'expense',
          transactionMode: 'recurring',
          occurredAt: DateTime(2026, 7, 20),
        ),
      );
      await (db.update(
        db.recurringOccurrences,
      )..where((row) => row.id.equals('occurrence'))).write(
        RecurringOccurrencesCompanion(
          status: const Value('paid'),
          transactionId: const Value('transaction'),
          resolvedAt: Value(DateTime(2026, 7, 20, 12)),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (tester.any(find.text('Open transaction'))) break;
      }
      expect(find.text('Open transaction'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 20));
    },
  );
}

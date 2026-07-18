import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/data/backup/transaction_csv_export_service.dart';
import 'package:lootr/data/database/app_database.dart';

void main() {
  late AppDatabase database;
  late Directory temporary;

  setUp(() async {
    database = AppDatabase.inMemory();
    temporary = await Directory.systemTemp.createTemp('lootr-csv-test-');
    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: 'owner',
            email: const Value('owner@example.invalid'),
            displayName: const Value('Owner'),
          ),
        );
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'account',
            ownerUserId: 'owner',
            name: 'Account, quoted',
            accountType: 'bank',
            currencyCode: const Value('TST'),
            currencyPrecision: const Value(12),
          ),
        );
  });

  tearDown(() async {
    await database.close();
    await temporary.delete(recursive: true);
  });

  test(
    'exports exact atoms, currency, and RFC-compatible escaped text',
    () async {
      await database
          .into(database.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: 'transaction',
              accountId: 'account',
              amount: 0.000000000001,
              amountAtoms: const Value('1'),
              amountScale: const Value(12),
              currencyCode: const Value('TST'),
              transactionDirection: 'expense',
              transactionMode: 'one_time',
              note: const Value('line one\n"line two"'),
              occurredAt: DateTime.utc(2026, 7, 18),
            ),
          );

      final destination = File('${temporary.path}/transactions.csv');
      final count = await const TransactionCsvExportService().export(
        database: database,
        destination: destination,
      );
      final text = await destination.readAsString();

      expect(count, 1);
      expect(text, contains('TST,0.000000000001'));
      expect(text, contains('"Account, quoted"'));
      expect(text, contains('"line one\n""line two"""'));
      expect(await File('${destination.path}.creating').exists(), isFalse);
    },
  );
}

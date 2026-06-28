import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/transaction_repo.dart';

import '../test/test_helpers/test_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('transaction flow smoke test', () {
    late AppDatabase db;
    late TransactionRepo repo;

    setUp(() async {
      db = createTestDb();
      repo = TransactionRepo(db);
      await seedDemoDataSubset(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('add transaction, observe list update, undo by soft delete', (
      tester,
    ) async {
      await repo.create(
        TransactionsCompanion.insert(
          id: 'txn-integration-coffee',
          accountId: 'acc-test-wallet',
          categoryId: const Value('cat-test-food'),
          payeeId: const Value('pay-test-grocery'),
          amount: 125,
          transactionDirection: 'expense',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 6, 21, 10),
        ),
      );

      var rows = await repo.watchFiltered(const TransactionRepoFilters()).first;
      expect(rows.map((row) => row.id), contains('txn-integration-coffee'));

      await repo.softDelete('txn-integration-coffee');

      rows = await repo.watchFiltered(const TransactionRepoFilters()).first;
      expect(
        rows.map((row) => row.id),
        isNot(contains('txn-integration-coffee')),
      );
    });
  });
}

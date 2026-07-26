import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/application/providers/transaction_bulk_command_provider.dart';
import 'package:lootr/data/database/app_database.dart';

void main() {
  test(
    'exposes repository preflight through application-owned types',
    () async {
      final database = AppDatabase.inMemory();
      addTearDown(database.close);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) => database)],
      );
      addTearDown(container.dispose);

      final plan = await container
          .read(transactionBulkCommandProvider)
          .preflight(
            const TransactionBulkRequest(
              transactionIds: {},
              operation: TransactionBulkOperation.delete,
            ),
          );

      expect(plan.canApply, isFalse);
      expect(plan.issues.single.message, 'Select at least one item.');
    },
  );
}

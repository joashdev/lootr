import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/transaction_list_intent_provider.dart';
import 'package:lootr/domain/value_objects/transaction_list_intent.dart';

void main() {
  test('selection and sort intent persist until explicitly cleared', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(transactionListIntentProvider.notifier);

    notifier.setSort(TransactionSort.oldestFirst);
    notifier.startSelection('txn-1');
    notifier.toggleSelection('txn-2');

    expect(
      container.read(transactionListIntentProvider).sort,
      TransactionSort.oldestFirst,
    );
    expect(container.read(transactionListIntentProvider).selectedIds, {
      'txn-1',
      'txn-2',
    });

    notifier.clearSelection();
    final cleared = container.read(transactionListIntentProvider);
    expect(cleared.isSelecting, isFalse);
    expect(cleared.selectedIds, isEmpty);
    expect(cleared.sort, TransactionSort.oldestFirst);
  });
}

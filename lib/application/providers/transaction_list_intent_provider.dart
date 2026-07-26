import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/transaction_list_intent.dart';

class TransactionListIntentNotifier extends Notifier<TransactionListIntent> {
  @override
  TransactionListIntent build() => const TransactionListIntent();

  void setSort(TransactionSort sort) {
    state = state.copyWith(sort: sort);
  }

  void startSelection([String? id]) {
    state = state.copyWith(
      isSelecting: true,
      selectedIds: id == null ? const <String>{} : <String>{id},
    );
  }

  void toggleSelection(String id) {
    final next = Set<String>.of(state.selectedIds);
    next.contains(id) ? next.remove(id) : next.add(id);
    state = state.copyWith(selectedIds: next, isSelecting: true);
  }

  void clearSelection() {
    state = state.copyWith(isSelecting: false, selectedIds: const <String>{});
  }
}

final transactionListIntentProvider =
    NotifierProvider<TransactionListIntentNotifier, TransactionListIntent>(
      TransactionListIntentNotifier.new,
    );

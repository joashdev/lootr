enum TransactionSort { newestFirst, oldestFirst }

class TransactionListIntent {
  const TransactionListIntent({
    this.sort = TransactionSort.newestFirst,
    this.selectedIds = const <String>{},
    this.isSelecting = false,
  });

  final TransactionSort sort;
  final Set<String> selectedIds;
  final bool isSelecting;

  TransactionListIntent copyWith({
    TransactionSort? sort,
    Set<String>? selectedIds,
    bool? isSelecting,
  }) {
    return TransactionListIntent(
      sort: sort ?? this.sort,
      selectedIds: Set<String>.unmodifiable(selectedIds ?? this.selectedIds),
      isSelecting: isSelecting ?? this.isSelecting,
    );
  }
}

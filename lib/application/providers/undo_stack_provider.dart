import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/value_objects/undo_entry.dart';

class UndoStackNotifier extends Notifier<List<UndoEntry>> {
  Timer? _expiryTimer;

  @override
  List<UndoEntry> build() {
    ref.onDispose(() {
      _expiryTimer?.cancel();
    });
    return [];
  }

  void push(UndoEntry entry) {
    if (state.isNotEmpty) {
      _popOldest();
    }
    state = [...state, entry];
    _expiryTimer?.cancel();
    _expiryTimer = Timer(const Duration(seconds: 5), () {
      _popById(entry.transactionId);
    });
  }

  Future<void> undo(String transactionId) async {
    final entry = state.cast<UndoEntry?>().firstWhere(
          (e) => e!.transactionId == transactionId,
          orElse: () => null,
        );
    if (entry == null) return;
    await entry.rollback();
    _popById(transactionId);
  }

  void _popById(String id) {
    state = state.where((e) => e.transactionId != id).toList();
  }

  void _popOldest() {
    if (state.isEmpty) return;
    state = state.sublist(1);
  }
}

final undoStackProvider = NotifierProvider<UndoStackNotifier, List<UndoEntry>>(
  UndoStackNotifier.new,
);

final undoEntryProvider = Provider.family<UndoEntry?, String>((ref, id) {
  final stack = ref.watch(undoStackProvider);
  try {
    return stack.firstWhere((e) => e.transactionId == id);
  } catch (_) {
    return null;
  }
});

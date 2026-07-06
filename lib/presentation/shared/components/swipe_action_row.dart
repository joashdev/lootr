import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';

/// Wraps a list row with the same horizontal swipe affordances used on
/// transaction rows (see `transactions_screen.dart`): swipe right
/// (start-to-end) reveals an edit background and triggers [onEdit]; swipe
/// left (end-to-start) reveals a delete background and triggers [onDelete].
///
/// The row is never actually dismissed — `confirmDismiss` always resolves to
/// `false` so callers own removal (e.g. after a confirmed delete the backing
/// list rebuilds without the row). Tap gestures on [child] keep working.
class SwipeActionRow extends StatelessWidget {
  const SwipeActionRow({
    super.key,
    required this.rowKey,
    required this.onEdit,
    required this.onDelete,
    required this.child,
  });

  /// Identity key for the underlying [Dismissible].
  final Key rowKey;

  /// Invoked on swipe right (edit). Row snaps back afterwards.
  final Future<void> Function() onEdit;

  /// Invoked on swipe left (delete). Row snaps back afterwards; the caller
  /// is responsible for confirmation and removing the row from its source.
  final Future<void> Function() onDelete;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: rowKey,
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await onEdit();
          return false;
        }
        await onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: AppColors.primary600,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger600,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: child,
    );
  }
}

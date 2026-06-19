typedef RollbackCallback = Future<void> Function();

class UndoEntry {
  final String transactionId;
  final String message;
  final RollbackCallback rollback;
  final DateTime createdAt;

  const UndoEntry({
    required this.transactionId,
    required this.message,
    required this.rollback,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) =>
      other is UndoEntry &&
      transactionId == other.transactionId &&
      message == other.message &&
      createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(transactionId, message, createdAt);

  @override
  String toString() => 'UndoEntry($transactionId, "$message")';
}

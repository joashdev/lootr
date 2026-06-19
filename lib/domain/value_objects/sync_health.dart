class SyncHealth {
  final DateTime? lastSyncedAt;
  final int pendingCount;
  final int failedCount;
  final String lastStatus;

  const SyncHealth({
    this.lastSyncedAt,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastStatus = 'healthy',
  });

  bool get isHealthy => lastStatus == 'healthy';
  bool get hasPending => pendingCount > 0;
  bool get hasFailed => failedCount > 0;

  @override
  bool operator ==(Object other) =>
      other is SyncHealth &&
      lastSyncedAt == other.lastSyncedAt &&
      pendingCount == other.pendingCount &&
      failedCount == other.failedCount &&
      lastStatus == other.lastStatus;

  @override
  int get hashCode =>
      Object.hash(lastSyncedAt, pendingCount, failedCount, lastStatus);

  @override
  String toString() =>
      'SyncHealth(status: $lastStatus, pending: $pendingCount, failed: $failedCount)';
}

class ConflictApplier {
  bool serverWins(DateTime serverUpdatedAt, DateTime? localUpdatedAt) {
    if (localUpdatedAt == null) return true;
    return !serverUpdatedAt.isBefore(localUpdatedAt);
  }
}

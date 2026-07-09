String _normalizeSubscriptionLabel(String? value) {
  return value?.trim().toLowerCase() ?? '';
}

bool _containsSubscriptionKeyword(String value) {
  return value.contains('subscription') ||
      value.contains('netflix') ||
      value.contains('spotify');
}

bool isSubscriptionRecurringTemplate({
  required String? payeeName,
  required String? categoryName,
  bool hasSubscriptionHistory = false,
}) {
  if (hasSubscriptionHistory) {
    return true;
  }

  final normalizedPayee = _normalizeSubscriptionLabel(payeeName);
  final normalizedCategory = _normalizeSubscriptionLabel(categoryName);

  return _containsSubscriptionKeyword(normalizedPayee) ||
      _containsSubscriptionKeyword(normalizedCategory);
}

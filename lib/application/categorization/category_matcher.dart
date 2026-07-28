import '../../domain/entities/category.dart';
import '../../domain/value_objects/field_types.dart';

/// Resolves parser/categorizer output against the user's persisted categories.
abstract final class CategoryMatcher {
  static Category? resolve({
    required String idOrLabel,
    required List<Category> categories,
    String? direction,
  }) {
    final normalized = _normalize(idOrLabel);
    if (normalized.isEmpty) return null;
    final group = direction == TransactionDirection.income
        ? CategoryGroup.income
        : CategoryGroup.expense;
    final candidates = categories.where(
      (category) =>
          category.deletedAt == null && category.categoryGroup == group,
    );

    for (final category in candidates) {
      if (category.id == idOrLabel || _normalize(category.name) == normalized) {
        return category;
      }
    }
    for (final category in candidates) {
      final name = _normalize(category.name);
      if (name.contains(normalized) || normalized.contains(name)) {
        return category;
      }
    }
    return null;
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

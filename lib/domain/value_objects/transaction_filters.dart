import 'package:flutter/foundation.dart';

import '../entities/transaction.dart';
import 'date_range.dart';

class TransactionFilters {
  final List<String> directions;
  final List<String> modes;
  final List<String> accountIds;
  final List<String> categoryIds;
  final double? minAmount;
  final double? maxAmount;
  final DateRange? dateRange;

  const TransactionFilters({
    this.directions = const [],
    this.modes = const [],
    this.accountIds = const [],
    this.categoryIds = const [],
    this.minAmount,
    this.maxAmount,
    this.dateRange,
  });

  String? get direction => directions.isEmpty ? null : directions.first;
  String? get mode => modes.isEmpty ? null : modes.first;
  String? get accountId => accountIds.isEmpty ? null : accountIds.first;
  String? get categoryId => categoryIds.isEmpty ? null : categoryIds.first;

  bool get isEmpty =>
      directions.isEmpty &&
      modes.isEmpty &&
      accountIds.isEmpty &&
      categoryIds.isEmpty &&
      minAmount == null &&
      maxAmount == null &&
      dateRange == null;

  /// Number of active (non-null) filter groups. Amount min/max counts as one.
  int get activeCount {
    int count = 0;
    count += directions.length;
    count += modes.length;
    count += accountIds.length;
    count += categoryIds.length;
    if (minAmount != null || maxAmount != null) count++;
    if (dateRange != null) count++;
    return count;
  }

  List<Transaction> apply(List<Transaction> transactions) {
    return transactions.where((t) {
      if (directions.isNotEmpty && !directions.contains(t.direction))
        return false;
      if (modes.isNotEmpty && !modes.contains(t.mode)) return false;
      if (accountIds.isNotEmpty && !accountIds.contains(t.accountId))
        return false;
      if (categoryIds.isNotEmpty && !categoryIds.contains(t.categoryId))
        return false;
      if (minAmount != null && t.amount < minAmount!) return false;
      if (maxAmount != null && t.amount > maxAmount!) return false;
      if (dateRange != null && !dateRange!.contains(t.occurredAt)) return false;
      return true;
    }).toList();
  }

  @override
  bool operator ==(Object other) =>
      other is TransactionFilters &&
      listEquals(directions, other.directions) &&
      listEquals(modes, other.modes) &&
      listEquals(accountIds, other.accountIds) &&
      listEquals(categoryIds, other.categoryIds) &&
      minAmount == other.minAmount &&
      maxAmount == other.maxAmount &&
      dateRange == other.dateRange;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(directions),
    Object.hashAll(modes),
    Object.hashAll(accountIds),
    Object.hashAll(categoryIds),
    minAmount,
    maxAmount,
    dateRange,
  );

  @override
  String toString() =>
      'TransactionFilters('
      'directions=$directions, '
      'modes=$modes, '
      'accountIds=$accountIds, '
      'categoryIds=$categoryIds, '
      'minAmount=$minAmount, '
      'maxAmount=$maxAmount, '
      'dateRange=$dateRange'
      ')';
}

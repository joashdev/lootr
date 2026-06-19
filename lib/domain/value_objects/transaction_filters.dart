import '../entities/transaction.dart';
import 'date_range.dart';

class TransactionFilters {
  final String? direction;
  final String? mode;
  final String? accountId;
  final String? categoryId;
  final double? minAmount;
  final double? maxAmount;
  final DateRange? dateRange;

  const TransactionFilters({
    this.direction,
    this.mode,
    this.accountId,
    this.categoryId,
    this.minAmount,
    this.maxAmount,
    this.dateRange,
  });

  bool get isEmpty =>
      direction == null &&
      mode == null &&
      accountId == null &&
      categoryId == null &&
      minAmount == null &&
      maxAmount == null &&
      dateRange == null;

  List<Transaction> apply(List<Transaction> transactions) {
    return transactions.where((t) {
      if (direction != null && t.direction != direction) return false;
      if (mode != null && t.mode != mode) return false;
      if (accountId != null && t.accountId != accountId) return false;
      if (categoryId != null && t.categoryId != categoryId) return false;
      if (minAmount != null && t.amount < minAmount!) return false;
      if (maxAmount != null && t.amount > maxAmount!) return false;
      if (dateRange != null && !dateRange!.contains(t.occurredAt)) return false;
      return true;
    }).toList();
  }

  @override
  bool operator ==(Object other) =>
      other is TransactionFilters &&
      direction == other.direction &&
      mode == other.mode &&
      accountId == other.accountId &&
      categoryId == other.categoryId &&
      minAmount == other.minAmount &&
      maxAmount == other.maxAmount &&
      dateRange == other.dateRange;

  @override
  int get hashCode => Object.hash(
        direction,
        mode,
        accountId,
        categoryId,
        minAmount,
        maxAmount,
        dateRange,
      );

  @override
  String toString() => 'TransactionFilters('
      'direction=$direction, '
      'mode=$mode, '
      'accountId=$accountId, '
      'categoryId=$categoryId, '
      'minAmount=$minAmount, '
      'maxAmount=$maxAmount, '
      'dateRange=$dateRange'
      ')';
}

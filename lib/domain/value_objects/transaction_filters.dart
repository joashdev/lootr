import 'package:flutter/foundation.dart';

import '../entities/transaction.dart';
import 'date_range.dart';
import 'exact_money.dart';

class TransactionFilters {
  final List<String> directions;
  final List<String> modes;
  final List<String> accountIds;
  final List<String> categoryIds;
  final String? currencyCode;
  final double? minAmount;
  final double? maxAmount;
  final String? minAmountCoefficient;
  final int? minAmountScale;
  final String? maxAmountCoefficient;
  final int? maxAmountScale;
  final DateRange? dateRange;

  const TransactionFilters({
    this.directions = const [],
    this.modes = const [],
    this.accountIds = const [],
    this.categoryIds = const [],
    this.currencyCode,
    this.minAmount,
    this.maxAmount,
    this.minAmountCoefficient,
    this.minAmountScale,
    this.maxAmountCoefficient,
    this.maxAmountScale,
    this.dateRange,
  }) : assert(
         (minAmountCoefficient == null) == (minAmountScale == null),
         'minAmountCoefficient and minAmountScale must be set together',
       ),
       assert(
         (maxAmountCoefficient == null) == (maxAmountScale == null),
         'maxAmountCoefficient and maxAmountScale must be set together',
       ),
       assert(
         currencyCode != null ||
             (minAmountCoefficient == null && maxAmountCoefficient == null),
         'Exact amount bounds require an explicit currencyCode',
       );

  String? get direction => directions.isEmpty ? null : directions.first;
  String? get mode => modes.isEmpty ? null : modes.first;
  String? get accountId => accountIds.isEmpty ? null : accountIds.first;
  String? get categoryId => categoryIds.isEmpty ? null : categoryIds.first;

  bool get isEmpty =>
      directions.isEmpty &&
      modes.isEmpty &&
      accountIds.isEmpty &&
      categoryIds.isEmpty &&
      currencyCode == null &&
      minAmount == null &&
      maxAmount == null &&
      minAmountCoefficient == null &&
      maxAmountCoefficient == null &&
      dateRange == null;

  bool get hasExactAmountRange =>
      minAmountCoefficient != null || maxAmountCoefficient != null;

  /// Number of active filter groups. Currency and amount each count as one.
  int get activeCount {
    int count = 0;
    count += directions.length;
    count += modes.length;
    count += accountIds.length;
    count += categoryIds.length;
    if (currencyCode != null) count++;
    if (hasExactAmountRange || minAmount != null || maxAmount != null) count++;
    if (dateRange != null) count++;
    return count;
  }

  List<Transaction> apply(
    List<Transaction> transactions, {
    bool includeMoney = true,
  }) {
    final exactMinimum = minAmountCoefficient == null
        ? null
        : ExactMoney(
            coefficient: BigInt.parse(minAmountCoefficient!),
            scale: minAmountScale!,
            currencyCode: currencyCode!,
          );
    final exactMaximum = maxAmountCoefficient == null
        ? null
        : ExactMoney(
            coefficient: BigInt.parse(maxAmountCoefficient!),
            scale: maxAmountScale!,
            currencyCode: currencyCode!,
          );

    return transactions.where((t) {
      if (directions.isNotEmpty && !directions.contains(t.direction)) {
        return false;
      }
      if (modes.isNotEmpty && !modes.contains(t.mode)) return false;
      if (accountIds.isNotEmpty && !accountIds.contains(t.accountId)) {
        return false;
      }
      if (categoryIds.isNotEmpty && !categoryIds.contains(t.categoryId)) {
        return false;
      }
      if (includeMoney) {
        final amount = t.exactAmount;
        if (currencyCode != null && amount.currencyCode != currencyCode) {
          return false;
        }
        if (hasExactAmountRange) {
          if (exactMinimum != null && amount.compareTo(exactMinimum) < 0) {
            return false;
          }
          if (exactMaximum != null && amount.compareTo(exactMaximum) > 0) {
            return false;
          }
        } else {
          // Legacy unqualified bounds are intentionally ignored: comparing
          // raw numbers across currencies would imply a silent 1:1 rate.
        }
      }
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
      currencyCode == other.currencyCode &&
      minAmount == other.minAmount &&
      maxAmount == other.maxAmount &&
      minAmountCoefficient == other.minAmountCoefficient &&
      minAmountScale == other.minAmountScale &&
      maxAmountCoefficient == other.maxAmountCoefficient &&
      maxAmountScale == other.maxAmountScale &&
      dateRange == other.dateRange;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(directions),
    Object.hashAll(modes),
    Object.hashAll(accountIds),
    Object.hashAll(categoryIds),
    currencyCode,
    minAmount,
    maxAmount,
    minAmountCoefficient,
    minAmountScale,
    maxAmountCoefficient,
    maxAmountScale,
    dateRange,
  );

  @override
  String toString() =>
      'TransactionFilters('
      'directions=$directions, '
      'modes=$modes, '
      'accountIds=$accountIds, '
      'categoryIds=$categoryIds, '
      'currencyCode=$currencyCode, '
      'minAmount=$minAmount, '
      'maxAmount=$maxAmount, '
      'minAmountCoefficient=$minAmountCoefficient, '
      'minAmountScale=$minAmountScale, '
      'maxAmountCoefficient=$maxAmountCoefficient, '
      'maxAmountScale=$maxAmountScale, '
      'dateRange=$dateRange'
      ')';
}

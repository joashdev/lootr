import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import '../value_objects/exact_money.dart';

part 'budget.g.dart';

@JsonSerializable()
class Budget extends Equatable {
  final String id;
  final String? householdId;
  final String ownerUserId;
  final String categoryId;
  final double amount;
  final String? amountAtoms;
  final int? amountScale;
  final String? currencyCode;
  final int month;
  final int year;

  /// Optional visual override; when null the budget inherits its
  /// category's icon/color.
  final String? icon;
  final String? color;

  /// Computed by the repository layer — not stored in the DB.
  /// Populated when fetching budgets (e.g., `BudgetRepo.watchWithSpent`).
  @JsonKey(includeFromJson: false, includeToJson: false)
  final double spent;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final ExactMoney? exactSpent;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Budget({
    required this.id,
    this.householdId,
    required this.ownerUserId,
    required this.categoryId,
    required this.amount,
    this.amountAtoms,
    this.amountScale,
    this.currencyCode,
    required this.month,
    required this.year,
    this.icon,
    this.color,
    this.spent = 0,
    this.exactSpent,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Budget.fromJson(Map<String, dynamic> json) => _$BudgetFromJson(json);

  Map<String, dynamic> toJson() => _$BudgetToJson(this);

  ExactMoney get exactAmount =>
      amountAtoms == null || amountScale == null || currencyCode == null
      ? ExactMoney.parse(
          amount.toStringAsFixed(amountScale ?? 2),
          currencyCode ?? 'PHP',
        )
      : ExactMoney(
          coefficient: BigInt.parse(amountAtoms!),
          scale: amountScale!,
          currencyCode: currencyCode!,
        );

  Budget copyWith({
    String? id,
    String? Function()? householdId,
    String? ownerUserId,
    String? categoryId,
    double? amount,
    String? Function()? amountAtoms,
    int? Function()? amountScale,
    String? Function()? currencyCode,
    int? month,
    int? year,
    String? Function()? icon,
    String? Function()? color,
    double? spent,
    ExactMoney? Function()? exactSpent,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      householdId: householdId != null ? householdId() : this.householdId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      amountAtoms: amountAtoms != null ? amountAtoms() : this.amountAtoms,
      amountScale: amountScale != null ? amountScale() : this.amountScale,
      currencyCode: currencyCode != null ? currencyCode() : this.currencyCode,
      month: month ?? this.month,
      year: year ?? this.year,
      icon: icon != null ? icon() : this.icon,
      color: color != null ? color() : this.color,
      spent: spent ?? this.spent,
      exactSpent: exactSpent != null ? exactSpent() : this.exactSpent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    householdId,
    ownerUserId,
    categoryId,
    amount,
    amountAtoms,
    amountScale,
    currencyCode,
    month,
    year,
    icon,
    color,
    createdAt,
    updatedAt,
    deletedAt,
  ];
}

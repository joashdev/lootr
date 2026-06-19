import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'budget.g.dart';

@JsonSerializable()
class Budget extends Equatable {
  final String id;
  final String? householdId;
  final String ownerUserId;
  final String categoryId;
  final double amount;
  final int month;
  final int year;
  /// Computed by the repository layer — not stored in the DB.
  /// Populated when fetching budgets (e.g., `BudgetRepo.watchWithSpent`).
  final double spent;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Budget({
    required this.id,
    this.householdId,
    required this.ownerUserId,
    required this.categoryId,
    required this.amount,
    required this.month,
    required this.year,
    this.spent = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Budget.fromJson(Map<String, dynamic> json) =>
      _$BudgetFromJson(json);

  Map<String, dynamic> toJson() => _$BudgetToJson(this);

  Budget copyWith({
    String? id,
    String? Function()? householdId,
    String? ownerUserId,
    String? categoryId,
    double? amount,
    int? month,
    int? year,
    double? spent,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      householdId:
          householdId != null ? householdId() : this.householdId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      month: month ?? this.month,
      year: year ?? this.year,
      spent: spent ?? this.spent,
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
        month,
        year,
        spent,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}

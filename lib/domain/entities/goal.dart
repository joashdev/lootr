import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import '../value_objects/exact_money.dart';

part 'goal.g.dart';

@JsonSerializable()
class Goal extends Equatable {
  final String id;
  final String ownerUserId;
  final String? householdId;
  final String name;
  final String goalType;
  final double targetAmount;
  final double currentAmount;
  final String? targetAmountAtoms;
  final String? currentAmountAtoms;
  final int? amountScale;
  final String? currencyCode;
  final DateTime? targetDate;

  /// Computed by the repository layer — not stored in the DB.
  /// Populated when fetching goals (e.g., `GoalRepo.watchWithProgress`).
  @JsonKey(includeFromJson: false, includeToJson: false)
  final double progress;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Goal({
    required this.id,
    required this.ownerUserId,
    this.householdId,
    required this.name,
    required this.goalType,
    required this.targetAmount,
    required this.currentAmount,
    this.targetAmountAtoms,
    this.currentAmountAtoms,
    this.amountScale,
    this.currencyCode,
    this.targetDate,
    this.progress = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Goal.fromJson(Map<String, dynamic> json) => _$GoalFromJson(json);

  Map<String, dynamic> toJson() => _$GoalToJson(this);

  ExactMoney get exactTargetAmount => _exact(targetAmountAtoms, targetAmount);

  ExactMoney get exactCurrentAmount =>
      _exact(currentAmountAtoms, currentAmount);

  Goal copyWith({
    String? id,
    String? ownerUserId,
    String? Function()? householdId,
    String? name,
    String? goalType,
    double? targetAmount,
    double? currentAmount,
    String? Function()? targetAmountAtoms,
    String? Function()? currentAmountAtoms,
    int? Function()? amountScale,
    String? Function()? currencyCode,
    DateTime? Function()? targetDate,
    double? progress,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) {
    return Goal(
      id: id ?? this.id,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      householdId: householdId != null ? householdId() : this.householdId,
      name: name ?? this.name,
      goalType: goalType ?? this.goalType,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetAmountAtoms: targetAmountAtoms != null
          ? targetAmountAtoms()
          : this.targetAmountAtoms,
      currentAmountAtoms: currentAmountAtoms != null
          ? currentAmountAtoms()
          : this.currentAmountAtoms,
      amountScale: amountScale != null ? amountScale() : this.amountScale,
      currencyCode: currencyCode != null ? currencyCode() : this.currencyCode,
      targetDate: targetDate != null ? targetDate() : this.targetDate,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    ownerUserId,
    householdId,
    name,
    goalType,
    targetAmount,
    currentAmount,
    targetAmountAtoms,
    currentAmountAtoms,
    amountScale,
    currencyCode,
    targetDate,
    createdAt,
    updatedAt,
    deletedAt,
  ];

  ExactMoney _exact(String? atoms, double projection) {
    if (atoms != null && amountScale != null && currencyCode != null) {
      return ExactMoney(
        coefficient: BigInt.parse(atoms),
        scale: amountScale!,
        currencyCode: currencyCode!,
      );
    }
    return ExactMoney.parse(
      projection.toStringAsFixed(amountScale ?? 2),
      currencyCode ?? 'PHP',
    );
  }
}

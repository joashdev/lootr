import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

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
  final DateTime? targetDate;
  /// Computed by the repository layer — not stored in the DB.
  /// Populated when fetching goals (e.g., `GoalRepo.watchWithProgress`).
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
    this.targetDate,
    this.progress = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Goal.fromJson(Map<String, dynamic> json) => _$GoalFromJson(json);

  Map<String, dynamic> toJson() => _$GoalToJson(this);

  Goal copyWith({
    String? id,
    String? ownerUserId,
    String? Function()? householdId,
    String? name,
    String? goalType,
    double? targetAmount,
    double? currentAmount,
    DateTime? Function()? targetDate,
    double? progress,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) {
    return Goal(
      id: id ?? this.id,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      householdId:
          householdId != null ? householdId() : this.householdId,
      name: name ?? this.name,
      goalType: goalType ?? this.goalType,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
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
        targetDate,
        progress,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}

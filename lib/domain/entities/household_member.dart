import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'household_member.g.dart';

@JsonSerializable()
class HouseholdMember extends Equatable {
  final String id;
  final String householdId;
  final String userId;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const HouseholdMember({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory HouseholdMember.fromJson(Map<String, dynamic> json) =>
      _$HouseholdMemberFromJson(json);

  Map<String, dynamic> toJson() => _$HouseholdMemberToJson(this);

  HouseholdMember copyWith({
    String? id,
    String? householdId,
    String? userId,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) {
    return HouseholdMember(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        householdId,
        userId,
        role,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}

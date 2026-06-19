import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User extends Equatable {
  final String id;
  final String? email;
  final String? displayName;
  final String currencyCode;
  final String? locale;
  final String? timezone;
  final bool aiEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const User({
    required this.id,
    this.email,
    this.displayName,
    this.currencyCode = 'PHP',
    this.locale,
    this.timezone,
    this.aiEnabled = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? id,
    String? Function()? email,
    String? Function()? displayName,
    String? currencyCode,
    String? Function()? locale,
    String? Function()? timezone,
    bool? aiEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email != null ? email() : this.email,
      displayName:
          displayName != null ? displayName() : this.displayName,
      currencyCode: currencyCode ?? this.currencyCode,
      locale: locale != null ? locale() : this.locale,
      timezone: timezone != null ? timezone() : this.timezone,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        currencyCode,
        locale,
        timezone,
        aiEnabled,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}

import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'payee.g.dart';

@JsonSerializable()
class Payee extends Equatable {
  final String id;
  final String normalizedName;
  final String? displayName;
  final String? logoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Payee({
    required this.id,
    required this.normalizedName,
    this.displayName,
    this.logoUrl,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Payee.fromJson(Map<String, dynamic> json) =>
      _$PayeeFromJson(json);

  Map<String, dynamic> toJson() => _$PayeeToJson(this);

  Payee copyWith({
    String? id,
    String? normalizedName,
    String? Function()? displayName,
    String? Function()? logoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) {
    return Payee(
      id: id ?? this.id,
      normalizedName: normalizedName ?? this.normalizedName,
      displayName:
          displayName != null ? displayName() : this.displayName,
      logoUrl: logoUrl != null ? logoUrl() : this.logoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        normalizedName,
        displayName,
        logoUrl,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}

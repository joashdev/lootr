import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'category.g.dart';

@JsonSerializable()
class Category extends Equatable {
  final String id;
  final String? parentCategoryId;
  final String name;
  final String? icon;
  final String? color;
  final String categoryGroup;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Category({
    required this.id,
    this.parentCategoryId,
    required this.name,
    this.icon,
    this.color,
    required this.categoryGroup,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);

  Map<String, dynamic> toJson() => _$CategoryToJson(this);

  Category copyWith({
    String? id,
    String? Function()? parentCategoryId,
    String? name,
    String? Function()? icon,
    String? Function()? color,
    String? categoryGroup,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) {
    return Category(
      id: id ?? this.id,
      parentCategoryId: parentCategoryId != null
          ? parentCategoryId()
          : this.parentCategoryId,
      name: name ?? this.name,
      icon: icon != null ? icon() : this.icon,
      color: color != null ? color() : this.color,
      categoryGroup: categoryGroup ?? this.categoryGroup,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        parentCategoryId,
        name,
        icon,
        color,
        categoryGroup,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}

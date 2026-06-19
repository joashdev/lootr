import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'transaction.g.dart';

/// Core financial event entity.
///
/// **copyWith null-set convention:** nullable fields accept `String? Function()?`
/// so callers can distinguish "don't change" from "set to null":
/// ```dart
/// tx.copyWith(note: () => null); // sets note to null
/// tx.copyWith(amount: 200);     // updates amount, leaves note unchanged
/// ```
@JsonSerializable()
class Transaction extends Equatable {
  final String id;
  final String accountId;
  final String? categoryId;
  final String? payeeId;
  final String? parentTransactionId;
  final String? recurringTemplateId;
  final double amount;
  final String direction;
  final String mode;
  final String? subtype;
  final String? note;
  final Map<String, dynamic>? metadata;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Transaction({
    required this.id,
    required this.accountId,
    this.categoryId,
    this.payeeId,
    this.parentTransactionId,
    this.recurringTemplateId,
    required this.amount,
    required this.direction,
    required this.mode,
    this.subtype,
    this.note,
    this.metadata,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);

  Map<String, dynamic> toJson() => _$TransactionToJson(this);

  Transaction copyWith({
    String? id,
    String? accountId,
    String? Function()? categoryId,
    String? Function()? payeeId,
    String? Function()? parentTransactionId,
    String? Function()? recurringTemplateId,
    double? amount,
    String? direction,
    String? mode,
    String? Function()? subtype,
    String? Function()? note,
    Map<String, dynamic>? Function()? metadata,
    DateTime? occurredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId != null ? categoryId() : this.categoryId,
      payeeId: payeeId != null ? payeeId() : this.payeeId,
      parentTransactionId: parentTransactionId != null
          ? parentTransactionId()
          : this.parentTransactionId,
      recurringTemplateId: recurringTemplateId != null
          ? recurringTemplateId()
          : this.recurringTemplateId,
      amount: amount ?? this.amount,
      direction: direction ?? this.direction,
      mode: mode ?? this.mode,
      subtype: subtype != null ? subtype() : this.subtype,
      note: note != null ? note() : this.note,
      metadata: metadata != null ? metadata() : this.metadata,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        accountId,
        categoryId,
        payeeId,
        parentTransactionId,
        recurringTemplateId,
        amount,
        direction,
        mode,
        subtype,
        note,
        metadata,
        occurredAt,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}

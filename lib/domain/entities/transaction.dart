import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import '../value_objects/exact_money.dart';

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
  final String? amountAtoms;
  final int? amountScale;
  final String? currencyCode;
  @JsonKey(name: 'transaction_direction')
  final String direction;
  @JsonKey(name: 'transaction_mode')
  final String mode;
  @JsonKey(name: 'transaction_subtype')
  final String? subtype;
  final String? note;
  final Map<String, dynamic>? metadata;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Transaction({
    required this.id,
    required this.accountId,
    this.categoryId,
    this.payeeId,
    this.parentTransactionId,
    this.recurringTemplateId,
    required this.amount,
    this.amountAtoms,
    this.amountScale,
    this.currencyCode,
    required this.direction,
    required this.mode,
    this.subtype,
    this.note,
    Map<String, dynamic>? metadata,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  }) : metadata = metadata == null
           ? null
           : Map<String, dynamic>.unmodifiable(metadata);

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);

  Map<String, dynamic> toJson() => _$TransactionToJson(this);

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

  Transaction copyWith({
    String? id,
    String? accountId,
    String? Function()? categoryId,
    String? Function()? payeeId,
    String? Function()? parentTransactionId,
    String? Function()? recurringTemplateId,
    double? amount,
    String? Function()? amountAtoms,
    int? Function()? amountScale,
    String? Function()? currencyCode,
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
      amountAtoms: amountAtoms != null ? amountAtoms() : this.amountAtoms,
      amountScale: amountScale != null ? amountScale() : this.amountScale,
      currencyCode: currencyCode != null ? currencyCode() : this.currencyCode,
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
    amountAtoms,
    amountScale,
    currencyCode,
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

import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'transfer.g.dart';

@JsonSerializable()
class Transfer extends Equatable {
  final String id;
  final String sourceAccountId;
  final String destinationAccountId;
  final double amount;
  final double feeAmount;
  final String? note;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Transfer({
    required this.id,
    required this.sourceAccountId,
    required this.destinationAccountId,
    required this.amount,
    this.feeAmount = 0,
    this.note,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Transfer.fromJson(Map<String, dynamic> json) =>
      _$TransferFromJson(json);

  Map<String, dynamic> toJson() => _$TransferToJson(this);

  Transfer copyWith({
    String? id,
    String? sourceAccountId,
    String? destinationAccountId,
    double? amount,
    double? feeAmount,
    String? Function()? note,
    DateTime? occurredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) {
    return Transfer(
      id: id ?? this.id,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      destinationAccountId:
          destinationAccountId ?? this.destinationAccountId,
      amount: amount ?? this.amount,
      feeAmount: feeAmount ?? this.feeAmount,
      note: note != null ? note() : this.note,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        sourceAccountId,
        destinationAccountId,
        amount,
        feeAmount,
        note,
        occurredAt,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}

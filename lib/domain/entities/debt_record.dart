import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'debt_record.g.dart';

@JsonSerializable()
class DebtRecord extends Equatable {
  final String id;
  final String ownerUserId;
  final String counterpartyName;
  final String debtDirection;
  final double amount;
  final double remainingBalance;
  final String? note;
  final DateTime? dueDate;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const DebtRecord({
    required this.id,
    required this.ownerUserId,
    required this.counterpartyName,
    required this.debtDirection,
    required this.amount,
    required this.remainingBalance,
    this.note,
    this.dueDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory DebtRecord.fromJson(Map<String, dynamic> json) =>
      _$DebtRecordFromJson(json);

  Map<String, dynamic> toJson() => _$DebtRecordToJson(this);

  DebtRecord copyWith({
    String? id,
    String? ownerUserId,
    String? counterpartyName,
    String? debtDirection,
    double? amount,
    double? remainingBalance,
    String? Function()? note,
    DateTime? Function()? dueDate,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) {
    return DebtRecord(
      id: id ?? this.id,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      debtDirection: debtDirection ?? this.debtDirection,
      amount: amount ?? this.amount,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      note: note != null ? note() : this.note,
      dueDate: dueDate != null ? dueDate() : this.dueDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        ownerUserId,
        counterpartyName,
        debtDirection,
        amount,
        remainingBalance,
        note,
        dueDate,
        status,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}

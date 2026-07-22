import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import '../value_objects/exact_money.dart';

part 'debt_record.g.dart';

@JsonSerializable()
class DebtRecord extends Equatable {
  final String id;
  final String ownerUserId;
  final String counterpartyName;
  final String debtDirection;
  final double amount;
  final double remainingBalance;
  final String? amountAtoms;
  final String? remainingBalanceAtoms;
  final int? amountScale;
  final String? currencyCode;
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
    this.amountAtoms,
    this.remainingBalanceAtoms,
    this.amountScale,
    this.currencyCode,
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

  ExactMoney get exactAmount => _exact(amountAtoms, amount);

  ExactMoney get exactRemainingBalance =>
      _exact(remainingBalanceAtoms, remainingBalance);

  DebtRecord copyWith({
    String? id,
    String? ownerUserId,
    String? counterpartyName,
    String? debtDirection,
    double? amount,
    double? remainingBalance,
    String? Function()? amountAtoms,
    String? Function()? remainingBalanceAtoms,
    int? Function()? amountScale,
    String? Function()? currencyCode,
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
      amountAtoms: amountAtoms != null ? amountAtoms() : this.amountAtoms,
      remainingBalanceAtoms: remainingBalanceAtoms != null
          ? remainingBalanceAtoms()
          : this.remainingBalanceAtoms,
      amountScale: amountScale != null ? amountScale() : this.amountScale,
      currencyCode: currencyCode != null ? currencyCode() : this.currencyCode,
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
    amountAtoms,
    remainingBalanceAtoms,
    amountScale,
    currencyCode,
    note,
    dueDate,
    status,
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

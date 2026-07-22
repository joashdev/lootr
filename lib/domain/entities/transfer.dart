import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import '../value_objects/exact_money.dart';

part 'transfer.g.dart';

@JsonSerializable()
class Transfer extends Equatable {
  final String id;
  final String sourceAccountId;
  final String destinationAccountId;
  final double amount;
  final double feeAmount;
  final String? sourceAmountAtoms;
  final int? sourceAmountScale;
  final String? sourceCurrencyCode;
  final String? destinationAmountAtoms;
  final int? destinationAmountScale;
  final String? destinationCurrencyCode;
  final String? feeAmountAtoms;
  final int? feeAmountScale;
  final String? feeCurrencyCode;
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
    this.sourceAmountAtoms,
    this.sourceAmountScale,
    this.sourceCurrencyCode,
    this.destinationAmountAtoms,
    this.destinationAmountScale,
    this.destinationCurrencyCode,
    this.feeAmountAtoms,
    this.feeAmountScale,
    this.feeCurrencyCode,
    this.note,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Transfer.fromJson(Map<String, dynamic> json) =>
      _$TransferFromJson(json);

  Map<String, dynamic> toJson() => _$TransferToJson(this);

  ExactMoney get exactSourceAmount =>
      _exact(sourceAmountAtoms, sourceAmountScale, sourceCurrencyCode, amount);

  ExactMoney get exactDestinationAmount => _exact(
    destinationAmountAtoms,
    destinationAmountScale,
    destinationCurrencyCode,
    amount,
  );

  ExactMoney get exactFeeAmount =>
      _exact(feeAmountAtoms, feeAmountScale, feeCurrencyCode, feeAmount);

  Transfer copyWith({
    String? id,
    String? sourceAccountId,
    String? destinationAccountId,
    double? amount,
    double? feeAmount,
    String? Function()? sourceAmountAtoms,
    int? Function()? sourceAmountScale,
    String? Function()? sourceCurrencyCode,
    String? Function()? destinationAmountAtoms,
    int? Function()? destinationAmountScale,
    String? Function()? destinationCurrencyCode,
    String? Function()? feeAmountAtoms,
    int? Function()? feeAmountScale,
    String? Function()? feeCurrencyCode,
    String? Function()? note,
    DateTime? occurredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) {
    return Transfer(
      id: id ?? this.id,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      amount: amount ?? this.amount,
      feeAmount: feeAmount ?? this.feeAmount,
      sourceAmountAtoms: sourceAmountAtoms != null
          ? sourceAmountAtoms()
          : this.sourceAmountAtoms,
      sourceAmountScale: sourceAmountScale != null
          ? sourceAmountScale()
          : this.sourceAmountScale,
      sourceCurrencyCode: sourceCurrencyCode != null
          ? sourceCurrencyCode()
          : this.sourceCurrencyCode,
      destinationAmountAtoms: destinationAmountAtoms != null
          ? destinationAmountAtoms()
          : this.destinationAmountAtoms,
      destinationAmountScale: destinationAmountScale != null
          ? destinationAmountScale()
          : this.destinationAmountScale,
      destinationCurrencyCode: destinationCurrencyCode != null
          ? destinationCurrencyCode()
          : this.destinationCurrencyCode,
      feeAmountAtoms: feeAmountAtoms != null
          ? feeAmountAtoms()
          : this.feeAmountAtoms,
      feeAmountScale: feeAmountScale != null
          ? feeAmountScale()
          : this.feeAmountScale,
      feeCurrencyCode: feeCurrencyCode != null
          ? feeCurrencyCode()
          : this.feeCurrencyCode,
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
    sourceAmountAtoms,
    sourceAmountScale,
    sourceCurrencyCode,
    destinationAmountAtoms,
    destinationAmountScale,
    destinationCurrencyCode,
    feeAmountAtoms,
    feeAmountScale,
    feeCurrencyCode,
    note,
    occurredAt,
    createdAt,
    updatedAt,
    deletedAt,
  ];

  ExactMoney _exact(
    String? atoms,
    int? scale,
    String? currencyCode,
    double projection,
  ) {
    if (atoms != null && scale != null && currencyCode != null) {
      return ExactMoney(
        coefficient: BigInt.parse(atoms),
        scale: scale,
        currencyCode: currencyCode,
      );
    }
    return ExactMoney.parse(
      projection.toStringAsFixed(scale ?? 2),
      currencyCode ?? 'PHP',
    );
  }
}

import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import '../value_objects/exact_money.dart';

part 'recurring_template.g.dart';

@JsonSerializable()
class RecurringTemplate extends Equatable {
  final String id;
  final String accountId;
  final String? categoryId;
  final String? payeeId;
  final double amount;
  final String? amountAtoms;
  final int? amountScale;
  final String? currencyCode;
  final String recurrenceRule;
  final bool reminderEnabled;
  final bool autoCreateDisabled;
  final DateTime? nextOccurrenceAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const RecurringTemplate({
    required this.id,
    required this.accountId,
    this.categoryId,
    this.payeeId,
    required this.amount,
    this.amountAtoms,
    this.amountScale,
    this.currencyCode,
    required this.recurrenceRule,
    this.reminderEnabled = true,
    this.autoCreateDisabled = false,
    this.nextOccurrenceAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory RecurringTemplate.fromJson(Map<String, dynamic> json) =>
      _$RecurringTemplateFromJson(json);

  Map<String, dynamic> toJson() => _$RecurringTemplateToJson(this);

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

  RecurringTemplate copyWith({
    String? id,
    String? accountId,
    String? Function()? categoryId,
    String? Function()? payeeId,
    double? amount,
    String? Function()? amountAtoms,
    int? Function()? amountScale,
    String? Function()? currencyCode,
    String? recurrenceRule,
    bool? reminderEnabled,
    bool? autoCreateDisabled,
    DateTime? Function()? nextOccurrenceAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) {
    return RecurringTemplate(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId != null ? categoryId() : this.categoryId,
      payeeId: payeeId != null ? payeeId() : this.payeeId,
      amount: amount ?? this.amount,
      amountAtoms: amountAtoms != null ? amountAtoms() : this.amountAtoms,
      amountScale: amountScale != null ? amountScale() : this.amountScale,
      currencyCode: currencyCode != null ? currencyCode() : this.currencyCode,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      autoCreateDisabled: autoCreateDisabled ?? this.autoCreateDisabled,
      nextOccurrenceAt: nextOccurrenceAt != null
          ? nextOccurrenceAt()
          : this.nextOccurrenceAt,
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
    amount,
    amountAtoms,
    amountScale,
    currencyCode,
    recurrenceRule,
    reminderEnabled,
    autoCreateDisabled,
    nextOccurrenceAt,
    createdAt,
    updatedAt,
    deletedAt,
  ];
}

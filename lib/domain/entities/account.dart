import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import '../value_objects/exact_money.dart';

part 'account.g.dart';

@JsonSerializable()
class Account extends Equatable {
  final String id;
  final String? householdId;
  final String ownerUserId;
  final String name;
  final String accountType;
  final double balance;
  final String currencyCode;
  final String? balanceAtoms;
  final int? currencyPrecision;
  final bool isArchived;
  final bool isHidden;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Account({
    required this.id,
    this.householdId,
    required this.ownerUserId,
    required this.name,
    required this.accountType,
    required this.balance,
    required this.currencyCode,
    this.balanceAtoms,
    this.currencyPrecision,
    required this.isArchived,
    required this.isHidden,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);

  Map<String, dynamic> toJson() => _$AccountToJson(this);

  ExactMoney get exactBalance => balanceAtoms == null
      ? ExactMoney.parse(
          balance.toStringAsFixed(currencyPrecision ?? 2),
          currencyCode,
        )
      : ExactMoney(
          coefficient: BigInt.parse(balanceAtoms!),
          scale: currencyPrecision ?? 2,
          currencyCode: currencyCode,
        );

  Account copyWith({
    String? id,
    String? Function()? householdId,
    String? ownerUserId,
    String? name,
    String? accountType,
    double? balance,
    String? currencyCode,
    String? Function()? balanceAtoms,
    int? Function()? currencyPrecision,
    bool? isArchived,
    bool? isHidden,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) {
    return Account(
      id: id ?? this.id,
      householdId: householdId != null ? householdId() : this.householdId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      name: name ?? this.name,
      accountType: accountType ?? this.accountType,
      balance: balance ?? this.balance,
      currencyCode: currencyCode ?? this.currencyCode,
      balanceAtoms: balanceAtoms != null ? balanceAtoms() : this.balanceAtoms,
      currencyPrecision: currencyPrecision != null
          ? currencyPrecision()
          : this.currencyPrecision,
      isArchived: isArchived ?? this.isArchived,
      isHidden: isHidden ?? this.isHidden,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    householdId,
    ownerUserId,
    name,
    accountType,
    balance,
    currencyCode,
    balanceAtoms,
    currencyPrecision,
    isArchived,
    isHidden,
    createdAt,
    updatedAt,
    deletedAt,
  ];
}

import 'package:equatable/equatable.dart';

class DebtRecord extends Equatable {
  final String id;
  final double amount;

  const DebtRecord({required this.id, required this.amount});

  @override
  List<Object?> get props => [id, amount];
}

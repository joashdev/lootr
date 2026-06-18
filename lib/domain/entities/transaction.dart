import 'package:equatable/equatable.dart';

class Transaction extends Equatable {
  final String id;
  final double amount;

  const Transaction({required this.id, required this.amount});

  @override
  List<Object?> get props => [id, amount];
}

import 'package:equatable/equatable.dart';

class Budget extends Equatable {
  final String id;
  final double amount;

  const Budget({required this.id, required this.amount});

  @override
  List<Object?> get props => [id, amount];
}

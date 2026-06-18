import 'package:equatable/equatable.dart';

class Transfer extends Equatable {
  final String id;
  final double amount;

  const Transfer({required this.id, required this.amount});

  @override
  List<Object?> get props => [id, amount];
}

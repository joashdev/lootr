import 'package:equatable/equatable.dart';

class Payee extends Equatable {
  final String id;
  final String name;

  const Payee({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}

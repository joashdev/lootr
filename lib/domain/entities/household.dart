import 'package:equatable/equatable.dart';

class Household extends Equatable {
  final String id;
  final String name;

  const Household({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}

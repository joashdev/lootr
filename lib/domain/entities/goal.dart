import 'package:equatable/equatable.dart';

class Goal extends Equatable {
  final String id;
  final String name;

  const Goal({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}

import 'package:equatable/equatable.dart';

class Account extends Equatable {
  final String id;
  final String name;

  const Account({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}

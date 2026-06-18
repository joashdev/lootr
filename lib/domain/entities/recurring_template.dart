import 'package:equatable/equatable.dart';

class RecurringTemplate extends Equatable {
  final String id;
  final String name;

  const RecurringTemplate({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}

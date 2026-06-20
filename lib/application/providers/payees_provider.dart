import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/entities/payee.dart';
import 'repo_providers.dart';

final payeesProvider = StreamProvider<List<Payee>>((ref) {
  final repo = ref.watch(payeeRepoProvider);
  return repo.watchAll().map(
        (rows) => rows.map((r) => r.toEntity()).toList(),
      );
});

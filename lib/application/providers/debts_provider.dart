import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/debt_record.dart';
import '../../domain/entities/mappers.dart';
import 'repo_providers.dart';

final debtsProvider = StreamProvider<List<DebtRecord>>((ref) {
  final repo = ref.watch(debtRepoProvider);
  return repo.watchAll().map((rows) => rows.map((r) => r.toEntity()).toList());
});

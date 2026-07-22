import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/debt_record.dart';
import '../../domain/entities/mappers.dart';
import 'repo_providers.dart';

final debtDetailProvider = StreamProvider.family<DebtRecord?, String>((
  ref,
  debtId,
) {
  final repo = ref.watch(debtRepoProvider);
  return repo.watchById(debtId).map((row) => row?.toEntity());
});

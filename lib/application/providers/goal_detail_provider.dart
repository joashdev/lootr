import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/mappers.dart';
import 'repo_providers.dart';

final goalDetailProvider = StreamProvider.family<Goal?, String>((ref, goalId) {
  final repo = ref.watch(goalRepoProvider);
  return repo.watchById(goalId).map((row) {
    if (row == null) return null;
    final entity = row.toEntity();
    final progress = entity.targetAmount > 0
        ? (entity.currentAmount / entity.targetAmount) * 100
        : 0.0;
    return entity.copyWith(progress: progress);
  });
});

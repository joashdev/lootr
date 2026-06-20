import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/mappers.dart';
import 'repo_providers.dart';

final goalsProvider = StreamProvider<List<Goal>>((ref) {
  final repo = ref.watch(goalRepoProvider);
  return repo.watchAll().map((rows) {
    return rows.map((r) {
      final entity = r.toEntity();
      final progress = entity.targetAmount > 0
          ? (entity.currentAmount / entity.targetAmount) * 100
          : 0.0;
      return entity.copyWith(progress: progress);
    }).toList();
  });
});

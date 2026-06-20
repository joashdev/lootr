import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/mappers.dart';
import 'repo_providers.dart';

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final repo = ref.watch(categoryRepoProvider);
  return repo.watchAll().map(
        (rows) => rows.map((r) => r.toEntity()).toList(),
      );
});

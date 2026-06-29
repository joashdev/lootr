import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repo_providers.dart';

final categorySeedProvider = FutureProvider<void>((ref) async {
  final repo = ref.watch(categoryRepoProvider);
  await repo.seedCategories();
});

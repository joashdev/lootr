import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repo_providers.dart';

final currentUserProvider = StreamProvider((ref) {
  final repo = ref.watch(userRepoProvider);
  return repo.watchCurrentUser();
});

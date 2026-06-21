import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repo_providers.dart';

final aiProcessingLogsProvider = StreamProvider((ref) {
  final repo = ref.watch(aiProcessingLogRepoProvider);
  return repo.watchAll();
});

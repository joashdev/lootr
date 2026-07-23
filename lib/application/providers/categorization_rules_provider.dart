import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import 'repo_providers.dart';

final categorizationRulesProvider =
    StreamProvider<List<CategorizationRuleData>>((ref) {
      return ref
          .watch(categorizationRuleRepoProvider)
          .watchAll(includeArchived: true);
    });

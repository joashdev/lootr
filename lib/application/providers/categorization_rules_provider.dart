import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../categorization/categorization_rules.dart';
import 'repo_providers.dart';

final categorizationRulesCommandsProvider = Provider<CategorizationRules>((
  ref,
) {
  return CategorizationRules(ref.watch(categorizationRuleRepoProvider));
});

final categorizationRulesProvider =
    StreamProvider<List<CategorizationRuleView>>((ref) {
      return ref.watch(categorizationRulesCommandsProvider).watchAll();
    });

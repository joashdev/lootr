import '../../data/repositories/categorization_rule_repo.dart';

class CategorizationRuleView {
  const CategorizationRuleView({
    required this.id,
    required this.matchTarget,
    required this.matchKind,
    required this.pattern,
    required this.normalizedPattern,
    required this.categoryId,
    required this.priority,
    required this.isActive,
    required this.isArchived,
  });

  final String id;
  final String matchTarget;
  final String matchKind;
  final String pattern;
  final String normalizedPattern;
  final String categoryId;
  final int priority;
  final bool isActive;
  final bool isArchived;
}

class UpdateCategorizationRuleCommand {
  const UpdateCategorizationRuleCommand({
    required this.id,
    required this.matchTarget,
    required this.matchKind,
    required this.pattern,
    required this.categoryId,
    this.priority,
  });

  final String id;
  final String matchTarget;
  final String matchKind;
  final String pattern;
  final String categoryId;
  final int? priority;
}

class RememberCategorizationCorrectionCommand {
  const RememberCategorizationCorrectionCommand({
    this.rule,
    required this.matchTarget,
    required this.correctedCategoryId,
    required this.input,
  });

  final CategorizationRuleView? rule;
  final String matchTarget;
  final String correctedCategoryId;
  final String input;
}

/// Application boundary for presenting and managing categorization memory.
///
/// New rules are deliberately exposed only through [rememberCorrection].
/// Settings can manage existing rules, but cannot manufacture one without an
/// explicit correction and opt-in from Add.
class CategorizationRules {
  CategorizationRules(this._repository);

  final CategorizationRuleRepo _repository;

  Stream<List<CategorizationRuleView>> watchAll() {
    return _repository
        .watchAll(includeArchived: true)
        .map(
          (rows) => rows
              .map(
                (row) => CategorizationRuleView(
                  id: row.id,
                  matchTarget: row.matchTarget,
                  matchKind: row.matchKind,
                  pattern: row.pattern,
                  normalizedPattern: row.normalizedPattern,
                  categoryId: row.categoryId,
                  priority: row.priority,
                  isActive: row.isActive,
                  isArchived: row.isArchived,
                ),
              )
              .toList(growable: false),
        );
  }

  Future<CategorizationRuleView?> match({String? title, String? payee}) async {
    final row = await _repository.match(title: title, payee: payee);
    if (row == null) return null;
    return CategorizationRuleView(
      id: row.id,
      matchTarget: row.matchTarget,
      matchKind: row.matchKind,
      pattern: row.pattern,
      normalizedPattern: row.normalizedPattern,
      categoryId: row.categoryId,
      priority: row.priority,
      isActive: row.isActive,
      isArchived: row.isArchived,
    );
  }

  Future<void> update(UpdateCategorizationRuleCommand command) {
    return _repository.update(
      id: command.id,
      matchTarget: command.matchTarget,
      matchKind: command.matchKind,
      pattern: command.pattern,
      categoryId: command.categoryId,
      priority: command.priority,
    );
  }

  Future<void> setActive(String id, bool active) {
    return _repository.setActive(id, active);
  }

  Future<void> archive(String id) => _repository.archive(id);

  Future<void> restore(String id) => _repository.restore(id);

  Future<void> delete(String id) => _repository.delete(id);

  Future<void> rememberCorrection(
    RememberCategorizationCorrectionCommand command,
  ) async {
    final input = command.input.trim();
    final rule = command.rule;
    if (input.isEmpty ||
        (rule != null && command.correctedCategoryId == rule.categoryId)) {
      return;
    }

    final normalizedInput = CategorizationRuleRepo.normalize(input);
    if (rule?.matchKind == 'exact' &&
        rule?.normalizedPattern == normalizedInput) {
      await _repository.update(
        id: rule!.id,
        matchTarget: rule.matchTarget,
        matchKind: 'exact',
        pattern: input,
        categoryId: command.correctedCategoryId,
        priority: rule.priority,
      );
      return;
    }

    await _repository.create(
      id: 'rule-${DateTime.now().microsecondsSinceEpoch}',
      matchTarget: rule?.matchTarget ?? command.matchTarget,
      matchKind: 'exact',
      pattern: input,
      categoryId: command.correctedCategoryId,
      priority: (rule?.priority ?? -1) + 1,
    );
  }
}

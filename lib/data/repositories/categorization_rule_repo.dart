import 'package:drift/drift.dart' hide isNull;

import '../database/app_database.dart';

class CategorizationRuleRepo {
  CategorizationRuleRepo(this._db);

  final AppDatabase _db;

  Future<String> create({
    required String id,
    required String matchTarget,
    required String matchKind,
    required String pattern,
    required String categoryId,
    int priority = 0,
  }) async {
    final normalized = normalize(pattern);
    if (normalized.isEmpty) {
      throw ArgumentError.value(pattern, 'pattern', 'must not be empty');
    }
    await _db
        .into(_db.categorizationRules)
        .insert(
          CategorizationRulesCompanion.insert(
            id: id,
            matchTarget: matchTarget,
            matchKind: matchKind,
            pattern: pattern,
            normalizedPattern: normalized,
            categoryId: categoryId,
            priority: Value(priority),
          ),
        );
    return id;
  }

  Stream<List<CategorizationRuleData>> watchAll({
    bool includeArchived = false,
  }) {
    final query = _db.select(_db.categorizationRules);
    if (!includeArchived) {
      query.where((row) => row.isArchived.equals(false));
    }
    return query.watch();
  }

  Future<CategorizationRuleData?> getById(String id) {
    return (_db.select(_db.categorizationRules)
          ..where((row) => row.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> update({
    required String id,
    required String matchTarget,
    required String matchKind,
    required String pattern,
    required String categoryId,
    int? priority,
  }) async {
    final normalized = normalize(pattern);
    if (normalized.isEmpty) {
      throw ArgumentError.value(pattern, 'pattern', 'must not be empty');
    }
    await (_db.update(
      _db.categorizationRules,
    )..where((row) => row.id.equals(id))).write(
      CategorizationRulesCompanion(
        matchTarget: Value(matchTarget),
        matchKind: Value(matchKind),
        pattern: Value(pattern.trim()),
        normalizedPattern: Value(normalized),
        categoryId: Value(categoryId),
        priority: priority == null ? const Value.absent() : Value(priority),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setActive(String id, bool active) {
    return (_db.update(
      _db.categorizationRules,
    )..where((row) => row.id.equals(id))).write(
      CategorizationRulesCompanion(
        isActive: Value(active),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> archive(String id) {
    return (_db.update(
      _db.categorizationRules,
    )..where((row) => row.id.equals(id))).write(
      CategorizationRulesCompanion(
        isArchived: const Value(true),
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> restore(String id) {
    return (_db.update(
      _db.categorizationRules,
    )..where((row) => row.id.equals(id))).write(
      CategorizationRulesCompanion(
        isArchived: const Value(false),
        isActive: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> delete(String id) async {
    await (_db.delete(
      _db.categorizationRules,
    )..where((row) => row.id.equals(id))).go();
  }

  /// Returns one deterministic match. Exact rules always precede contains
  /// rules; archived or inactive rules never participate.
  Future<CategorizationRuleData?> match({String? title, String? payee}) async {
    final candidates =
        await (_db.select(_db.categorizationRules)..where(
              (row) => row.isActive.equals(true) & row.isArchived.equals(false),
            ))
            .get();
    final inputs = {
      'title': title == null ? null : normalize(title),
      'payee': payee == null ? null : normalize(payee),
    };
    final matches = candidates.where((rule) {
      final input = inputs[rule.matchTarget];
      if (input == null || input.isEmpty) return false;
      return switch (rule.matchKind) {
        'exact' => input == rule.normalizedPattern,
        'contains' => input.contains(rule.normalizedPattern),
        _ => false,
      };
    }).toList();
    matches.sort(_compareRules);
    return matches.firstOrNull;
  }

  static String normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static int _compareRules(
    CategorizationRuleData left,
    CategorizationRuleData right,
  ) {
    final leftKind = left.matchKind == 'exact' ? 0 : 1;
    final rightKind = right.matchKind == 'exact' ? 0 : 1;
    var comparison = leftKind.compareTo(rightKind);
    if (comparison != 0) return comparison;
    comparison = right.priority.compareTo(left.priority);
    if (comparison != 0) return comparison;
    comparison = right.normalizedPattern.length.compareTo(
      left.normalizedPattern.length,
    );
    if (comparison != 0) return comparison;
    comparison = left.createdAt.compareTo(right.createdAt);
    if (comparison != 0) return comparison;
    return left.id.compareTo(right.id);
  }
}

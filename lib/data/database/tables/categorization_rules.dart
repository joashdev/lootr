import 'package:drift/drift.dart';

import 'categories.dart';

@DataClassName('CategorizationRuleData')
@TableIndex(
  name: 'idx_categorization_rule_match',
  columns: {#isActive, #matchTarget, #matchKind, #normalizedPattern},
)
class CategorizationRules extends Table {
  TextColumn get id => text()();
  TextColumn get matchTarget => text().named('match_target')();
  TextColumn get matchKind => text().named('match_kind')();
  TextColumn get pattern => text()();
  TextColumn get normalizedPattern => text().named('normalized_pattern')();
  TextColumn get categoryId =>
      text().named('category_id').references(Categories, #id)();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  BoolColumn get isActive =>
      boolean().named('is_active').withDefault(const Constant(true))();
  BoolColumn get isArchived =>
      boolean().named('is_archived').withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (match_target IN (\'title\', \'payee\'))',
    'CHECK (match_kind IN (\'exact\', \'contains\'))',
  ];
}

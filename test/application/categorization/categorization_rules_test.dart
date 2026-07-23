import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/categorization/categorization_rules.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/categorization_rule_repo.dart';

void main() {
  test(
    'explicit correction command creates the first future-only rule',
    () async {
      final database = AppDatabase.inMemory();
      addTearDown(database.close);
      await database.categories.insertOne(
        CategoriesCompanion.insert(
          id: 'cat-corrected',
          name: 'Groceries',
          categoryGroup: 'expense',
        ),
      );
      final rules = CategorizationRules(CategorizationRuleRepo(database));

      await rules.rememberCorrection(
        const RememberCategorizationCorrectionCommand(
          matchTarget: 'payee',
          correctedCategoryId: 'cat-corrected',
          input: 'Corner Market',
        ),
      );

      final created = await database
          .select(database.categorizationRules)
          .getSingle();
      expect(created.matchTarget, 'payee');
      expect(created.matchKind, 'exact');
      expect(created.normalizedPattern, 'corner market');
      expect(created.categoryId, 'cat-corrected');
    },
  );
}

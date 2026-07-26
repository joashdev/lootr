import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/categorization/categorization_rules.dart';
import 'package:lootr/application/providers/categorization_rules_provider.dart';
import 'package:lootr/application/providers/categories_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/domain/entities/category.dart';
import 'package:lootr/presentation/screens/more/categorization_rules_screen.dart';

Widget _wrap(List<CategorizationRuleView> rules) {
  return ProviderScope(
    overrides: [
      categorizationRulesProvider.overrideWith((ref) => Stream.value(rules)),
      categoriesProvider.overrideWith(
        (ref) => Stream.value([
          Category(
            id: 'cat-1',
            name: 'Food',
            categoryGroup: 'expense',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ]),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const CategorizationRulesScreen(),
    ),
  );
}

void main() {
  testWidgets('empty management screen cannot create an arbitrary rule', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Add category rule'), findsNothing);
    expect(find.text('Add Rule'), findsNothing);
    expect(find.textContaining('Remember this correction'), findsOneWidget);
  });

  testWidgets('archived rule offers restore but not edit', (tester) async {
    await tester.pumpWidget(
      _wrap(const [
        CategorizationRuleView(
          id: 'rule-1',
          matchTarget: 'payee',
          matchKind: 'exact',
          pattern: 'Corner Market',
          normalizedPattern: 'corner market',
          categoryId: 'cat-1',
          priority: 0,
          isActive: false,
          isArchived: true,
        ),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rule actions'));
    await tester.pumpAndSettle();

    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
  });
}

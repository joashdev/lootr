import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/ai/categorizer.dart';
import 'package:lootr/domain/value_objects/field_types.dart';

void main() {
  group('Categorizer', () {
    test('returns null when no payee or note', () async {
      const categorizer = Categorizer();
      final result = await categorizer.suggest(amount: 100, payee: null);
      expect(result, isNull);
    });

    test('returns category from payee history', () async {
      const categorizer = Categorizer(
        payeeCategoryHistory: {'starbucks': 'Dining', 'shell': 'Transport'},
      );
      final result = await categorizer.suggest(payee: 'starbucks');
      expect(result, isNotNull);
      expect(result!.categoryId, 'Dining');
      expect(result.confidence, 0.9);
      expect(result.source, 'history');
      expect(result.isDeterministic, isTrue);
    });

    test('matches payee case-insensitively', () async {
      const categorizer = Categorizer(
        payeeCategoryHistory: {'starbucks': 'Dining'},
      );
      final result = await categorizer.suggest(payee: 'STARBUCKS');
      expect(result, isNotNull);
      expect(result!.categoryId, 'Dining');
    });

    test('returns income category for income direction', () async {
      const categorizer = Categorizer();
      final result = await categorizer.suggest(
        payee: 'unknown_client',
        direction: TransactionDirection.income,
      );
      expect(result, isNotNull);
      expect(result!.categoryId, 'Income');
      expect(result.confidence, 0.7);
      expect(result.source, 'heuristic');
    });

    test('categorizes from note keywords', () async {
      const categorizer = Categorizer();
      final result = await categorizer.suggest(
        payee: 'merchant',
        note: 'groceries shopping at market',
      );
      expect(result, isNotNull);
      expect(result!.categoryId, 'Groceries');
      expect(result.confidence, 0.5);
    });

    test('categorizes transport from note gas keyword', () async {
      const categorizer = Categorizer();
      final result = await categorizer.suggest(
        payee: 'shell',
        note: 'gas fillup',
      );
      expect(result, isNotNull);
      expect(result!.categoryId, 'Transport');
    });

    test('categorizes dining from note', () async {
      const categorizer = Categorizer();
      final result = await categorizer.suggest(
        payee: 'restaurant',
        note: 'dining out with friends',
      );
      expect(result, isNotNull);
      expect(result!.categoryId, 'Dining');
    });

    test('categorizes rent from note', () async {
      const categorizer = Categorizer();
      final result = await categorizer.suggest(
        payee: 'landlord',
        note: 'monthly rent payment',
      );
      expect(result, isNotNull);
      expect(result!.categoryId, 'Rent');
    });

    test('returns null when no history and no keywords match', () async {
      const categorizer = Categorizer();
      final result = await categorizer.suggest(
        payee: 'some_merchant',
        note: 'misc',
      );
      expect(result, isNull);
    });

    test('prefers payee history over note keywords', () async {
      const categorizer = Categorizer(
        payeeCategoryHistory: {'shell': 'Transport'},
      );
      final result = await categorizer.suggest(
        payee: 'shell',
        note: 'groceries',
      );
      expect(result, isNotNull);
      expect(result!.categoryId, 'Transport');
      expect(result.source, 'history');
    });

    test('modelEnabled does not error (stub in V1)', () async {
      const categorizer = Categorizer(modelEnabled: true);
      final result = await categorizer.suggest(
        payee: 'new_merchant',
        note: 'unknown',
      );
      expect(result, isNull);
    });

    test('copyWith creates new instance with updated fields', () {
      const categorizer = Categorizer(
        payeeCategoryHistory: {'a': 'X'},
      );
      final updated = categorizer.copyWith(
        modelEnabled: true,
        payeeCategoryHistory: {'b': 'Y'},
      );
      expect(updated.modelEnabled, isTrue);
      expect(updated.payeeCategoryHistory, {'b': 'Y'});
    });

    test('CategorySuggestion equality', () {
      const a = CategorySuggestion(categoryId: 'Food', confidence: 0.9, source: 'history');
      const b = CategorySuggestion(categoryId: 'Food', confidence: 0.9, source: 'history');
      const c = CategorySuggestion(categoryId: 'Transport', confidence: 0.9, source: 'history');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}

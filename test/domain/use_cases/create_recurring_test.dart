import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart';
import 'package:lootr/data/repositories/recurring_repo.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/entities/recurring_template.dart';
import 'package:lootr/domain/use_cases/create_recurring.dart';
import 'package:lootr/domain/value_objects/result.dart';

class MockRecurringRepo extends Mock implements RecurringRepo {}

void main() {
  late MockRecurringRepo mockRepo;
  late CreateRecurring useCase;

  setUpAll(() {
    registerFallbackValue(RecurringTemplatesCompanion(
      id: const Value(''),
      accountId: const Value(''),
      amount: const Value(0),
      recurrenceRule: const Value('daily'),
    ));
  });

  final testTemplate = RecurringTemplate(
    id: 'rec-1',
    accountId: 'acc-1',
    amount: 500,
    recurrenceRule: 'monthly',
    nextOccurrenceAt: DateTime(2026, 7, 19),
    createdAt: DateTime(2026, 6, 19),
    updatedAt: DateTime(2026, 6, 19),
  );

  setUp(() {
    mockRepo = MockRecurringRepo();
    useCase = CreateRecurring(mockRepo);
  });

  group('CreateRecurring', () {
    test('should return Failure when amount is zero', () async {
      final t = testTemplate.copyWith(amount: 0);

      final result = await useCase(t);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<String>;
      expect(failure.code, 'invalid_amount');
    });

    test('should return Failure for invalid recurrence rule', () async {
      final t = testTemplate.copyWith(recurrenceRule: 'invalid');

      final result = await useCase(t);

      expect(result.isFailure, isTrue);
      final failure = result as Failure<String>;
      expect(failure.code, 'invalid_rule');
    });

    test('should accept all valid rules', () async {
      const validRules = ['daily', 'weekly', 'biweekly', 'monthly', 'yearly'];

      for (final rule in validRules) {
        when(() => mockRepo.create(any())).thenAnswer((_) async => 'rec-1');
        final t = testTemplate.copyWith(recurrenceRule: rule);
        final result = await useCase(t);
        expect(result.isSuccess, isTrue);
      }
    });

    test('should return Success with id on valid template', () async {
      when(() => mockRepo.create(any())).thenAnswer((_) async => 'rec-1');

      final result = await useCase(testTemplate);

      expect(result.isSuccess, isTrue);
      final success = result as Success<String>;
      expect(success.value, 'rec-1');
    });
  });
}

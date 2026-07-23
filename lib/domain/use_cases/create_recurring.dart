import '../../core/recurring/recurrence_date.dart';
import '../../data/repositories/recurring_repo.dart';
import '../entities/recurring_template.dart';
import '../entities/mappers.dart';
import '../value_objects/result.dart';

class CreateRecurring {
  final RecurringRepo _recurringRepo;

  CreateRecurring(this._recurringRepo);

  Future<Result<String>> call(RecurringTemplate template) async {
    if (template.amount <= 0) {
      return Failure(
        'Amount must be greater than zero',
        code: 'invalid_amount',
      );
    }

    const validRules = [
      'daily',
      'weekly',
      'biweekly',
      'monthly',
      'quarterly',
      'yearly',
    ];
    if (!validRules.contains(template.recurrenceRule)) {
      return Failure(
        'Invalid recurrence rule: ${template.recurrenceRule}',
        code: 'invalid_rule',
      );
    }

    try {
      DateTime? nextAt = template.nextOccurrenceAt;
      nextAt ??= nextRecurrenceDate(DateTime.now(), template.recurrenceRule);

      final entity = template.copyWith(
        nextOccurrenceAt: nextAt != null ? () => nextAt : () => null,
      );

      final id = await _recurringRepo.create(entity.toCompanion());
      return Success(id);
    } catch (e) {
      return Failure(
        'Failed to create recurring template: $e',
        code: 'create_error',
      );
    }
  }
}

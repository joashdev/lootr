import '../entities/recurring_template.dart';
import '../value_objects/result.dart';
import '../../data/repositories/recurring_repo.dart';
import '../entities/mappers.dart';

class CreateRecurring {
  final RecurringRepo _recurringRepo;

  CreateRecurring(this._recurringRepo);

  Future<Result<String>> call(RecurringTemplate template) async {
    if (template.amount <= 0) {
      return Failure('Amount must be greater than zero', code: 'invalid_amount');
    }

    const validRules = ['daily', 'weekly', 'biweekly', 'monthly', 'yearly'];
    if (!validRules.contains(template.recurrenceRule)) {
      return Failure('Invalid recurrence rule: ${template.recurrenceRule}',
          code: 'invalid_rule');
    }

    try {
      final nextAt = _computeNext(DateTime.now(), template.recurrenceRule);

      final entity = template.copyWith(
        nextOccurrenceAt: nextAt != null ? () => nextAt : () => null,
      );

      final id = await _recurringRepo.create(entity.toCompanion());
      return Success(id);
    } catch (e) {
      return Failure('Failed to create recurring template: $e',
          code: 'create_error');
    }
  }

  DateTime? _computeNext(DateTime current, String rule) {
    switch (rule) {
      case 'daily':
        return current.add(const Duration(days: 1));
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'biweekly':
        return current.add(const Duration(days: 14));
      case 'monthly':
        final y = current.month == 12 ? current.year + 1 : current.year;
        final m = current.month == 12 ? 1 : current.month + 1;
        final d = current.day > 28 ? 28 : current.day;
        return DateTime(y, m, d);
      case 'yearly':
        return DateTime(current.year + 1, current.month,
            current.day > 28 ? 28 : current.day);
      default:
        return null;
    }
  }
}

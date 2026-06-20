import '../entities/transaction.dart';
import '../value_objects/result.dart';
import '../value_objects/field_types.dart';
import '../../data/repositories/transaction_repo.dart';
import '../../data/repositories/recurring_repo.dart';
import '../entities/mappers.dart';

class AdvanceRecurring {
  final TransactionRepo _transactionRepo;
  final RecurringRepo _recurringRepo;

  AdvanceRecurring(this._transactionRepo, this._recurringRepo);

  Future<Result<void>> call(String templateId) async {
    try {
      final template =
          await _recurringRepo.watchById(templateId).first;
      if (template == null) {
        return Failure('Recurring template not found: $templateId',
            code: 'not_found');
      }

      final now = DateTime.now();
      final occurredAt = template.nextOccurrenceAt ?? now;

      final transaction = Transaction(
        id: 'txn-${now.microsecondsSinceEpoch}',
        accountId: template.accountId,
        categoryId: template.categoryId,
        payeeId: template.payeeId,
        amount: template.amount,
        direction: TransactionDirection.expense,
        mode: TransactionMode.recurring,
        occurredAt: occurredAt,
        createdAt: now,
        updatedAt: now,
      );

      await _transactionRepo.create(transaction.toCompanion());

      await _recurringRepo.advanceNextOccurrence(templateId);

      return const Success(null);
    } catch (e) {
      return Failure('Failed to advance recurring: $e',
          code: 'advance_error');
    }
  }
}

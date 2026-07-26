import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/recurring_detail_provider.dart';
import 'package:lootr/domain/value_objects/exact_money.dart';

void main() {
  test('future recurring occurrences are not actionable', () {
    final occurrence = RecurringOccurrenceView(
      id: 'occurrence',
      recurringTemplateId: 'series',
      status: 'due',
      originalDueAt: DateTime(2026, 8, 1),
      dueAt: DateTime(2026, 8, 1),
      amount: ExactMoney.parse('25.00', 'USD'),
    );

    expect(occurrence.isActionableAt(DateTime(2026, 7, 31, 23, 59)), isFalse);
    expect(occurrence.isActionableAt(DateTime(2026, 8, 1)), isTrue);
  });
}

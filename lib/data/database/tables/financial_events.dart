import 'package:drift/drift.dart';

import 'debt_records.dart';
import 'goals.dart';
import 'recurring_templates.dart';
import 'transactions.dart';

@DataClassName('RecurringOccurrenceData')
@TableIndex(
  name: 'idx_recurring_occurrence_template_due',
  columns: {#recurringTemplateId, #dueAt},
)
@TableIndex(name: 'idx_recurring_occurrence_status', columns: {#status})
class RecurringOccurrences extends Table {
  TextColumn get id => text()();
  TextColumn get recurringTemplateId => text()
      .named('recurring_template_id')
      .references(RecurringTemplates, #id)();
  TextColumn get transactionId =>
      text().named('transaction_id').nullable().references(Transactions, #id)();
  TextColumn get status => text()();
  DateTimeColumn get originalDueAt => dateTime().named('original_due_at')();
  DateTimeColumn get dueAt => dateTime().named('due_at')();
  DateTimeColumn get resolvedAt => dateTime().named('resolved_at').nullable()();
  TextColumn get amountAtoms => text().named('amount_atoms')();
  IntColumn get amountScale => integer().named('amount_scale')();
  TextColumn get currencyCode => text().named('currency_code')();
  TextColumn get sourceSeriesKey =>
      text().named('source_series_key').nullable()();
  TextColumn get sourceOccurrenceKey =>
      text().named('source_occurrence_key').nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (status IN (\'due\', \'paid\', \'unpaid\', \'skipped\', \'dismissed\'))',
    'CHECK (amount_scale >= 0)',
  ];
}

/// Immutable event stream used to derive and reconcile goal progress.
@DataClassName('GoalContributionEventData')
@TableIndex(name: 'idx_goal_event_goal_time', columns: {#goalId, #occurredAt})
class GoalContributionEvents extends Table {
  TextColumn get id => text()();
  TextColumn get goalId => text().named('goal_id').references(Goals, #id)();
  TextColumn get transactionId =>
      text().named('transaction_id').nullable().references(Transactions, #id)();
  TextColumn get eventType =>
      text().named('event_type').withDefault(const Constant('contribution'))();
  TextColumn get amountAtoms => text().named('amount_atoms')();
  IntColumn get amountScale => integer().named('amount_scale')();
  TextColumn get currencyCode => text().named('currency_code')();
  DateTimeColumn get occurredAt => dateTime().named('occurred_at')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (event_type IN (\'contribution\', \'withdrawal\', \'adjustment\'))',
    'CHECK (amount_scale >= 0)',
  ];
}

/// Immutable event stream used to derive and reconcile debt balances.
@DataClassName('DebtPaymentEventData')
@TableIndex(
  name: 'idx_debt_event_debt_time',
  columns: {#debtRecordId, #occurredAt},
)
class DebtPaymentEvents extends Table {
  TextColumn get id => text()();
  TextColumn get debtRecordId =>
      text().named('debt_record_id').references(DebtRecords, #id)();
  TextColumn get transactionId =>
      text().named('transaction_id').nullable().references(Transactions, #id)();
  TextColumn get eventType =>
      text().named('event_type').withDefault(const Constant('payment'))();
  TextColumn get amountAtoms => text().named('amount_atoms')();
  IntColumn get amountScale => integer().named('amount_scale')();
  TextColumn get currencyCode => text().named('currency_code')();
  DateTimeColumn get occurredAt => dateTime().named('occurred_at')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (event_type IN (\'payment\', \'refund\', \'adjustment\'))',
    'CHECK (amount_scale >= 0)',
  ];
}

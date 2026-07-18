import 'package:drift/drift.dart';
import 'users.dart';
import 'households.dart';

@DataClassName('GoalData')
@TableIndex(name: 'idx_goals_owner', columns: {#ownerUserId})
@TableIndex(name: 'idx_goals_type', columns: {#goalType})
class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get ownerUserId =>
      text().named('owner_user_id').references(Users, #id)();
  TextColumn get householdId =>
      text().named('household_id').nullable().references(Households, #id)();
  TextColumn get name => text()();
  TextColumn get goalType => text().named('goal_type')();
  RealColumn get targetAmount => real().named('target_amount')();
  RealColumn get currentAmount =>
      real().named('current_amount').withDefault(const Constant(0))();
  TextColumn get targetAmountAtoms =>
      text().named('target_amount_atoms').nullable()();
  TextColumn get currentAmountAtoms =>
      text().named('current_amount_atoms').nullable()();
  IntColumn get amountScale => integer().named('amount_scale').nullable()();
  TextColumn get currencyCode => text().named('currency_code').nullable()();
  DateTimeColumn get targetDate => dateTime().named('target_date').nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('local_only'))();
  DateTimeColumn get lastSyncedAt =>
      dateTime().named('last_synced_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (goal_type IN (\'emergency_fund\', \'savings\', \'travel\', \'debt_payoff\', \'custom\'))',
    'CHECK (amount_scale IS NULL OR amount_scale >= 0)',
    'CHECK (sync_status IN (\'local_only\', \'pending_sync\', \'synced\', \'sync_failed\'))',
  ];
}

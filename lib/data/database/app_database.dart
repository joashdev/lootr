import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/users.dart';
import 'tables/households.dart';
import 'tables/household_members.dart';
import 'tables/accounts.dart';
import 'tables/transactions.dart';
import 'tables/transfers.dart';
import 'tables/categories.dart';
import 'tables/payees.dart';
import 'tables/budgets.dart';
import 'tables/debt_records.dart';
import 'tables/goals.dart';
import 'tables/recurring_templates.dart';
import 'tables/account_balance_snapshots.dart';
import 'tables/notifications.dart';
import 'tables/ai_processing_logs.dart';
import 'tables/sync_metadata.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Users,
  Households,
  HouseholdMembers,
  Accounts,
  Transactions,
  Transfers,
  Categories,
  Payees,
  Budgets,
  DebtRecords,
  Goals,
  RecurringTemplates,
  AccountBalanceSnapshots,
  Notifications,
  AiProcessingLogs,
  SyncMetadata,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase()
      : super(
          driftDatabase(
            name: 'lootr',
          ),
        );

  @override
  int get schemaVersion => 1;
}

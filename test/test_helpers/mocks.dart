import 'package:mocktail/mocktail.dart';
import 'package:lootr/application/sync/connectivity_monitor.dart';
import 'package:lootr/application/sync/sync_http_client.dart';
import 'package:lootr/application/sync/sync_manager.dart';
import 'package:lootr/data/repositories/account_repo.dart';
import 'package:lootr/data/repositories/ai_processing_log_repo.dart';
import 'package:lootr/data/repositories/budget_repo.dart';
import 'package:lootr/data/repositories/category_repo.dart';
import 'package:lootr/data/repositories/debt_repo.dart';
import 'package:lootr/data/repositories/goal_repo.dart';
import 'package:lootr/data/repositories/household_repo.dart';
import 'package:lootr/data/repositories/payee_repo.dart';
import 'package:lootr/data/repositories/recurring_repo.dart';
import 'package:lootr/data/repositories/sync_metadata_repo.dart';
import 'package:lootr/data/repositories/transaction_repo.dart';
import 'package:lootr/data/repositories/transfer_repo.dart';
import 'package:lootr/data/repositories/user_repo.dart';

abstract class NotificationScheduler {
  Future<void> schedule({
    required String id,
    required DateTime scheduledAt,
    required String title,
    required String body,
  });

  Future<void> cancel(String id);

  Future<void> cancelAll();
}

class MockTransactionRepo extends Mock implements TransactionRepo {}

class MockAccountRepo extends Mock implements AccountRepo {}

class MockBudgetRepo extends Mock implements BudgetRepo {}

class MockCategoryRepo extends Mock implements CategoryRepo {}

class MockPayeeRepo extends Mock implements PayeeRepo {}

class MockTransferRepo extends Mock implements TransferRepo {}

class MockDebtRepo extends Mock implements DebtRepo {}

class MockGoalRepo extends Mock implements GoalRepo {}

class MockRecurringRepo extends Mock implements RecurringRepo {}

class MockUserRepo extends Mock implements UserRepo {}

class MockHouseholdRepo extends Mock implements HouseholdRepo {}

class MockSyncMetadataRepo extends Mock implements SyncMetadataRepo {}

class MockAiProcessingLogRepo extends Mock implements AiProcessingLogRepo {}

class MockSyncManager extends Mock implements SyncManager {}

class MockSyncHttpClient extends Mock implements SyncHttpClient {}

class MockConnectivityMonitor extends Mock implements ConnectivityMonitor {}

class MockNotificationScheduler extends Mock implements NotificationScheduler {}

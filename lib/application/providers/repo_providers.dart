import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/account_repo.dart';
import '../../data/repositories/ai_processing_log_repo.dart';
import '../../data/repositories/budget_repo.dart';
import '../../data/repositories/category_repo.dart';
import '../../data/repositories/categorization_rule_repo.dart';
import '../../data/repositories/composite_budget_repo.dart';
import '../../data/repositories/debt_repo.dart';
import '../../data/repositories/goal_repo.dart';
import '../../data/repositories/household_repo.dart';
import '../../data/repositories/payee_repo.dart';
import '../../data/repositories/recurring_repo.dart';
import '../../data/repositories/recurring_occurrence_repo.dart';
import '../../data/repositories/recurring_occurrence_service.dart';
import '../../data/repositories/sync_metadata_repo.dart';
import '../../data/repositories/transaction_repo.dart';
import '../../data/repositories/transfer_repo.dart';
import '../../data/repositories/user_repo.dart';
import 'database_provider.dart';

final transactionRepoProvider = Provider<TransactionRepo>((ref) {
  return TransactionRepo(ref.watch(databaseProvider));
});

final accountRepoProvider = Provider<AccountRepo>((ref) {
  return AccountRepo(ref.watch(databaseProvider));
});

final budgetRepoProvider = Provider<BudgetRepo>((ref) {
  return BudgetRepo(ref.watch(databaseProvider));
});

final compositeBudgetRepoProvider = Provider<CompositeBudgetRepo>((ref) {
  return CompositeBudgetRepo(ref.watch(databaseProvider));
});

final categoryRepoProvider = Provider<CategoryRepo>((ref) {
  return CategoryRepo(ref.watch(databaseProvider));
});

final payeeRepoProvider = Provider<PayeeRepo>((ref) {
  return PayeeRepo(ref.watch(databaseProvider));
});

final transferRepoProvider = Provider<TransferRepo>((ref) {
  return TransferRepo(ref.watch(databaseProvider));
});

final debtRepoProvider = Provider<DebtRepo>((ref) {
  return DebtRepo(ref.watch(databaseProvider));
});

final goalRepoProvider = Provider<GoalRepo>((ref) {
  return GoalRepo(ref.watch(databaseProvider));
});

final recurringRepoProvider = Provider<RecurringRepo>((ref) {
  return RecurringRepo(ref.watch(databaseProvider));
});

final recurringOccurrenceRepoProvider = Provider<RecurringOccurrenceRepo>((
  ref,
) {
  return RecurringOccurrenceRepo(ref.watch(databaseProvider));
});

final recurringOccurrenceServiceProvider = Provider<RecurringOccurrenceService>(
  (ref) {
    return RecurringOccurrenceService(
      ref.watch(databaseProvider),
      ref.watch(transactionRepoProvider),
      ref.watch(recurringOccurrenceRepoProvider),
    );
  },
);

final categorizationRuleRepoProvider = Provider<CategorizationRuleRepo>((ref) {
  return CategorizationRuleRepo(ref.watch(databaseProvider));
});

final userRepoProvider = Provider<UserRepo>((ref) {
  return UserRepo(ref.watch(databaseProvider));
});

final householdRepoProvider = Provider<HouseholdRepo>((ref) {
  return HouseholdRepo(ref.watch(databaseProvider));
});

final syncMetadataRepoProvider = Provider<SyncMetadataRepo>((ref) {
  return SyncMetadataRepo(ref.watch(databaseProvider));
});

final aiProcessingLogRepoProvider = Provider<AiProcessingLogRepo>((ref) {
  return AiProcessingLogRepo(ref.watch(databaseProvider));
});

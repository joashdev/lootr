import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/account_repo.dart';
import '../../data/repositories/budget_repo.dart';
import '../../data/repositories/category_repo.dart';
import '../../data/repositories/debt_repo.dart';
import '../../data/repositories/goal_repo.dart';
import '../../data/repositories/household_repo.dart';
import '../../data/repositories/payee_repo.dart';
import '../../data/repositories/recurring_repo.dart';
import '../../data/repositories/sync_metadata_repo.dart';
import '../../data/repositories/transaction_repo.dart';
import '../../data/repositories/transfer_repo.dart';
import '../../data/repositories/user_repo.dart';

final transactionRepoProvider = Provider<TransactionRepo>((ref) => throw UnimplementedError());
final accountRepoProvider = Provider<AccountRepo>((ref) => throw UnimplementedError());
final budgetRepoProvider = Provider<BudgetRepo>((ref) => throw UnimplementedError());
final categoryRepoProvider = Provider<CategoryRepo>((ref) => throw UnimplementedError());
final payeeRepoProvider = Provider<PayeeRepo>((ref) => throw UnimplementedError());
final transferRepoProvider = Provider<TransferRepo>((ref) => throw UnimplementedError());
final debtRepoProvider = Provider<DebtRepo>((ref) => throw UnimplementedError());
final goalRepoProvider = Provider<GoalRepo>((ref) => throw UnimplementedError());
final recurringRepoProvider = Provider<RecurringRepo>((ref) => throw UnimplementedError());
final userRepoProvider = Provider<UserRepo>((ref) => throw UnimplementedError());
final householdRepoProvider = Provider<HouseholdRepo>((ref) => throw UnimplementedError());
final syncMetadataRepoProvider = Provider<SyncMetadataRepo>((ref) => throw UnimplementedError());

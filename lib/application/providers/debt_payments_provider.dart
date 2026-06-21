import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/transaction_repo.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/entities/transaction.dart';
import 'repo_providers.dart';

final debtPaymentsProvider = StreamProvider.family<List<Transaction>, String>((
  ref,
  debtId,
) {
  final repo = ref.watch(transactionRepoProvider);
  return repo.watchFiltered(const TransactionRepoFilters()).map((rows) {
    final payments =
        rows
            .map((row) => row.toEntity())
            .where((transaction) => transaction.metadata?['debtId'] == debtId)
            .toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return payments;
  });
});

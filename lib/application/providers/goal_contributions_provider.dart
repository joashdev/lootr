import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/mappers.dart';
import '../../domain/entities/transaction.dart';
import '../../data/repositories/transaction_repo.dart';
import 'repo_providers.dart';

final goalContributionsProvider =
    StreamProvider.family<List<Transaction>, String>((ref, goalId) {
      final repo = ref.watch(transactionRepoProvider);
      return repo.watchFiltered(const TransactionRepoFilters()).map((rows) {
        final contributions =
            rows
                .map((row) => row.toEntity())
                .where(
                  (transaction) => transaction.metadata?['goalId'] == goalId,
                )
                .toList()
              ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
        return contributions;
      });
    });

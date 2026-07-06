import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/entities/transaction.dart';
import 'repo_providers.dart';

final accountDetailProvider =
    StreamProvider.family<({Account account, List<Transaction> transactions})?, String>(
  (ref, accountId) {
    final accountRepo = ref.watch(accountRepoProvider);
    final txnRepo = ref.watch(transactionRepoProvider);

    final accountStream = accountRepo.watchById(accountId).map(
          (row) => row?.toEntity(),
        );

    final txnStream = txnRepo.watchByAccount(accountId).map(
      (rows) =>
          rows.map((r) => r.toEntity()).toList()
            ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt)),
    );

    return Rx.combineLatest2(
      accountStream,
      txnStream,
      (Account? account, List<Transaction> transactions) {
        if (account == null) return null;
        return (account: account, transactions: transactions);
      },
    );
  },
);

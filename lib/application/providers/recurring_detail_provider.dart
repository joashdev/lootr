import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/entities/recurring_template.dart';
import '../../domain/entities/transaction.dart';
import '../../data/repositories/transaction_repo.dart';
import 'repo_providers.dart';

final recurringDetailProvider =
    StreamProvider.family<
      ({RecurringTemplate template, List<Transaction> transactions})?,
      String
    >((ref, templateId) {
      final recurringRepo = ref.watch(recurringRepoProvider);
      final txnRepo = ref.watch(transactionRepoProvider);

      final templateStream = recurringRepo
          .watchById(templateId)
          .map((row) => row?.toEntity());

      final txnStream = txnRepo
          .watchFiltered(const TransactionRepoFilters())
          .map(
            (rows) => rows
                .where((r) => r.recurringTemplateId == templateId)
                .map((r) => r.toEntity())
                .toList(),
          );

      return Rx.combineLatest2(templateStream, txnStream, (
        RecurringTemplate? template,
        List<Transaction> transactions,
      ) {
        if (template == null) return null;
        return (template: template, transactions: transactions);
      });
    });

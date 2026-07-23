import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/entities/recurring_template.dart';
import '../../domain/entities/transaction.dart';
import '../../data/repositories/transaction_repo.dart';
import '../../data/database/app_database.dart';
import 'repo_providers.dart';

final recurringDetailProvider =
    StreamProvider.family<
      ({
        RecurringTemplate template,
        List<Transaction> transactions,
        List<RecurringOccurrenceData> occurrences,
      })?,
      String
    >((ref, templateId) {
      final recurringRepo = ref.watch(recurringRepoProvider);
      final occurrenceRepo = ref.watch(recurringOccurrenceRepoProvider);
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

      final occurrenceStream = occurrenceRepo.watchForTemplate(templateId);

      return Rx.combineLatest3(templateStream, txnStream, occurrenceStream, (
        RecurringTemplate? template,
        List<Transaction> transactions,
        List<RecurringOccurrenceData> occurrences,
      ) {
        if (template == null) return null;
        return (
          template: template,
          transactions: transactions,
          occurrences: occurrences,
        );
      });
    });

final recurringOccurrenceProvider =
    StreamProvider.family<RecurringOccurrenceData?, String>((ref, id) {
      return ref.watch(recurringOccurrenceRepoProvider).watchById(id);
    });

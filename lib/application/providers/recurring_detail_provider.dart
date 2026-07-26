import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../../domain/entities/mappers.dart';
import '../../domain/entities/recurring_template.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/value_objects/exact_money.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/transaction_repo.dart';
import 'notification_provider.dart';
import 'repo_providers.dart';

class RecurringOccurrenceView {
  const RecurringOccurrenceView({
    required this.id,
    required this.recurringTemplateId,
    required this.status,
    required this.originalDueAt,
    required this.dueAt,
    required this.amount,
    this.resolvedAt,
    this.transactionId,
  });

  final String id;
  final String recurringTemplateId;
  final String status;
  final DateTime originalDueAt;
  final DateTime dueAt;
  final ExactMoney amount;
  final DateTime? resolvedAt;
  final String? transactionId;

  bool get isActionable => isActionableAt(DateTime.now());

  bool isActionableAt(DateTime now) =>
      (status == 'due' || status == 'unpaid') && !dueAt.isAfter(now);
}

class RecurringDetailView {
  const RecurringDetailView({
    required this.template,
    required this.transactions,
    required this.occurrences,
    required this.transactionDirection,
  });

  final RecurringTemplate template;
  final List<Transaction> transactions;
  final List<RecurringOccurrenceView> occurrences;
  final String transactionDirection;
}

class RecurringPaymentPrefill {
  const RecurringPaymentPrefill({
    required this.occurrenceId,
    required this.recurringTemplateId,
    required this.accountId,
    required this.amount,
    required this.direction,
    required this.occurredAt,
    this.categoryId,
    this.payeeId,
  });

  final String occurrenceId;
  final String recurringTemplateId;
  final String accountId;
  final String? categoryId;
  final String? payeeId;
  final ExactMoney amount;
  final String direction;
  final DateTime occurredAt;
}

RecurringOccurrenceView _occurrenceView(RecurringOccurrenceData row) {
  return RecurringOccurrenceView(
    id: row.id,
    recurringTemplateId: row.recurringTemplateId,
    status: row.status,
    originalDueAt: row.originalDueAt,
    dueAt: row.dueAt,
    amount: ExactMoney(
      coefficient: BigInt.parse(row.amountAtoms),
      scale: row.amountScale,
      currencyCode: row.currencyCode,
    ),
    resolvedAt: row.resolvedAt,
    transactionId: row.transactionId,
  );
}

final recurringOccurrenceBootstrapProvider = FutureProvider<void>((ref) {
  return ref.watch(recurringOccurrenceServiceProvider).ensureNextOccurrences();
});

final recurringDetailProvider =
    StreamProvider.family<RecurringDetailView?, String>((ref, templateId) {
      ref.watch(recurringOccurrenceBootstrapProvider);
      final recurringRepo = ref.watch(recurringRepoProvider);
      final occurrenceRepo = ref.watch(recurringOccurrenceRepoProvider);
      final txnRepo = ref.watch(transactionRepoProvider);

      final templateStream = recurringRepo.watchById(templateId);
      final txnStream = txnRepo
          .watchFiltered(const TransactionRepoFilters())
          .map(
            (rows) => rows
                .where((row) => row.recurringTemplateId == templateId)
                .map((row) => row.toEntity())
                .toList(),
          );
      final occurrenceStream = occurrenceRepo
          .watchForTemplate(templateId)
          .map((rows) => rows.map(_occurrenceView).toList());

      return Rx.combineLatest3(templateStream, txnStream, occurrenceStream, (
        RecurringTemplateData? template,
        List<Transaction> transactions,
        List<RecurringOccurrenceView> occurrences,
      ) {
        if (template == null) return null;
        return RecurringDetailView(
          template: template.toEntity(),
          transactions: transactions,
          occurrences: occurrences,
          transactionDirection: template.transactionDirection ?? 'expense',
        );
      });
    });

final recurringOccurrenceProvider =
    StreamProvider.family<RecurringOccurrenceView?, String>((ref, id) {
      return ref
          .watch(recurringOccurrenceRepoProvider)
          .watchById(id)
          .map((row) => row == null ? null : _occurrenceView(row));
    });

class RecurringOccurrenceCommands {
  RecurringOccurrenceCommands(this.ref);

  final Ref ref;

  Future<String> confirmPayment(
    String occurrenceId,
    Transaction transaction,
  ) async {
    final account = await ref
        .read(accountRepoProvider)
        .watchById(transaction.accountId)
        .first;
    if (account == null || account.deletedAt != null || account.isArchived) {
      throw StateError('The selected account is unavailable');
    }
    if (transaction.exactAmount.coefficient <= BigInt.zero) {
      throw ArgumentError('Amount must be greater than zero');
    }
    if (transaction.direction != 'expense' &&
        transaction.direction != 'income') {
      throw ArgumentError('Unsupported transaction direction');
    }
    final id = await ref
        .read(recurringOccurrenceServiceProvider)
        .pay(occurrenceId, transaction);
    await ref.read(notificationSchedulerProvider).rebuildSchedule();
    return id;
  }

  Future<void> skip(String occurrenceId) async {
    await ref.read(recurringOccurrenceServiceProvider).skip(occurrenceId);
    await ref.read(notificationSchedulerProvider).rebuildSchedule();
  }

  Future<void> updateOccurrence({
    required String id,
    required DateTime dueAt,
    required ExactMoney amount,
  }) async {
    await ref
        .read(recurringOccurrenceRepoProvider)
        .updateOccurrence(
          id: id,
          dueAt: dueAt,
          amountAtoms: amount.coefficient.toString(),
          amountScale: amount.scale,
          currencyCode: amount.currencyCode,
        );
  }

  Future<void> deleteSeries(String id) async {
    await ref.read(recurringRepoProvider).softDelete(id);
    await ref.read(notificationSchedulerProvider).rebuildSchedule();
  }

  Future<void> setSeriesEnabled(String id, {required bool enabled}) async {
    await ref
        .read(recurringRepoProvider)
        .update(
          RecurringTemplatesCompanion(
            id: Value(id),
            autoCreateDisabled: Value(!enabled),
          ),
        );
    await ref.read(notificationSchedulerProvider).rebuildSchedule();
  }
}

final recurringOccurrenceCommandsProvider =
    Provider<RecurringOccurrenceCommands>(RecurringOccurrenceCommands.new);

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/recurring/subscription_template_classifier.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/entities/payee.dart';
import '../../domain/entities/recurring_template.dart';
import '../../domain/value_objects/exact_money.dart';
import '../../data/database/app_database.dart';
import 'categories_provider.dart';
import 'database_provider.dart';
import 'payees_provider.dart';
import 'repo_providers.dart';
import 'recurring_detail_provider.dart';

final recurringProvider = StreamProvider<List<RecurringTemplate>>((ref) {
  final repo = ref.watch(recurringRepoProvider);
  return repo.watchAll().map((rows) {
    final entities = rows.map((r) => r.toEntity()).toList();
    entities.sort((a, b) {
      if (a.nextOccurrenceAt == null && b.nextOccurrenceAt == null) return 0;
      if (a.nextOccurrenceAt == null) return 1;
      if (b.nextOccurrenceAt == null) return -1;
      return a.nextOccurrenceAt!.compareTo(b.nextOccurrenceAt!);
    });
    return entities;
  });
});

final recurringOccurrencesProvider =
    StreamProvider<List<RecurringOccurrenceView>>((ref) {
      return ref
          .watch(recurringOccurrenceRepoProvider)
          .watchAll()
          .map((rows) => rows.map(_recurringOccurrenceView).toList());
    });

RecurringOccurrenceView _recurringOccurrenceView(RecurringOccurrenceData row) {
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

final subscriptionRecurringTemplateIdsProvider = StreamProvider<Set<String>>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  final templates =
      ref.watch(recurringProvider).asData?.value ?? const <RecurringTemplate>[];
  final payees = ref.watch(payeesProvider).asData?.value ?? const <Payee>[];
  final categories =
      ref.watch(categoriesProvider).asData?.value ?? const <Category>[];
  final payeeNames = {for (final payee in payees) payee.id: payee.resolvedName};
  final categoryNames = {
    for (final category in categories) category.id: category.name,
  };

  return (db.select(db.transactions)..where(
        (row) =>
            row.deletedAt.isNull() &
            row.recurringTemplateId.isNotNull() &
            row.transactionSubtype.equals('subscription'),
      ))
      .watch()
      .map((rows) {
        final historyIds = rows
            .map((row) => row.recurringTemplateId)
            .whereType<String>()
            .toSet();

        return templates
            .where(
              (template) => isSubscriptionRecurringTemplate(
                payeeName: template.payeeId == null
                    ? null
                    : payeeNames[template.payeeId!],
                categoryName: template.categoryId == null
                    ? null
                    : categoryNames[template.categoryId!],
                hasSubscriptionHistory: historyIds.contains(template.id),
              ),
            )
            .map((template) => template.id)
            .toSet();
      });
});

import 'package:drift/drift.dart' hide isNull;

import '../database/app_database.dart';
import '../repositories/account_repo.dart';
import 'demo_data_manifest.dart';

enum DemoInspectionStatus { absent, present, unverified }

class DemoInspection {
  final DemoInspectionStatus status;
  final bool canSeed;
  final int recordCount;

  const DemoInspection({
    required this.status,
    required this.canSeed,
    required this.recordCount,
  });
}

class DemoClearAnalysis {
  final int personalDependencyCount;
  final int affectedDemoRecordCount;

  const DemoClearAnalysis({
    required this.personalDependencyCount,
    required this.affectedDemoRecordCount,
  });

  bool get requiresRecovery => personalDependencyCount > 0;
}

class DemoDataService {
  final AppDatabase _db;

  DemoDataService(this._db);

  Future<DemoInspection> inspect() async {
    await reconcileLegacyRecords();
    var recordCount = await _demoRecordCount();
    final metadata = await (_db.select(
      _db.syncMetadata,
    )..where((row) => row.key.equals('demo_data_seeded'))).getSingleOrNull();
    final status = recordCount > 0
        ? DemoInspectionStatus.present
        : metadata?.value == 'true'
        ? DemoInspectionStatus.unverified
        : DemoInspectionStatus.absent;
    if (status == DemoInspectionStatus.unverified) {
      recordCount = (await _knownLegacyRecords()).length;
    }
    return DemoInspection(
      status: status,
      canSeed: status == DemoInspectionStatus.absent && await _ledgerIsEmpty(),
      recordCount: recordCount,
    );
  }

  Future<void> reconcileLegacyRecords() async {
    final reconciliationKey =
        'demo_manifest_reconciled_v${DemoDataManifest.seedVersion}';
    final reconciliation = await (_db.select(
      _db.syncMetadata,
    )..where((row) => row.key.equals(reconciliationKey))).getSingleOrNull();
    if (reconciliation?.value == 'true') return;

    final legacyFlag = await (_db.select(
      _db.syncMetadata,
    )..where((row) => row.key.equals('demo_data_seeded'))).getSingleOrNull();

    final existing = legacyFlag?.value == 'true'
        ? await _knownLegacyRecords()
        : <DemoRecordRef>[];
    if (existing.length == DemoDataManifest.knownRecords.length) {
      await _register(existing);
    }
    await _db
        .into(_db.syncMetadata)
        .insertOnConflictUpdate(
          SyncMetadataCompanion(
            key: Value(reconciliationKey),
            value: const Value('true'),
          ),
        );
  }

  Future<DemoClearAnalysis> analyzeClear() async {
    await reconcileLegacyRecords();
    final protected = await _protectedDemoRecords();
    return DemoClearAnalysis(
      personalDependencyCount: protected.personalDependencyCount,
      affectedDemoRecordCount: protected.recordCount,
    );
  }

  Future<void> dismissLegacyFlag() async {
    await reconcileLegacyRecords();
    await _db.transaction(() async {
      if (await _demoRecordCount() > 0 ||
          (await _knownLegacyRecords()).isNotEmpty) {
        throw StateError('Known sample records still exist.');
      }
      await _db
          .into(_db.syncMetadata)
          .insertOnConflictUpdate(
            const SyncMetadataCompanion(
              key: Value('demo_data_seeded'),
              value: Value('false'),
            ),
          );
    });
  }

  Future<void> clear({
    bool preservePersonalDependencies = true,
    bool reviewLegacyRecords = false,
  }) async {
    await reconcileLegacyRecords();
    final reviewedRecords = reviewLegacyRecords
        ? await _knownLegacyRecords()
        : <DemoRecordRef>[];
    if (reviewLegacyRecords && reviewedRecords.isEmpty) {
      throw StateError('No known sample records were found.');
    }
    await _db.transaction(() async {
      await _register(reviewedRecords);
      final protected = await _protectedDemoRecords();
      if (protected.personalDependencyCount > 0 &&
          !preservePersonalDependencies) {
        throw StateError('Personal records depend on sample data.');
      }

      final personalUserId = await _personalUserId();
      if (personalUserId == null &&
          (protected.accountIds.isNotEmpty ||
              protected.budgetIds.isNotEmpty ||
              protected.goalIds.isNotEmpty ||
              protected.debtIds.isNotEmpty)) {
        protected.userIds.addAll(
          (await (_db.select(_db.demoRecords)..where(
                    (row) =>
                        row.entityType.equals(DemoEntityType.user.tableName),
                  ))
                  .get())
              .map((row) => row.entityId),
        );
      }
      if (protected.accountIds.isNotEmpty && personalUserId != null) {
        await (_db.update(_db.accounts)
              ..where((row) => row.id.isIn(protected.accountIds)))
            .write(AccountsCompanion(ownerUserId: Value(personalUserId)));
      }
      if (protected.budgetIds.isNotEmpty && personalUserId != null) {
        await (_db.update(_db.budgets)
              ..where((row) => row.id.isIn(protected.budgetIds)))
            .write(BudgetsCompanion(ownerUserId: Value(personalUserId)));
      }
      if (protected.goalIds.isNotEmpty && personalUserId != null) {
        await (_db.update(_db.goals)
              ..where((row) => row.id.isIn(protected.goalIds)))
            .write(GoalsCompanion(ownerUserId: Value(personalUserId)));
      }
      if (protected.debtIds.isNotEmpty && personalUserId != null) {
        await (_db.update(_db.debtRecords)
              ..where((row) => row.id.isIn(protected.debtIds)))
            .write(DebtRecordsCompanion(ownerUserId: Value(personalUserId)));
      }

      await _deleteUnprotected(protected);

      for (final accountId in protected.accountIds) {
        await AccountRepo(_db).recalcBalance(accountId);
      }

      await _db.delete(_db.demoRecords).go();
      await _db
          .into(_db.syncMetadata)
          .insertOnConflictUpdate(
            const SyncMetadataCompanion(
              key: Value('demo_data_seeded'),
              value: Value('false'),
            ),
          );
    });
  }

  Future<void> _deleteUnprotected(_ProtectedDemoRecords protected) async {
    final records = await _db.select(_db.demoRecords).get();
    Set<String> registered(DemoEntityType type) => records
        .where((record) => record.entityType == type.tableName)
        .map((record) => record.entityId)
        .toSet();
    Set<String> deletable(DemoEntityType type, Set<String> kept) => records
        .where((record) => record.entityType == type.tableName)
        .map((record) => record.entityId)
        .where((id) => !kept.contains(id))
        .toSet();

    final allEntityIds = records.map((record) => record.entityId).toSet();
    final allAccountIds = registered(DemoEntityType.account);
    final allTransactionIds = registered(DemoEntityType.transaction);
    final allRecurringIds = registered(DemoEntityType.recurring);

    if (allAccountIds.isNotEmpty) {
      await (_db.delete(
        _db.accountBalanceSnapshots,
      )..where((row) => row.accountId.isIn(allAccountIds))).go();
    }
    if (allRecurringIds.isNotEmpty || allTransactionIds.isNotEmpty) {
      await (_db.delete(_db.recurringOccurrences)..where(
            (row) =>
                row.status.equals('due') &
                (row.recurringTemplateId.isIn(allRecurringIds) |
                    row.transactionId.isIn(allTransactionIds)),
          ))
          .go();
    }
    if (allEntityIds.isNotEmpty) {
      await (_db.delete(
        _db.notifications,
      )..where((row) => row.relatedEntityId.isIn(allEntityIds))).go();
      await (_db.delete(
        _db.aiProcessingLogs,
      )..where((row) => row.sourceReferenceId.isIn(allEntityIds))).go();
    }

    final transactionIds = deletable(
      DemoEntityType.transaction,
      protected.transactionIds,
    );
    if (transactionIds.isNotEmpty) {
      await (_db.delete(
        _db.transactions,
      )..where((row) => row.id.isIn(transactionIds))).go();
    }
    final recurringIds = deletable(
      DemoEntityType.recurring,
      protected.recurringIds,
    );
    if (recurringIds.isNotEmpty) {
      await (_db.delete(
        _db.recurringTemplates,
      )..where((row) => row.id.isIn(recurringIds))).go();
    }
    final budgetIds = deletable(DemoEntityType.budget, protected.budgetIds);
    if (budgetIds.isNotEmpty) {
      await (_db.delete(
        _db.budgets,
      )..where((row) => row.id.isIn(budgetIds))).go();
    }
    final goalIds = deletable(DemoEntityType.goal, protected.goalIds);
    if (goalIds.isNotEmpty) {
      await (_db.delete(_db.goals)..where((row) => row.id.isIn(goalIds))).go();
    }
    final debtIds = deletable(DemoEntityType.debt, protected.debtIds);
    if (debtIds.isNotEmpty) {
      await (_db.delete(
        _db.debtRecords,
      )..where((row) => row.id.isIn(debtIds))).go();
    }
    final accountIds = deletable(DemoEntityType.account, protected.accountIds);
    if (accountIds.isNotEmpty) {
      await (_db.delete(
        _db.accounts,
      )..where((row) => row.id.isIn(accountIds))).go();
    }
    final payeeIds = deletable(DemoEntityType.payee, protected.payeeIds);
    if (payeeIds.isNotEmpty) {
      await (_db.delete(
        _db.payees,
      )..where((row) => row.id.isIn(payeeIds))).go();
    }
    final userIds = deletable(DemoEntityType.user, protected.userIds);
    if (userIds.isNotEmpty) {
      await (_db.delete(_db.users)..where((row) => row.id.isIn(userIds))).go();
    }
  }

  Future<_ProtectedDemoRecords> _protectedDemoRecords() async {
    final records = await _db.select(_db.demoRecords).get();
    final byType = <String, Set<String>>{};
    for (final record in records) {
      byType
          .putIfAbsent(record.entityType, () => <String>{})
          .add(record.entityId);
    }
    final protected = _ProtectedDemoRecords();

    final demoTransactionIds =
        byType[DemoEntityType.transaction.tableName] ?? const {};
    final demoAccountIds = byType[DemoEntityType.account.tableName] ?? const {};
    final demoPayeeIds = byType[DemoEntityType.payee.tableName] ?? const {};
    final demoRecurringIds =
        byType[DemoEntityType.recurring.tableName] ?? const {};
    final demoGoalIds = byType[DemoEntityType.goal.tableName] ?? const {};
    final demoDebtIds = byType[DemoEntityType.debt.tableName] ?? const {};
    final demoBudgetIds = byType[DemoEntityType.budget.tableName] ?? const {};
    final demoUserIds = byType[DemoEntityType.user.tableName] ?? const {};

    final personalAccounts =
        await (_db.select(_db.accounts)..where(
              (row) =>
                  row.id.isNotIn(demoAccountIds) &
                  row.ownerUserId.isIn(demoUserIds),
            ))
            .get();
    final personalBudgets =
        await (_db.select(_db.budgets)..where(
              (row) =>
                  row.id.isNotIn(demoBudgetIds) &
                  row.ownerUserId.isIn(demoUserIds),
            ))
            .get();
    final personalGoals =
        await (_db.select(_db.goals)..where(
              (row) =>
                  row.id.isNotIn(demoGoalIds) &
                  row.ownerUserId.isIn(demoUserIds),
            ))
            .get();
    final personalDebts =
        await (_db.select(_db.debtRecords)..where(
              (row) =>
                  row.id.isNotIn(demoDebtIds) &
                  row.ownerUserId.isIn(demoUserIds),
            ))
            .get();
    final personalBudgetDefinitions = await (_db.select(
      _db.budgetDefinitions,
    )..where((row) => row.ownerUserId.isIn(demoUserIds))).get();
    final personalOwnedCount =
        personalAccounts.length +
        personalBudgets.length +
        personalGoals.length +
        personalDebts.length +
        personalBudgetDefinitions.length;
    protected.personalDependencyCount += personalOwnedCount;
    if (personalOwnedCount > 0) {
      protected.userIds.addAll(demoUserIds);
    }

    final personalTransactions =
        await (_db.select(_db.transactions)..where(
              (row) =>
                  row.id.isNotIn(demoTransactionIds) &
                  (row.accountId.isIn(demoAccountIds) |
                      row.payeeId.isIn(demoPayeeIds) |
                      row.recurringTemplateId.isIn(demoRecurringIds) |
                      row.parentTransactionId.isIn(demoTransactionIds)),
            ))
            .get();
    protected.personalDependencyCount += personalTransactions.length;
    for (final transaction in personalTransactions) {
      if (demoAccountIds.contains(transaction.accountId)) {
        protected.accountIds.add(transaction.accountId);
      }
      if (demoPayeeIds.contains(transaction.payeeId)) {
        protected.payeeIds.add(transaction.payeeId!);
      }
      if (demoRecurringIds.contains(transaction.recurringTemplateId)) {
        protected.recurringIds.add(transaction.recurringTemplateId!);
      }
      if (demoTransactionIds.contains(transaction.parentTransactionId)) {
        protected.transactionIds.add(transaction.parentTransactionId!);
      }
    }

    final personalTransfers =
        await (_db.select(_db.transfers)..where(
              (row) =>
                  row.sourceAccountId.isIn(demoAccountIds) |
                  row.destinationAccountId.isIn(demoAccountIds),
            ))
            .get();
    protected.personalDependencyCount += personalTransfers.length;
    for (final transfer in personalTransfers) {
      if (demoAccountIds.contains(transfer.sourceAccountId)) {
        protected.accountIds.add(transfer.sourceAccountId);
      }
      if (demoAccountIds.contains(transfer.destinationAccountId)) {
        protected.accountIds.add(transfer.destinationAccountId);
      }
    }

    final accountMemberships = await (_db.select(
      _db.budgetAccountMemberships,
    )..where((row) => row.accountId.isIn(demoAccountIds))).get();
    protected.personalDependencyCount += accountMemberships.length;
    for (final membership in accountMemberships) {
      protected.accountIds.add(membership.accountId!);
    }

    final transactionMemberships = await (_db.select(
      _db.budgetTransactionMemberships,
    )..where((row) => row.transactionId.isIn(demoTransactionIds))).get();
    protected.personalDependencyCount += transactionMemberships.length;
    for (final membership in transactionMemberships) {
      protected.transactionIds.add(membership.transactionId!);
    }

    final personalRecurring =
        await (_db.select(_db.recurringTemplates)..where(
              (row) =>
                  row.id.isNotIn(demoRecurringIds) &
                  (row.accountId.isIn(demoAccountIds) |
                      row.payeeId.isIn(demoPayeeIds)),
            ))
            .get();
    protected.personalDependencyCount += personalRecurring.length;
    for (final recurring in personalRecurring) {
      if (demoAccountIds.contains(recurring.accountId)) {
        protected.accountIds.add(recurring.accountId);
      }
      if (demoPayeeIds.contains(recurring.payeeId)) {
        protected.payeeIds.add(recurring.payeeId!);
      }
    }

    final resolvedOccurrences =
        await (_db.select(_db.recurringOccurrences)..where(
              (row) =>
                  row.status.equals('due').not() &
                  (row.recurringTemplateId.isIn(demoRecurringIds) |
                      row.transactionId.isIn(demoTransactionIds)),
            ))
            .get();
    protected.personalDependencyCount += resolvedOccurrences.length;
    for (final occurrence in resolvedOccurrences) {
      if (demoRecurringIds.contains(occurrence.recurringTemplateId)) {
        protected.recurringIds.add(occurrence.recurringTemplateId);
      }
      if (demoTransactionIds.contains(occurrence.transactionId)) {
        protected.transactionIds.add(occurrence.transactionId!);
      }
    }

    final goalEvents =
        await (_db.select(_db.goalContributionEvents)..where(
              (row) =>
                  row.goalId.isIn(demoGoalIds) |
                  row.transactionId.isIn(demoTransactionIds),
            ))
            .get();
    protected.personalDependencyCount += goalEvents.length;
    for (final event in goalEvents) {
      if (demoGoalIds.contains(event.goalId)) {
        protected.goalIds.add(event.goalId);
      }
      if (demoTransactionIds.contains(event.transactionId)) {
        protected.transactionIds.add(event.transactionId!);
      }
    }

    final debtEvents =
        await (_db.select(_db.debtPaymentEvents)..where(
              (row) =>
                  row.debtRecordId.isIn(demoDebtIds) |
                  row.transactionId.isIn(demoTransactionIds),
            ))
            .get();
    protected.personalDependencyCount += debtEvents.length;
    for (final event in debtEvents) {
      if (demoDebtIds.contains(event.debtRecordId)) {
        protected.debtIds.add(event.debtRecordId);
      }
      if (demoTransactionIds.contains(event.transactionId)) {
        protected.transactionIds.add(event.transactionId!);
      }
    }

    final attachments = await (_db.select(
      _db.transactionAttachmentLinks,
    )..where((row) => row.transactionId.isIn(demoTransactionIds))).get();
    protected.personalDependencyCount += attachments.length;
    for (final attachment in attachments) {
      protected.transactionIds.add(attachment.transactionId);
    }

    final personalHouseholds = await (_db.select(
      _db.households,
    )..where((row) => row.createdByUserId.isIn(demoUserIds))).get();
    final personalMemberships = await (_db.select(
      _db.householdMembers,
    )..where((row) => row.userId.isIn(demoUserIds))).get();
    protected.personalDependencyCount +=
        personalHouseholds.length + personalMemberships.length;
    protected.userIds.addAll(
      personalHouseholds.map((row) => row.createdByUserId),
    );
    protected.userIds.addAll(personalMemberships.map((row) => row.userId));

    await _protectAncestors(protected, byType);
    return protected;
  }

  Future<void> _protectAncestors(
    _ProtectedDemoRecords protected,
    Map<String, Set<String>> byType,
  ) async {
    final demoAccountIds = byType[DemoEntityType.account.tableName] ?? const {};
    final demoPayeeIds = byType[DemoEntityType.payee.tableName] ?? const {};
    final demoRecurringIds =
        byType[DemoEntityType.recurring.tableName] ?? const {};

    if (protected.transactionIds.isNotEmpty) {
      final transactions = await (_db.select(
        _db.transactions,
      )..where((row) => row.id.isIn(protected.transactionIds))).get();
      for (final transaction in transactions) {
        if (demoAccountIds.contains(transaction.accountId)) {
          protected.accountIds.add(transaction.accountId);
        }
        if (demoPayeeIds.contains(transaction.payeeId)) {
          protected.payeeIds.add(transaction.payeeId!);
        }
        if (demoRecurringIds.contains(transaction.recurringTemplateId)) {
          protected.recurringIds.add(transaction.recurringTemplateId!);
        }
      }
    }
    if (protected.recurringIds.isNotEmpty) {
      final recurring = await (_db.select(
        _db.recurringTemplates,
      )..where((row) => row.id.isIn(protected.recurringIds))).get();
      for (final row in recurring) {
        if (demoAccountIds.contains(row.accountId)) {
          protected.accountIds.add(row.accountId);
        }
        if (demoPayeeIds.contains(row.payeeId)) {
          protected.payeeIds.add(row.payeeId!);
        }
      }
    }
  }

  Future<String?> _personalUserId() async {
    final demoUserIds =
        (await (_db.select(_db.demoRecords)..where(
                  (row) => row.entityType.equals(DemoEntityType.user.tableName),
                ))
                .get())
            .map((row) => row.entityId)
            .toSet();
    final users = await _db.select(_db.users).get();
    for (final user in users) {
      if (!demoUserIds.contains(user.id)) return user.id;
    }
    return null;
  }

  Future<bool> _ledgerIsEmpty() async {
    final counts = await Future.wait<int>([
      _db.select(_db.accounts).get().then((rows) => rows.length),
      _db.select(_db.payees).get().then((rows) => rows.length),
      _db.select(_db.transactions).get().then((rows) => rows.length),
      _db.select(_db.transfers).get().then((rows) => rows.length),
      _db.select(_db.budgets).get().then((rows) => rows.length),
      _db.select(_db.goals).get().then((rows) => rows.length),
      _db.select(_db.debtRecords).get().then((rows) => rows.length),
      _db.select(_db.recurringTemplates).get().then((rows) => rows.length),
    ]);
    return counts.every((count) => count == 0);
  }

  Future<int> _demoRecordCount() async {
    final count = _db.demoRecords.entityId.count();
    final row = await (_db.selectOnly(
      _db.demoRecords,
    )..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> _register(Iterable<DemoRecordRef> records) async {
    final values = records
        .map(
          (record) => DemoRecordsCompanion.insert(
            entityType: record.entityType.tableName,
            entityId: record.entityId,
            seedVersion: const Value(DemoDataManifest.seedVersion),
          ),
        )
        .toList();
    if (values.isEmpty) return;
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.demoRecords, values);
    });
  }

  Future<List<DemoRecordRef>> _knownLegacyRecords() async {
    final existing = <DemoRecordRef>[];
    await _collectExisting(
      DemoEntityType.user,
      [DemoDataManifest.userId],
      (ids) => (_db.select(_db.users)..where((row) => row.id.isIn(ids))).get(),
      (row) => row.id,
      existing,
    );
    await _collectExisting(
      DemoEntityType.account,
      DemoDataManifest.accountIds,
      (ids) =>
          (_db.select(_db.accounts)..where((row) => row.id.isIn(ids))).get(),
      (row) => row.id,
      existing,
    );
    await _collectExisting(
      DemoEntityType.payee,
      DemoDataManifest.payeeIds,
      (ids) => (_db.select(_db.payees)..where((row) => row.id.isIn(ids))).get(),
      (row) => row.id,
      existing,
    );
    await _collectExisting(
      DemoEntityType.transaction,
      DemoDataManifest.transactionIds,
      (ids) => (_db.select(
        _db.transactions,
      )..where((row) => row.id.isIn(ids))).get(),
      (row) => row.id,
      existing,
    );
    await _collectExisting(
      DemoEntityType.budget,
      DemoDataManifest.budgetIds,
      (ids) =>
          (_db.select(_db.budgets)..where((row) => row.id.isIn(ids))).get(),
      (row) => row.id,
      existing,
    );
    await _collectExisting(
      DemoEntityType.goal,
      DemoDataManifest.goalIds,
      (ids) => (_db.select(_db.goals)..where((row) => row.id.isIn(ids))).get(),
      (row) => row.id,
      existing,
    );
    await _collectExisting(
      DemoEntityType.debt,
      DemoDataManifest.debtIds,
      (ids) =>
          (_db.select(_db.debtRecords)..where((row) => row.id.isIn(ids))).get(),
      (row) => row.id,
      existing,
    );
    await _collectExisting(
      DemoEntityType.recurring,
      DemoDataManifest.recurringIds,
      (ids) => (_db.select(
        _db.recurringTemplates,
      )..where((row) => row.id.isIn(ids))).get(),
      (row) => row.id,
      existing,
    );
    return existing;
  }

  Future<void> _collectExisting<T>(
    DemoEntityType entityType,
    Iterable<String> knownIds,
    Future<List<T>> Function(List<String> ids) query,
    String Function(T row) idOf,
    List<DemoRecordRef> target,
  ) async {
    final ids = knownIds.toList();
    if (ids.isEmpty) return;
    final rows = await query(ids);
    target.addAll(rows.map((row) => DemoRecordRef(entityType, idOf(row))));
  }
}

class _ProtectedDemoRecords {
  int personalDependencyCount = 0;
  final userIds = <String>{};
  final accountIds = <String>{};
  final payeeIds = <String>{};
  final transactionIds = <String>{};
  final budgetIds = <String>{};
  final goalIds = <String>{};
  final debtIds = <String>{};
  final recurringIds = <String>{};

  int get recordCount =>
      userIds.length +
      accountIds.length +
      payeeIds.length +
      transactionIds.length +
      budgetIds.length +
      goalIds.length +
      debtIds.length +
      recurringIds.length;
}

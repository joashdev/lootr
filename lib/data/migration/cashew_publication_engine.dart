import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'cashew/cashew_migration.dart';

class CashewPublicationEngine {
  const CashewPublicationEngine();

  Future<CashewPublicationResult> publish({
    required AppDatabase database,
    required String importRunId,
    required CashewAnalysis analysis,
    required String titlePolicy,
    required String timezoneId,
  }) async {
    if (analysis.report.hasBlockingIssues ||
        !analysis.report.sourceUnchanged ||
        !analysis.report.everySourceRowDisposed) {
      throw const CashewPublicationFailure('dry_run_blocking');
    }

    final context = _PublicationContext(
      database: database,
      importRunId: importRunId,
      analysis: analysis,
      titlePolicy: titlePolicy,
      timezoneId: timezoneId,
    );
    await database.transaction(() async {
      await context.publish();
      await database.customStatement('PRAGMA foreign_key_check');
    });
    return context.result();
  }
}

class _PublicationContext {
  _PublicationContext({
    required this.database,
    required this.importRunId,
    required this.analysis,
    required this.titlePolicy,
    required this.timezoneId,
  }) : byToken = {
         for (final record in analysis.records) record.sourceToken: record,
       };

  final AppDatabase database;
  final String importRunId;
  final CashewAnalysis analysis;
  final String titlePolicy;
  final String timezoneId;
  final Map<String, CanonicalCashewRecord> byToken;

  final Map<Object, String> accountIds = {};
  final Map<Object, int> accountPrecisions = {};
  final Map<Object, String> accountCurrencies = {};
  final Map<Object, BigInt> accountBalances = {};
  final Map<Object, String> categoryIds = {};
  final Map<Object, String> transactionIds = {};
  final Map<Object, String> budgetIds = {};
  final Map<Object, String> goalIds = {};
  final Map<Object, String> debtIds = {};
  final Set<Object> importedTransferLegs = {};
  final Set<Object> reviewedTransferLegs = {};
  final Set<String> recurringSeriesKeys = {};

  var insertedFinancialRecords = 0;
  var insertedPreservedRecords = 0;
  var reusedRecords = 0;

  Future<void> publish() async {
    await _assertReimportSafe();
    final ownerId = await _ownerId();
    await _persistSourceInventory();
    await _publishAccounts(ownerId);
    await _publishCategories();
    await _publishObjectives(ownerId);
    await _classifyTransferLegs();
    await _publishRecurringTemplates();
    await _publishTransactions();
    await _publishTransfers();
    await _publishObjectiveEvents();
    await _publishBudgets(ownerId);
    await _publishRules();
    await _publishPreservedRows();
    await _writeBalances();
  }

  CashewPublicationResult result() => CashewPublicationResult(
    insertedFinancialRecords: insertedFinancialRecords,
    preservedRecords: insertedPreservedRecords,
    reusedRecords: reusedRecords,
    accountPartitions: accountIds.length,
    reviewAccountPartitions: _reviewAccountKeys().length,
  );

  Future<void> _assertReimportSafe() async {
    for (final record in analysis.records) {
      final sourceId = _sourceEntityId(record);
      final payloadHash = _payloadHash(record.privatePayload);
      final rows = await database
          .customSelect(
            '''
        SELECT source_payload_sha256
        FROM import_provenance
        WHERE source_system = 'cashew'
          AND source_entity_type = ?
          AND source_entity_id = ?
        LIMIT 1
        ''',
            variables: [
              Variable.withString(record.sourceTable),
              Variable.withString(sourceId),
            ],
            readsFrom: {database.importProvenance},
          )
          .get();
      if (rows.isEmpty) continue;
      if (rows.single.read<String>('source_payload_sha256') != payloadHash) {
        throw const CashewPublicationFailure(
          'newer_export_conflicts_with_existing_mapping',
        );
      }
    }
  }

  Future<String> _ownerId() async {
    final users = await database
        .customSelect(
          'SELECT id FROM users WHERE deleted_at IS NULL ORDER BY created_at LIMIT 1',
          readsFrom: {database.users},
        )
        .get();
    if (users.isNotEmpty) return users.single.read<String>('id');
    const id = 'local-migration-owner';
    await _statement(
      '''
      INSERT OR IGNORE INTO users (id, timezone, sync_status)
      VALUES (?, ?, 'local_only')
      ''',
      [id, timezoneId],
    );
    return id;
  }

  Future<void> _persistSourceInventory() async {
    for (final record in analysis.records) {
      final sourceId = _sourceEntityId(record);
      final payloadHash = _payloadHash(record.privatePayload);
      await _statement(
        '''
        INSERT OR IGNORE INTO import_source_records (
          id, import_run_id, source_table, source_entity_id,
          source_payload_sha256, canonical_kind, canonical_payload_sha256,
          disposition, reason_code
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          _id('source', '${record.sourceTable}\u0000$sourceId'),
          importRunId,
          record.sourceTable,
          sourceId,
          payloadHash,
          record.kind,
          payloadHash,
          _disposition(record.disposition),
          record.issueCodes.isEmpty ? null : record.issueCodes.first,
        ],
      );
    }
    for (var ordinal = 0; ordinal < analysis.relationships.length; ordinal++) {
      final relation = analysis.relationships[ordinal];
      await _statement(
        '''
        INSERT OR IGNORE INTO import_source_relations (
          id, import_run_id, source_from, relation_kind, source_to,
          disposition, reason_code
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          _id('relation', '$ordinal\u0000${relation.kind}'),
          importRunId,
          _locatorHash(relation.fromToken),
          relation.kind,
          relation.toToken == null
              ? '<missing>'
              : _locatorHash(relation.toToken!),
          _disposition(relation.disposition),
          relation.issueCodes.isEmpty ? null : relation.issueCodes.first,
        ],
      );
    }
    for (var ordinal = 0; ordinal < analysis.issues.length; ordinal++) {
      final issue = analysis.issues[ordinal];
      await _statement(
        '''
        INSERT OR IGNORE INTO import_discrepancies (
          id, import_run_id, severity, issue_code, source_locator_hash,
          message_code, redacted_details_json, is_resolved
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          _id('issue', '$ordinal\u0000${issue.code}'),
          importRunId,
          _severity(issue.severity),
          issue.code,
          issue.sourceToken == null ? null : _locatorHash(issue.sourceToken!),
          issue.code,
          jsonEncode(const <String, Object>{'redacted': true}),
          issue.severity != CashewIssueSeverity.blocking ? 1 : 0,
        ],
      );
    }
  }

  Future<void> _publishAccounts(String ownerId) async {
    for (final record in _records('wallets')) {
      final row = record.privatePayload;
      final sourceId = row['wallet_pk']!;
      final targetId = _targetId('account', sourceId);
      final precision = row['decimals']! as int;
      final currency = (row['currency'] as String?)?.trim();
      final currencyCode = currency == null || currency.isEmpty
          ? 'UNKNOWN'
          : currency;
      accountIds[sourceId] = targetId;
      accountPrecisions[sourceId] = precision;
      accountCurrencies[sourceId] = currencyCode;
      accountBalances[sourceId] = BigInt.zero;

      final inserted = await _insertTarget(
        table: 'accounts',
        id: targetId,
        record: record,
        sql: '''
          INSERT OR IGNORE INTO accounts (
            id, owner_user_id, name, account_type, balance, currency_code,
            balance_atoms, currency_precision, icon, color, emoji_icon,
            sort_order, is_archived, sync_status
          ) VALUES (?, ?, ?, 'bank', 0, ?, '0', ?, ?, ?, ?, ?, ?, 'local_only')
        ''',
        values: [
          targetId,
          ownerId,
          row['name'],
          currencyCode,
          precision,
          row['icon_name'],
          row['colour'],
          row['emoji_icon_name'],
          row['order'],
          row['archived'] == 1 ? 1 : 0,
        ],
      );
      if (inserted) insertedFinancialRecords++;
    }
  }

  Future<void> _publishCategories() async {
    for (final record in _records('categories')) {
      final row = record.privatePayload;
      final sourceId = row['category_pk']!;
      categoryIds[sourceId] = _targetId('category', sourceId);
    }
    for (final record in _records('categories')) {
      final row = record.privatePayload;
      final sourceId = row['category_pk']!;
      final targetId = categoryIds[sourceId]!;
      final inserted = await _insertTarget(
        table: 'categories',
        id: targetId,
        record: record,
        sql: '''
          INSERT OR IGNORE INTO categories (
            id, parent_category_id, name, icon, color, emoji_icon,
            source_asset_icon, sort_order, is_archived, category_group,
            sync_status
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'local_only')
        ''',
        values: [
          targetId,
          null,
          row['name'],
          row['icon_name'],
          row['colour'],
          row['emoji_icon_name'],
          row['icon_name'],
          row['order'],
          row['archived'] == 1 ? 1 : 0,
          row['category_pk'] == '0'
              ? 'transfer'
              : (row['income'] == 1 ? 'income' : 'expense'),
        ],
      );
      if (inserted) insertedFinancialRecords++;
    }
    for (final record in _records('categories')) {
      final row = record.privatePayload;
      final parentId = categoryIds[row['main_category_pk']];
      if (parentId == null) continue;
      await _statement(
        'UPDATE categories SET parent_category_id = ? WHERE id = ?',
        [parentId, categoryIds[row['category_pk']]],
      );
    }
  }

  Future<void> _publishObjectives(String ownerId) async {
    for (final record in _records('objectives')) {
      final row = record.privatePayload;
      final sourceId = row['objective_pk']!;
      final walletId = row['wallet_fk'];
      final amount = _amount(row['amount']!, walletId);
      final targetDate = _date(row['end_date']);
      if (row['type'] == 1) {
        final targetId = _targetId('debt', sourceId);
        debtIds[sourceId] = targetId;
        final inserted = await _insertTarget(
          table: 'debt_records',
          id: targetId,
          record: record,
          sql: '''
            INSERT OR IGNORE INTO debt_records (
              id, owner_user_id, counterparty_name, debt_direction, amount,
              remaining_balance, amount_atoms, remaining_balance_atoms,
              amount_scale, currency_code, due_date, status, sync_status
            ) VALUES (?, ?, ?, 'borrowed', ?, ?, ?, ?, ?, ?, ?, 'active', 'local_only')
          ''',
          values: [
            targetId,
            ownerId,
            row['name'],
            amount.approximate,
            amount.approximate,
            amount.atoms.toString(),
            amount.atoms.toString(),
            amount.scale,
            amount.currency,
            targetDate,
          ],
        );
        if (inserted) insertedFinancialRecords++;
      } else {
        final targetId = _targetId('goal', sourceId);
        goalIds[sourceId] = targetId;
        final inserted = await _insertTarget(
          table: 'goals',
          id: targetId,
          record: record,
          sql: '''
            INSERT OR IGNORE INTO goals (
              id, owner_user_id, name, goal_type, target_amount, current_amount,
              target_amount_atoms, current_amount_atoms, amount_scale,
              currency_code, target_date, deleted_at, sync_status
            ) VALUES (?, ?, ?, 'savings', ?, 0, ?, '0', ?, ?, ?, ?, 'local_only')
          ''',
          values: [
            targetId,
            ownerId,
            row['name'],
            amount.approximate,
            amount.atoms.toString(),
            amount.scale,
            amount.currency,
            targetDate,
            row['archived'] == 1 ? DateTime.now().toUtc() : null,
          ],
        );
        if (inserted) insertedFinancialRecords++;
      }
    }
    for (final record in _records('transactions')) {
      final row = record.privatePayload;
      if (row['type'] != 3 && row['type'] != 4) continue;
      final sourceId = row['transaction_pk']!;
      final amount = _amount(row['amount']!, row['wallet_fk']);
      final targetId = _targetId('standalone-debt', sourceId);
      final inserted = await _insertTarget(
        table: 'debt_records',
        id: targetId,
        record: record,
        sql: '''
          INSERT OR IGNORE INTO debt_records (
            id, owner_user_id, counterparty_name, debt_direction, amount,
            remaining_balance, amount_atoms, remaining_balance_atoms,
            amount_scale, currency_code, note, due_date, status, sync_status
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', 'local_only')
        ''',
        values: [
          targetId,
          ownerId,
          row['name'],
          row['type'] == 3 ? 'lent' : 'borrowed',
          amount.approximate,
          amount.approximate,
          amount.atoms.toString(),
          amount.atoms.toString(),
          amount.scale,
          amount.currency,
          row['note'],
          _date(row['original_date_due']),
        ],
      );
      if (inserted) insertedFinancialRecords++;
    }
  }

  Future<void> _classifyTransferLegs() async {
    for (final relation in analysis.relationships) {
      if (relation.kind != 'same_currency_transfer' &&
          relation.kind != 'cross_currency_transfer') {
        continue;
      }
      final left = byToken[relation.fromToken];
      final right = relation.toToken == null ? null : byToken[relation.toToken];
      if (left == null || right == null) continue;
      final leftId = left.privatePayload['transaction_pk'];
      final rightId = right.privatePayload['transaction_pk'];
      if (relation.disposition == CashewDisposition.transformedImport) {
        importedTransferLegs
          ..add(leftId!)
          ..add(rightId!);
      } else {
        reviewedTransferLegs
          ..add(leftId!)
          ..add(rightId!);
      }
    }
  }

  Future<void> _publishRecurringTemplates() async {
    recurringSeriesKeys.addAll(
      _records('transactions')
          .map((record) => record.privatePayload['transaction_pk'])
          .whereType<String>()
          .where((sourceId) => sourceId.contains('::predict::'))
          .map((sourceId) => sourceId.split('::predict::').first),
    );
    final groups = <String, List<CanonicalCashewRecord>>{};
    for (final record in _records('transactions')) {
      final row = record.privatePayload;
      if (row['period_length'] == null || row['reoccurrence'] == null) continue;
      final pk = row['transaction_pk']! as String;
      final base = pk.split('::predict::').first;
      if (!recurringSeriesKeys.contains(base)) continue;
      groups.putIfAbsent(base, () => []).add(record);
    }
    for (final entry in groups.entries) {
      entry.value.sort(
        (left, right) => (left.privatePayload['date_created']! as int)
            .compareTo(right.privatePayload['date_created']! as int),
      );
      final first = entry.value.first;
      final row = first.privatePayload;
      final wallet = row['wallet_fk']!;
      final accountId = accountIds[wallet];
      if (accountId == null) continue;
      final amount = _amount(row['amount']!, wallet);
      final templateId = _targetId('recurring', entry.key);
      final unpaid = entry.value.where(
        (record) => record.privatePayload['paid'] == 0,
      );
      final next = unpaid
          .map(
            (record) =>
                record.privatePayload['canonical_original_due_utc']
                    as DateTime?,
          )
          .whereType<DateTime>()
          .fold<DateTime?>(
            null,
            (latest, value) =>
                latest == null || value.isAfter(latest) ? value : latest,
          );
      await _statement(
        '''
        INSERT OR IGNORE INTO recurring_templates (
          id, account_id, category_id, amount, amount_atoms, amount_scale,
          currency_code, transaction_direction, recurrence_rule,
          reminder_enabled, auto_create_disabled, next_occurrence_at, sync_status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, 'local_only')
        ''',
        [
          templateId,
          accountId,
          categoryIds[row['sub_category_fk'] ?? row['category_fk']],
          amount.approximate,
          amount.atoms.toString(),
          amount.scale,
          amount.currency,
          row['income'] == 1 ? 'income' : 'expense',
          _recurrenceRule(row),
          row['upcoming_transaction_notification'] == 1 ? 1 : 0,
          next,
        ],
      );
      for (final occurrence in entry.value) {
        final occurrenceRow = occurrence.privatePayload;
        final occurrenceAmount = _amount(
          occurrenceRow['amount']!,
          occurrenceRow['wallet_fk'],
        );
        final originalDue =
            occurrenceRow['canonical_original_due_utc'] as DateTime? ??
            _date(occurrenceRow['date_created'])!;
        final occurrenceId = _targetId(
          'occurrence',
          occurrenceRow['transaction_pk']!,
        );
        final paid = occurrenceRow['paid'] == 1;
        final skipped = !paid && occurrenceRow['skip_paid'] == 1;
        await _statement(
          '''
          INSERT OR IGNORE INTO recurring_occurrences (
            id, recurring_template_id, status, original_due_at, due_at,
            resolved_at, amount_atoms, amount_scale, currency_code,
            source_series_key, source_occurrence_key
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            occurrenceId,
            templateId,
            skipped ? 'skipped' : (paid ? 'paid' : 'unpaid'),
            originalDue,
            originalDue,
            paid ? occurrenceRow['canonical_resolved_utc'] as DateTime? : null,
            occurrenceAmount.atoms.toString(),
            occurrenceAmount.scale,
            occurrenceAmount.currency,
            entry.key,
            occurrenceRow['transaction_pk'],
          ],
        );
      }
    }
  }

  Future<void> _publishTransactions() async {
    for (final record in _records('transactions')) {
      final row = record.privatePayload;
      final sourceId = row['transaction_pk']!;
      if (importedTransferLegs.contains(sourceId) ||
          reviewedTransferLegs.contains(sourceId) ||
          (row['paired_transaction_fk'] != null &&
              record.disposition == CashewDisposition.reviewRequired) ||
          row['paid'] != 1) {
        continue;
      }
      if (record.disposition == CashewDisposition.invalidBlocking) continue;
      final wallet = row['wallet_fk']!;
      final accountId = accountIds[wallet];
      if (accountId == null) continue;
      final amount = _amount(row['amount']!, wallet);
      final targetId = _targetId('transaction', sourceId);
      transactionIds[sourceId] = targetId;
      final payeeId = titlePolicy == 'createPayees'
          ? await _payeeId(row['name']! as String)
          : null;
      final recurrencePk = (sourceId as String).split('::predict::').first;
      final recurringTemplateId =
          row['period_length'] != null &&
              row['reoccurrence'] != null &&
              recurringSeriesKeys.contains(recurrencePk)
          ? _targetId('recurring', recurrencePk)
          : null;
      final inserted = await _insertTarget(
        table: 'transactions',
        id: targetId,
        record: record,
        sql: '''
          INSERT OR IGNORE INTO transactions (
            id, account_id, category_id, payee_id, recurring_template_id,
            amount, amount_atoms, amount_scale, currency_code, title,
            transaction_direction, transaction_mode, transaction_subtype,
            note, metadata, occurred_at, sync_status
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'local_only')
        ''',
        values: [
          targetId,
          accountId,
          categoryIds[row['sub_category_fk'] ?? row['category_fk']],
          payeeId,
          recurringTemplateId,
          amount.approximate,
          amount.atoms.toString(),
          amount.scale,
          amount.currency,
          row['name'],
          row['income'] == 1 ? 'income' : 'expense',
          recurringTemplateId == null ? 'one_time' : 'recurring',
          row['category_fk'] == '0' ? 'opening_balance' : null,
          row['note'],
          jsonEncode({
            'source': 'cashew',
            'source_type': row['type'],
            'timezone_policy': timezoneId,
          }),
          _date(row['date_created'])!,
        ],
      );
      if (inserted) insertedFinancialRecords++;
      final signed = row['income'] == 1 ? amount.atoms : -amount.atoms;
      accountBalances[wallet] = accountBalances[wallet]! + signed;
      await _publishAttachmentLinks(record, targetId);
    }
  }

  Future<void> _publishTransfers() async {
    final seen = <String>{};
    for (final relation in analysis.relationships) {
      if ((relation.kind != 'same_currency_transfer' &&
              relation.kind != 'cross_currency_transfer') ||
          relation.disposition != CashewDisposition.transformedImport ||
          relation.toToken == null) {
        continue;
      }
      final left = byToken[relation.fromToken]!;
      final right = byToken[relation.toToken!]!;
      final pairKey = [left.sourceToken, right.sourceToken]..sort();
      if (!seen.add(pairKey.join('|'))) continue;
      final leftRow = left.privatePayload;
      final rightRow = right.privatePayload;
      final source = leftRow['income'] == 1 ? rightRow : leftRow;
      final destination = identical(source, leftRow) ? rightRow : leftRow;
      final sourceWallet = source['wallet_fk']!;
      final destinationWallet = destination['wallet_fk']!;
      final sourceAmount = _amount(source['amount']!, sourceWallet);
      final destinationAmount = _amount(
        destination['amount']!,
        destinationWallet,
      );
      final targetId = _targetId('transfer', pairKey.join('\u0000'));
      final inserted = await _insertTarget(
        table: 'transfers',
        id: targetId,
        record: left,
        sourceRecords: [left, right],
        sql: '''
          INSERT OR IGNORE INTO transfers (
            id, source_account_id, destination_account_id, amount,
            source_amount_atoms, source_amount_scale, source_currency_code,
            destination_amount_atoms, destination_amount_scale,
            destination_currency_code, note, occurred_at, sync_status
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'local_only')
        ''',
        values: [
          targetId,
          accountIds[sourceWallet],
          accountIds[destinationWallet],
          sourceAmount.approximate,
          sourceAmount.atoms.toString(),
          sourceAmount.scale,
          sourceAmount.currency,
          destinationAmount.atoms.toString(),
          destinationAmount.scale,
          destinationAmount.currency,
          source['note'],
          _date(source['date_created'])!,
        ],
      );
      if (inserted) insertedFinancialRecords++;
      accountBalances[sourceWallet] =
          accountBalances[sourceWallet]! - sourceAmount.atoms;
      accountBalances[destinationWallet] =
          accountBalances[destinationWallet]! + destinationAmount.atoms;
    }
  }

  Future<void> _publishObjectiveEvents() async {
    final goalTotals = <Object, BigInt>{};
    final debtPayments = <Object, BigInt>{};
    for (final record in _records('transactions')) {
      final row = record.privatePayload;
      if (row['paid'] != 1) continue;
      final wallet = row['wallet_fk'];
      final amount = _amount(row['amount']!, wallet);
      final transactionId = transactionIds[row['transaction_pk']];
      final goalSourceId = row['objective_fk'];
      if (goalSourceId != null && goalIds[goalSourceId] != null) {
        final eventId = _targetId('goal-event', row['transaction_pk']!);
        await _statement(
          '''
          INSERT OR IGNORE INTO goal_contribution_events (
            id, goal_id, transaction_id, event_type, amount_atoms,
            amount_scale, currency_code, occurred_at
          ) VALUES (?, ?, ?, 'contribution', ?, ?, ?, ?)
          ''',
          [
            eventId,
            goalIds[goalSourceId],
            transactionId != null &&
                    !importedTransferLegs.contains(row['transaction_pk'])
                ? transactionId
                : null,
            amount.atoms.toString(),
            amount.scale,
            amount.currency,
            _date(row['date_created'])!,
          ],
        );
        goalTotals[goalSourceId] =
            (goalTotals[goalSourceId] ?? BigInt.zero) + amount.atoms;
      }
      final debtSourceId = row['objective_loan_fk'];
      if (debtSourceId != null && debtIds[debtSourceId] != null) {
        final eventId = _targetId('debt-event', row['transaction_pk']!);
        await _statement(
          '''
          INSERT OR IGNORE INTO debt_payment_events (
            id, debt_record_id, transaction_id, event_type, amount_atoms,
            amount_scale, currency_code, occurred_at
          ) VALUES (?, ?, ?, 'payment', ?, ?, ?, ?)
          ''',
          [
            eventId,
            debtIds[debtSourceId],
            transactionId != null &&
                    !importedTransferLegs.contains(row['transaction_pk'])
                ? transactionId
                : null,
            amount.atoms.toString(),
            amount.scale,
            amount.currency,
            _date(row['date_created'])!,
          ],
        );
        debtPayments[debtSourceId] =
            (debtPayments[debtSourceId] ?? BigInt.zero) + amount.atoms;
      }
    }
    for (final entry in goalTotals.entries) {
      await _statement(
        'UPDATE goals SET current_amount_atoms = ?, current_amount = ? WHERE id = ?',
        [
          entry.value.toString(),
          _approximate(entry.value, _objectiveAmountScale(entry.key)),
          goalIds[entry.key],
        ],
      );
    }
    for (final entry in debtPayments.entries) {
      final objective = _objective(entry.key)!;
      final principal = _amount(
        objective.privatePayload['amount']!,
        objective.privatePayload['wallet_fk'],
      );
      final remaining = principal.atoms > entry.value
          ? principal.atoms - entry.value
          : BigInt.zero;
      await _statement(
        '''
        UPDATE debt_records
        SET remaining_balance_atoms = ?, remaining_balance = ?,
            status = CASE WHEN ? = '0' THEN 'settled' ELSE 'partially_paid' END
        WHERE id = ?
        ''',
        [
          remaining.toString(),
          _approximate(remaining, principal.scale),
          remaining.toString(),
          debtIds[entry.key],
        ],
      );
    }
  }

  Future<void> _publishBudgets(String ownerId) async {
    for (final record in _records('budgets')) {
      final row = record.privatePayload;
      final sourceId = row['budget_pk']!;
      final wallet = row['wallet_fk'];
      final amount = _amount(row['amount']!, wallet);
      final targetId = _targetId('budget', sourceId);
      budgetIds[sourceId] = targetId;
      final start = _date(row['start_date']);
      final end = _date(row['end_date']);
      final monthly = row['reoccurrence'] == 3;
      final hasMissingReference = record.issueCodes.contains(
        CashewIssueCodes.budgetDeletedAccount,
      );
      final inserted = await _insertTarget(
        table: 'budget_definitions',
        id: targetId,
        record: record,
        sql: '''
          INSERT OR IGNORE INTO budget_definitions (
            id, owner_user_id, name, amount_atoms, amount_scale, currency_code,
            period_type, period_start, period_end, cycle_rule,
            direction_filter, membership_mode, overlap_policy, review_state,
            is_read_only, sync_status
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'independent', ?, ?, 'local_only')
        ''',
        values: [
          targetId,
          ownerId,
          row['name'],
          amount.atoms.toString(),
          amount.scale,
          amount.currency,
          monthly ? 'monthly' : 'custom_cycle',
          start,
          end != null && start != null && end.isAfter(start) ? end : null,
          _recurrenceRule(row),
          row['income'] == 1 ? 'income' : 'expense',
          row['added_transactions_only'] == 1
              ? 'explicit_only'
              : 'all_matching',
          hasMissingReference ? 'needs_review' : 'ready',
          hasMissingReference ? 1 : 0,
        ],
      );
      if (inserted) insertedFinancialRecords++;
      if (start != null && end != null && end.isAfter(start)) {
        await _statement(
          '''
          INSERT OR IGNORE INTO budget_periods (
            id, budget_id, starts_at, ends_at, amount_atoms, amount_scale,
            currency_code, is_imported
          ) VALUES (?, ?, ?, ?, ?, ?, ?, 1)
          ''',
          [
            _targetId('budget-period', sourceId),
            targetId,
            start,
            end,
            amount.atoms.toString(),
            amount.scale,
            amount.currency,
          ],
        );
      }
      await _publishBudgetMemberships(record, targetId);
    }

    for (final record in _records('category_budget_limits')) {
      final row = record.privatePayload;
      final targetBudget = budgetIds[row['budget_fk']];
      if (targetBudget == null) continue;
      final amount = _amount(row['amount']!, row['wallet_fk']);
      await _statement(
        '''
        INSERT OR IGNORE INTO budget_category_limits (
          id, budget_id, category_id, source_reference, amount_atoms,
          amount_scale, currency_code
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          _targetId('budget-limit', row['category_limit_pk']!),
          targetBudget,
          categoryIds[row['category_fk']],
          categoryIds[row['category_fk']] == null
              ? _locatorHash(row['category_fk'].toString())
              : null,
          amount.atoms.toString(),
          amount.scale,
          amount.currency,
        ],
      );
    }
    for (final record in _records('transactions')) {
      final row = record.privatePayload;
      final attachedBudget = row['shared_reference_budget_pk'];
      if (attachedBudget == null || budgetIds[attachedBudget] == null) continue;
      final transactionId = transactionIds[row['transaction_pk']];
      await _statement(
        '''
        INSERT OR IGNORE INTO budget_transaction_memberships (
          id, budget_id, transaction_id, source_reference, membership,
          reason_code, review_state
        ) VALUES (?, ?, ?, ?, 'include', 'source_explicit', ?)
        ''',
        [
          _targetId(
            'budget-transaction',
            '$attachedBudget\u0000${row['transaction_pk']}',
          ),
          budgetIds[attachedBudget],
          transactionId,
          transactionId == null
              ? _locatorHash(row['transaction_pk'].toString())
              : null,
          transactionId == null ? 'needs_review' : 'ready',
        ],
      );
    }
  }

  Future<void> _publishBudgetMemberships(
    CanonicalCashewRecord record,
    String targetBudget,
  ) async {
    final row = record.privatePayload;
    final budgetSourceId = row['budget_pk']!;
    final accountIncludes = <Object>{
      row['wallet_fk']!,
      ..._jsonList(row['wallet_fks']),
    };
    for (final sourceId in accountIncludes) {
      final target = accountIds[sourceId];
      await _statement(
        '''
        INSERT OR IGNORE INTO budget_account_memberships (
          id, budget_id, account_id, source_reference, membership, review_state
        ) VALUES (?, ?, ?, ?, 'include', ?)
        ''',
        [
          _targetId('budget-account', '$budgetSourceId\u0000$sourceId'),
          targetBudget,
          target,
          target == null ? _locatorHash(sourceId.toString()) : null,
          target == null ? 'missing_reference' : 'ready',
        ],
      );
    }
    await _publishCategoryMembershipList(
      targetBudget,
      budgetSourceId,
      _jsonList(row['category_fks']),
      'include',
    );
    await _publishCategoryMembershipList(
      targetBudget,
      budgetSourceId,
      _jsonList(row['category_fks_exclude']),
      'exclude',
    );
  }

  Future<void> _publishCategoryMembershipList(
    String targetBudget,
    Object budgetSourceId,
    List<Object> sourceIds,
    String membership,
  ) async {
    for (final sourceId in sourceIds) {
      final target = categoryIds[sourceId];
      await _statement(
        '''
        INSERT OR IGNORE INTO budget_category_memberships (
          id, budget_id, category_id, source_reference, membership, review_state
        ) VALUES (?, ?, ?, ?, ?, ?)
        ''',
        [
          _targetId(
            'budget-category',
            '$budgetSourceId\u0000$membership\u0000$sourceId',
          ),
          targetBudget,
          target,
          target == null ? _locatorHash(sourceId.toString()) : null,
          membership,
          target == null ? 'missing_reference' : 'ready',
        ],
      );
    }
  }

  Future<void> _publishRules() async {
    for (final record in _records('associated_titles')) {
      final row = record.privatePayload;
      final categoryId = categoryIds[row['category_fk']];
      if (categoryId == null) continue;
      final exact = row['is_exact_match'] == 1;
      final order = row['order']! as int;
      final targetId = _targetId('rule', row['associated_title_pk']!);
      final inserted = await _insertTarget(
        table: 'categorization_rules',
        id: targetId,
        record: record,
        sql: '''
          INSERT OR IGNORE INTO categorization_rules (
            id, match_target, match_kind, pattern, normalized_pattern,
            category_id, priority, is_active, is_archived
          ) VALUES (?, 'title', ?, ?, ?, ?, ?, ?, ?)
        ''',
        values: [
          targetId,
          exact ? 'exact' : 'contains',
          row['title'],
          _normalize(row['title']! as String),
          categoryId,
          (exact ? 1000000 : 0) - order,
          row['archived'] == 1 ? 0 : 1,
          row['archived'] == 1 ? 1 : 0,
        ],
      );
      if (inserted) insertedFinancialRecords++;
    }
  }

  Future<void> _publishPreservedRows() async {
    const alwaysPreservedTables = {
      'app_settings',
      'delete_logs',
      'scanner_templates',
      'tags',
      'transaction_to_tag_links',
    };
    for (final record in analysis.records) {
      if (!alwaysPreservedTables.contains(record.sourceTable) &&
          record.disposition != CashewDisposition.preservedOnly &&
          record.disposition != CashewDisposition.reviewRequired &&
          record.disposition != CashewDisposition.ignoredSafe) {
        continue;
      }
      final json = _canonicalJson(record.privatePayload);
      final preservedId = _targetId(
        'preserved',
        '${analysis.report.sourceSha256}\u0000${record.sourceToken}',
      );
      final alreadyPreserved = await database
          .customSelect(
            'SELECT 1 FROM import_preserved_payloads WHERE id = ? LIMIT 1',
            variables: [Variable.withString(preservedId)],
            readsFrom: {database.importPreservedPayloads},
          )
          .get();
      await _statement(
        '''
        INSERT OR IGNORE INTO import_preserved_payloads (
          id, import_run_id, source_locator, payload_version, payload_json,
          payload_sha256, reason_code
        ) VALUES (?, ?, ?, 1, ?, ?, ?)
        ''',
        [
          preservedId,
          importRunId,
          _locatorHash(record.sourceToken),
          json,
          sha256.convert(utf8.encode(json)).toString(),
          record.issueCodes.isEmpty
              ? 'source_preserved'
              : record.issueCodes.first,
        ],
      );
      if (alreadyPreserved.isEmpty) insertedPreservedRecords++;
    }
  }

  Future<void> _writeBalances() async {
    for (final entry in accountIds.entries) {
      final sourceId = entry.key;
      final precision = accountPrecisions[sourceId]!;
      final atoms = accountBalances[sourceId]!;
      await _statement(
        'UPDATE accounts SET balance_atoms = ?, balance = ? WHERE id = ?',
        [atoms.toString(), _approximate(atoms, precision), entry.value],
      );
    }
  }

  Future<void> _publishAttachmentLinks(
    CanonicalCashewRecord record,
    String transactionId,
  ) async {
    final note = record.privatePayload['note'];
    if (note is! String || note.isEmpty) return;
    final matches = RegExp(
      r'https?://[^\s<>"'
      ']+',
      caseSensitive: false,
    ).allMatches(note);
    var ordinal = 0;
    for (final match in matches) {
      final url = match.group(0)!;
      if (!url.toLowerCase().contains('drive.google.com')) continue;
      await _statement(
        '''
        INSERT OR IGNORE INTO transaction_attachment_links (
          id, transaction_id, url, link_type, attachment_bytes_migrated
        ) VALUES (?, ?, ?, 'remote_reference', 0)
        ''',
        [
          _targetId(
            'attachment',
            '${record.privatePayload['transaction_pk']}\u0000${ordinal++}',
          ),
          transactionId,
          url,
        ],
      );
    }
  }

  Future<String?> _payeeId(String title) async {
    final normalized = _normalize(title);
    if (normalized.isEmpty) return null;
    final id = _targetId('payee', normalized);
    await _statement(
      '''
      INSERT OR IGNORE INTO payees (
        id, normalized_name, display_name, sync_status
      ) VALUES (?, ?, ?, 'local_only')
      ''',
      [id, normalized, title],
    );
    return id;
  }

  Future<bool> _insertTarget({
    required String table,
    required String id,
    required CanonicalCashewRecord record,
    required String sql,
    required List<Object?> values,
    List<CanonicalCashewRecord>? sourceRecords,
  }) async {
    final before = await _targetExists(table, id);
    await _statement(sql, values);
    final inserted = !before && await _targetExists(table, id);
    if (!inserted) reusedRecords++;
    final targetHash = _payloadHash({
      'target_table': table,
      'target_id': id,
      'source_payload_sha256': _payloadHash(record.privatePayload),
    });
    final records = sourceRecords ?? [record];
    for (final sourceRecord in records) {
      final sourceId = _sourceEntityId(sourceRecord);
      await _statement(
        '''
        INSERT OR IGNORE INTO import_provenance (
          id, import_run_id, source_system, source_fingerprint,
          source_entity_type, source_entity_id, source_payload_sha256,
          target_table, target_id, mapping_role, imported_target_sha256
        ) VALUES (?, ?, 'cashew', ?, ?, ?, ?, ?, ?, 'primary', ?)
        ''',
        [
          _targetId(
            'provenance',
            '${analysis.report.sourceSha256}\u0000'
                '${sourceRecord.sourceTable}\u0000$sourceId\u0000$table\u0000$id',
          ),
          importRunId,
          analysis.report.sourceSha256,
          sourceRecord.sourceTable,
          sourceId,
          _payloadHash(sourceRecord.privatePayload),
          table,
          id,
          targetHash,
        ],
      );
    }
    return inserted;
  }

  Future<bool> _targetExists(String table, String id) async {
    const allowed = {
      'accounts',
      'categories',
      'transactions',
      'transfers',
      'goals',
      'debt_records',
      'budget_definitions',
      'categorization_rules',
    };
    if (!allowed.contains(table)) {
      throw ArgumentError.value(table, 'table');
    }
    final rows = await database
        .customSelect(
          'SELECT 1 FROM $table WHERE id = ? LIMIT 1',
          variables: [Variable.withString(id)],
        )
        .get();
    return rows.isNotEmpty;
  }

  Future<void> _statement(String sql, [List<Object?> parameters = const []]) {
    return database.customStatement(sql, [
      for (final value in parameters)
        if (value is DateTime) value.millisecondsSinceEpoch ~/ 1000 else value,
    ]);
  }

  _ImportedAmount _amount(Object sqliteAmount, Object? walletSourceId) {
    final precision = accountPrecisions[walletSourceId];
    final currency = accountCurrencies[walletSourceId];
    if (precision == null || currency == null) {
      final preserved = CashewDecimal.fromSqlite(sqliteAmount).absolute;
      return _ImportedAmount(
        atoms: preserved.coefficient.abs(),
        scale: preserved.scale,
        currency: 'UNKNOWN',
      );
    }
    final decimal = CashewDecimal.fromSqlite(
      sqliteAmount,
    ).absolute.quantized(precision);
    return _ImportedAmount(
      atoms: decimal.coefficient.abs(),
      scale: precision,
      currency: currency,
    );
  }

  int _objectiveAmountScale(Object sourceId) {
    final objective = _objective(sourceId)!;
    return accountPrecisions[objective.privatePayload['wallet_fk']]!;
  }

  CanonicalCashewRecord? _objective(Object sourceId) {
    return _records('objectives')
        .where((record) => record.privatePayload['objective_pk'] == sourceId)
        .firstOrNull;
  }

  Set<Object> _reviewAccountKeys() {
    final result = <Object>{};
    for (final record in _records('transactions')) {
      if (record.disposition == CashewDisposition.reviewRequired) {
        final wallet = record.privatePayload['wallet_fk'];
        if (wallet != null) result.add(wallet);
      }
    }
    return result;
  }

  Iterable<CanonicalCashewRecord> _records(String table) =>
      analysis.records.where((record) => record.sourceTable == table);

  String _sourceEntityId(CanonicalCashewRecord record) {
    const keys = {
      'app_settings': ['settings_pk'],
      'associated_titles': ['associated_title_pk'],
      'budgets': ['budget_pk'],
      'categories': ['category_pk'],
      'category_budget_limits': ['category_limit_pk'],
      'delete_logs': ['delete_log_pk'],
      'objectives': ['objective_pk'],
      'scanner_templates': ['scanner_template_pk'],
      'tags': ['tag_pk'],
      'transaction_to_tag_links': ['transaction_pk', 'tag_pk'],
      'transactions': ['transaction_pk'],
      'wallets': ['wallet_pk'],
    };
    return (keys[record.sourceTable] ?? const <String>[])
        .map((key) => record.privatePayload[key].toString())
        .join('\u0000');
  }

  String _targetId(String kind, Object sourceId) {
    final digest = sha256.convert(
      utf8.encode('cashew\u0000$kind\u0000$sourceId'),
    );
    return '$kind-${digest.toString().substring(0, 32)}';
  }

  String _id(String kind, String seed) {
    final digest = sha256.convert(
      utf8.encode('$importRunId\u0000$kind\u0000$seed'),
    );
    return '$kind-${digest.toString().substring(0, 32)}';
  }

  String _locatorHash(String source) =>
      sha256.convert(utf8.encode(source)).toString();

  String _payloadHash(Map<String, Object?> payload) =>
      sha256.convert(utf8.encode(_canonicalJson(payload))).toString();

  String _canonicalJson(Object? value) {
    Object? convert(Object? item) {
      if (item is CashewDecimal) return item.toPlainString();
      if (item is CashewAmount) {
        return {
          'raw_decimal': item.rawDecimal.toPlainString(),
          'wallet_precision': item.walletPrecision,
          'at_wallet_precision': item.atWalletPrecision.toPlainString(),
        };
      }
      if (item is DateTime) return item.toUtc().toIso8601String();
      if (item is Map) {
        final entries = item.entries.toList()
          ..sort(
            (left, right) =>
                left.key.toString().compareTo(right.key.toString()),
          );
        return {
          for (final entry in entries)
            entry.key.toString(): convert(entry.value),
        };
      }
      if (item is Iterable) return item.map(convert).toList();
      return item;
    }

    return jsonEncode(convert(value));
  }

  String _disposition(CashewDisposition disposition) => switch (disposition) {
    CashewDisposition.exactImport => 'exact_import',
    CashewDisposition.transformedImport => 'transformed_import',
    CashewDisposition.preservedOnly => 'preserved_only',
    CashewDisposition.reviewRequired => 'review_required',
    CashewDisposition.ignoredSafe => 'ignored_safe',
    CashewDisposition.invalidBlocking => 'invalid_blocking',
  };

  String _severity(CashewIssueSeverity severity) => switch (severity) {
    CashewIssueSeverity.info => 'info',
    CashewIssueSeverity.warning => 'warning',
    CashewIssueSeverity.review => 'review',
    CashewIssueSeverity.blocking => 'blocking',
  };

  String _normalize(String source) =>
      source.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  List<Object> _jsonList(Object? source) {
    if (source == null) return const [];
    final decoded = jsonDecode(source as String);
    return decoded is List ? decoded.whereType<Object>().toList() : const [];
  }

  DateTime? _date(Object? seconds) {
    if (seconds is! int || seconds < 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  String _recurrenceRule(Map<String, Object?> row) {
    final interval = row['period_length'] is int
        ? row['period_length'] as int
        : 1;
    final frequency = switch (row['reoccurrence']) {
      1 => 'DAILY',
      2 => 'WEEKLY',
      3 => 'MONTHLY',
      4 => 'YEARLY',
      _ => 'DAILY',
    };
    return 'FREQ=$frequency;INTERVAL=$interval';
  }
}

class _ImportedAmount {
  const _ImportedAmount({
    required this.atoms,
    required this.scale,
    required this.currency,
  });

  final BigInt atoms;
  final int scale;
  final String currency;

  double get approximate => _approximate(atoms, scale);
}

double _approximate(BigInt atoms, int scale) =>
    double.parse('${atoms.toString()}e-$scale');

class CashewPublicationResult {
  const CashewPublicationResult({
    required this.insertedFinancialRecords,
    required this.preservedRecords,
    required this.reusedRecords,
    required this.accountPartitions,
    required this.reviewAccountPartitions,
  });

  final int insertedFinancialRecords;
  final int preservedRecords;
  final int reusedRecords;
  final int accountPartitions;
  final int reviewAccountPartitions;
}

class CashewPublicationFailure implements Exception {
  const CashewPublicationFailure(this.code);

  final String code;

  @override
  String toString() => 'CashewPublicationFailure($code)';
}

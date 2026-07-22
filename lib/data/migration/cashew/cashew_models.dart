import 'dart:collection';

import 'cashew_decimal.dart';

enum CashewDisposition {
  exactImport,
  transformedImport,
  preservedOnly,
  reviewRequired,
  ignoredSafe,
  invalidBlocking,
}

enum CashewIssueSeverity { info, warning, review, blocking }

abstract final class CashewIssueCodes {
  static const invalidHeader = 'source.invalid_header';
  static const unreadableSource = 'source.unreadable';
  static const unknownSchema = 'schema.unknown_version';
  static const schemaMismatch = 'schema.structure_mismatch';
  static const integrityCheck = 'source.integrity_check';
  static const sourceChanged = 'source.changed_during_read';
  static const invalidPrimaryKey = 'row.invalid_primary_key';
  static const invalidDate = 'value.invalid_date';
  static const legacyDateSentinel = 'value.legacy_date_sentinel';
  static const invalidEnum = 'value.invalid_enum';
  static const invalidJson = 'value.invalid_json';
  static const invalidAmount = 'transaction.invalid_amount';
  static const invalidPrecision = 'currency.invalid_precision';
  static const missingCurrency = 'currency.missing_identifier';
  static const signDirectionMismatch = 'transaction.sign_direction_mismatch';
  static const orphanReference = 'relationship.orphan';
  static const tombstonedReference = 'relationship.tombstoned_parent';
  static const transferSameAccount = 'transfer.same_account';
  static const transferUnequalAmounts = 'transfer.unequal_amounts';
  static const transferNonTransferCategory = 'transfer.non_transfer_category';
  static const transferDirection = 'transfer.direction_mismatch';
  static const transferPaidState = 'transfer.paid_state_mismatch';
  static const transferCrossCurrency = 'transfer.cross_currency';
  static const transferDangling = 'transfer.dangling_reference';
  static const balanceCorrection = 'transaction.balance_correction_review';
  static const recurrencePartial = 'recurrence.partial_definition';
  static const recurrenceMalformedPrediction =
      'recurrence.malformed_prediction_id';
  static const budgetDeletedAccount = 'budget.deleted_account';
  static const objectiveDeletedAccount = 'objective.deleted_account';
  static const goalContributionTotalMismatch =
      'goal.contribution_total_mismatch';
  static const debtPaymentTotalMismatch = 'debt.payment_total_mismatch';
  static const preservedAutomation = 'automation.preserved_for_later';
  static const ambiguousDeleteLog = 'delete_log.ambiguous_type';
  static const attachmentUrlPreserved = 'attachment.url_preserved';
  static const tagLinkInvalid = 'tag.invalid_link';
}

final class CashewIssue {
  const CashewIssue({
    required this.code,
    required this.severity,
    required this.message,
    this.sourceToken,
  });

  final String code;
  final CashewIssueSeverity severity;

  /// A generic, redacted message. It must never contain source values.
  final String message;

  /// Internal row token. This is deliberately omitted from report output.
  final String? sourceToken;
}

final class CanonicalCashewRecord {
  CanonicalCashewRecord({
    required this.sourceTable,
    required this.sourceToken,
    required this.kind,
    required this.disposition,
    required Map<String, Object?> privatePayload,
    Iterable<String> issueCodes = const [],
  }) : privatePayload = UnmodifiableMapView(privatePayload),
       issueCodes = List.unmodifiable(issueCodes);

  final String sourceTable;
  final String sourceToken;
  final String kind;
  final CashewDisposition disposition;

  /// In-memory source payload for the eventual atomic mapper.
  ///
  /// This map may contain sensitive values and must never be serialized into
  /// diagnostics. [toString] is intentionally redacted.
  final Map<String, Object?> privatePayload;
  final List<String> issueCodes;

  @override
  String toString() =>
      'CanonicalCashewRecord(table: $sourceTable, kind: $kind, '
      'disposition: ${disposition.name}, payload: <redacted>)';
}

final class CanonicalCashewRelationship {
  CanonicalCashewRelationship({
    required this.kind,
    required this.fromToken,
    this.toToken,
    required this.disposition,
    Iterable<String> issueCodes = const [],
  }) : issueCodes = List.unmodifiable(issueCodes);

  final String kind;
  final String fromToken;
  final String? toToken;
  final CashewDisposition disposition;
  final List<String> issueCodes;

  @override
  String toString() =>
      'CanonicalCashewRelationship(kind: $kind, '
      'disposition: ${disposition.name}, endpoints: <redacted>)';
}

final class CashewDateBounds {
  const CashewDateBounds({required this.minimumUtc, required this.maximumUtc});

  final DateTime minimumUtc;
  final DateTime maximumUtc;

  Map<String, String> toRedactedJson() => {
    'minimum_utc': minimumUtc.toIso8601String(),
    'maximum_utc': maximumUtc.toIso8601String(),
  };
}

final class CashewReconciliationSummary {
  const CashewReconciliationSummary({
    required this.accountPartitions,
    required this.currencyPartitions,
    required this.zeroDeltaAccountPartitions,
    required this.zeroDeltaCurrencyPartitions,
    required this.signDirectionMismatches,
  });

  final int accountPartitions;
  final int currencyPartitions;
  final int zeroDeltaAccountPartitions;
  final int zeroDeltaCurrencyPartitions;
  final int signDirectionMismatches;

  bool get passed =>
      accountPartitions == zeroDeltaAccountPartitions &&
      currencyPartitions == zeroDeltaCurrencyPartitions &&
      signDirectionMismatches == 0;

  Map<String, Object> toRedactedJson() => {
    'account_partitions': accountPartitions,
    'currency_partitions': currencyPartitions,
    'zero_delta_account_partitions': zeroDeltaAccountPartitions,
    'zero_delta_currency_partitions': zeroDeltaCurrencyPartitions,
    'sign_direction_mismatches': signDirectionMismatches,
    'passed': passed,
  };
}

final class CashewTransferSummary {
  const CashewTransferSummary({
    required this.resolvedPairs,
    required this.sameCurrencyPairs,
    required this.crossCurrencyPairs,
    required this.reviewPairs,
    required this.danglingReferences,
    required this.balanceCorrections,
  });

  final int resolvedPairs;
  final int sameCurrencyPairs;
  final int crossCurrencyPairs;
  final int reviewPairs;
  final int danglingReferences;
  final int balanceCorrections;

  Map<String, int> toRedactedJson() => {
    'resolved_pairs': resolvedPairs,
    'same_currency_pairs': sameCurrencyPairs,
    'cross_currency_pairs': crossCurrencyPairs,
    'review_pairs': reviewPairs,
    'dangling_references': danglingReferences,
    'balance_corrections': balanceCorrections,
  };
}

final class CashewObjectiveEventReconciliationSummary {
  const CashewObjectiveEventReconciliationSummary({
    required this.goalPartitions,
    required this.debtPartitions,
    required this.goalEventRows,
    required this.debtPaymentEventRows,
    required this.zeroDeltaGoalPartitions,
    required this.zeroDeltaDebtPartitions,
    required this.reviewRequiredPartitions,
    required this.mismatchedPartitions,
  });

  final int goalPartitions;
  final int debtPartitions;
  final int goalEventRows;
  final int debtPaymentEventRows;
  final int zeroDeltaGoalPartitions;
  final int zeroDeltaDebtPartitions;
  final int reviewRequiredPartitions;
  final int mismatchedPartitions;

  bool get passed =>
      mismatchedPartitions == 0 &&
      zeroDeltaGoalPartitions +
              zeroDeltaDebtPartitions +
              reviewRequiredPartitions ==
          goalPartitions + debtPartitions;

  Map<String, Object> toRedactedJson() => {
    'goal_partitions': goalPartitions,
    'debt_partitions': debtPartitions,
    'goal_event_rows': goalEventRows,
    'debt_payment_event_rows': debtPaymentEventRows,
    'zero_delta_goal_partitions': zeroDeltaGoalPartitions,
    'zero_delta_debt_partitions': zeroDeltaDebtPartitions,
    'review_required_partitions': reviewRequiredPartitions,
    'mismatched_partitions': mismatchedPartitions,
    'passed': passed,
  };
}

final class CashewDomainSummary {
  const CashewDomainSummary({
    required this.recurringSeries,
    required this.unpaidOccurrences,
    required this.skippedOccurrences,
    required this.objectives,
    required this.objectiveFinancialRows,
    required this.budgets,
    required this.explicitBudgetMemberships,
    required this.categorizationRules,
    required this.tags,
    required this.tagLinks,
    required this.attachmentUrlOccurrences,
  });

  final int recurringSeries;
  final int unpaidOccurrences;
  final int skippedOccurrences;
  final int objectives;
  final int objectiveFinancialRows;
  final int budgets;
  final int explicitBudgetMemberships;
  final int categorizationRules;
  final int tags;
  final int tagLinks;
  final int attachmentUrlOccurrences;

  Map<String, int> toRedactedJson() => {
    'recurring_series': recurringSeries,
    'unpaid_occurrences': unpaidOccurrences,
    'skipped_occurrences': skippedOccurrences,
    'objectives': objectives,
    'objective_financial_rows': objectiveFinancialRows,
    'budgets': budgets,
    'explicit_budget_memberships': explicitBudgetMemberships,
    'categorization_rules': categorizationRules,
    'tags': tags,
    'tag_links': tagLinks,
    'attachment_url_occurrences': attachmentUrlOccurrences,
  };
}

final class CashewDryRunReport {
  CashewDryRunReport({
    required this.sourceSha256,
    required this.schemaVersion,
    required Map<String, int> tableCounts,
    required Map<String, CashewDateBounds> dateBounds,
    required Map<String, Map<String, int>> enumDomains,
    required Map<CashewDisposition, int> recordDispositions,
    required Map<CashewDisposition, int> relationshipDispositions,
    required Map<String, int> issueCounts,
    required this.reconciliation,
    required this.objectiveEvents,
    required this.transfers,
    required this.domains,
    required this.sourceUnchanged,
  }) : tableCounts = UnmodifiableMapView(tableCounts),
       dateBounds = UnmodifiableMapView(dateBounds),
       enumDomains = UnmodifiableMapView(
         enumDomains.map(
           (key, value) => MapEntry(key, UnmodifiableMapView(value)),
         ),
       ),
       recordDispositions = UnmodifiableMapView(recordDispositions),
       relationshipDispositions = UnmodifiableMapView(relationshipDispositions),
       issueCounts = UnmodifiableMapView(issueCounts);

  final String sourceSha256;
  final int? schemaVersion;
  final Map<String, int> tableCounts;
  final Map<String, CashewDateBounds> dateBounds;
  final Map<String, Map<String, int>> enumDomains;
  final Map<CashewDisposition, int> recordDispositions;
  final Map<CashewDisposition, int> relationshipDispositions;
  final Map<String, int> issueCounts;
  final CashewReconciliationSummary reconciliation;
  final CashewObjectiveEventReconciliationSummary objectiveEvents;
  final CashewTransferSummary transfers;
  final CashewDomainSummary domains;
  final bool sourceUnchanged;

  int get sourceRowCount =>
      tableCounts.values.fold(0, (total, value) => total + value);
  int get disposedSourceRowCount =>
      recordDispositions.values.fold(0, (total, value) => total + value);
  bool get everySourceRowDisposed => sourceRowCount == disposedSourceRowCount;
  bool get hasBlockingIssues =>
      (recordDispositions[CashewDisposition.invalidBlocking] ?? 0) > 0 ||
      issueCounts.entries.any(
        (entry) =>
            entry.key.startsWith('source.') ||
            entry.key.startsWith('schema.') ||
            entry.key == CashewIssueCodes.invalidAmount ||
            entry.key == CashewIssueCodes.signDirectionMismatch,
      );

  Map<String, Object?> toRedactedJson() => {
    'source_sha256': sourceSha256,
    'schema_version': schemaVersion,
    'source_unchanged': sourceUnchanged,
    'table_counts': tableCounts,
    'date_bounds': dateBounds.map(
      (key, value) => MapEntry(key, value.toRedactedJson()),
    ),
    'enum_domains': enumDomains,
    'record_dispositions': recordDispositions.map(
      (key, value) => MapEntry(key.name, value),
    ),
    'relationship_dispositions': relationshipDispositions.map(
      (key, value) => MapEntry(key.name, value),
    ),
    'issue_counts': issueCounts,
    'every_source_row_disposed': everySourceRowDisposed,
    'reconciliation': reconciliation.toRedactedJson(),
    'objective_events': objectiveEvents.toRedactedJson(),
    'transfers': transfers.toRedactedJson(),
    'domains': domains.toRedactedJson(),
  };

  @override
  String toString() => toRedactedJson().toString();
}

final class CashewAnalysis {
  CashewAnalysis({
    required Iterable<CanonicalCashewRecord> records,
    required Iterable<CanonicalCashewRelationship> relationships,
    required Iterable<CashewIssue> issues,
    required this.report,
  }) : records = List.unmodifiable(records),
       relationships = List.unmodifiable(relationships),
       issues = List.unmodifiable(issues);

  final List<CanonicalCashewRecord> records;
  final List<CanonicalCashewRelationship> relationships;
  final List<CashewIssue> issues;
  final CashewDryRunReport report;

  @override
  String toString() => report.toString();
}

final class CashewAmount {
  const CashewAmount({required this.rawDecimal, required this.walletPrecision});

  final CashewDecimal rawDecimal;
  final int walletPrecision;

  CashewDecimal get atWalletPrecision => rawDecimal.quantized(walletPrecision);
}

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/data/migration/cashew/cashew_migration.dart';

void main() {
  final sourcePath = Platform.environment['CASHEW_EXPORT_PATH'];

  test(
    'real schema-48 export matches the redacted structural oracle',
    () async {
      final analysis = await const CashewSourceAdapter().analyzeFile(
        File(sourcePath!),
      );
      final report = analysis.report;

      expect(report.schemaVersion, 48);
      expect(report.sourceUnchanged, isTrue);
      expect(report.everySourceRowDisposed, isTrue);
      expect(report.reconciliation.passed, isTrue);
      expect(report.tableCounts['wallets'], 19);
      expect(report.tableCounts['transactions'], 2065);
      expect(report.transfers.resolvedPairs, 269);
      expect(report.transfers.sameCurrencyPairs, 269);
      expect(report.transfers.crossCurrencyPairs, 0);
      expect(report.transfers.reviewPairs, 10);
      expect(report.transfers.danglingReferences, 11);
      expect(report.transfers.balanceCorrections, 65);
      expect(report.domains.recurringSeries, 31);
      expect(report.domains.objectives, 8);
      expect(report.domains.objectiveFinancialRows, 235);
      expect(report.domains.budgets, 5);
      expect(report.domains.explicitBudgetMemberships, 1127);
      expect(report.domains.categorizationRules, 277);
      expect(report.domains.tags, 0);
      expect(report.domains.tagLinks, 0);
      expect(report.domains.attachmentUrlOccurrences, 36);
      expect(
        report.recordDispositions[CashewDisposition.invalidBlocking] ?? 0,
        0,
        reason: report.issueCounts.toString(),
      );

      print(
        'CASHEW_SMOKE PASS '
        'schema=${report.schemaVersion} '
        'accounts=${report.tableCounts['wallets']} '
        'transactions=${report.tableCounts['transactions']} '
        'transfers=${report.transfers.resolvedPairs} '
        'series=${report.domains.recurringSeries} '
        'objectives=${report.domains.objectives} '
        'budgets=${report.domains.budgets} '
        'rules=${report.domains.categorizationRules} '
        'rows=${report.sourceRowCount} '
        'transformed=${report.recordDispositions[CashewDisposition.transformedImport] ?? 0} '
        'preserved=${report.recordDispositions[CashewDisposition.preservedOnly] ?? 0} '
        'review=${report.recordDispositions[CashewDisposition.reviewRequired] ?? 0} '
        'blocking=${report.recordDispositions[CashewDisposition.invalidBlocking] ?? 0} '
        'relations_transformed=${report.relationshipDispositions[CashewDisposition.transformedImport] ?? 0} '
        'relations_preserved=${report.relationshipDispositions[CashewDisposition.preservedOnly] ?? 0} '
        'relations_review=${report.relationshipDispositions[CashewDisposition.reviewRequired] ?? 0} '
        'relations_blocking=${report.relationshipDispositions[CashewDisposition.invalidBlocking] ?? 0} '
        'reconciled=${report.reconciliation.passed} '
        'source_unchanged=${report.sourceUnchanged}',
      );
    },
    skip: sourcePath == null
        ? 'Set CASHEW_EXPORT_PATH to run the private redacted smoke test.'
        : false,
  );
}

// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/data/migration/cashew/cashew_migration.dart';
import 'package:sqlite3/sqlite3.dart';

import 'cashew_fixture_builder.dart';

void main() {
  group('CashewSourceAdapter schema detection', () {
    for (final version in const [46, 47, 48]) {
      test('accepts an exact schema-$version database read-only', () async {
        final fixture = await CashewFixtureBuilder(version).build();
        addTearDown(() => fixture.parent.delete(recursive: true));
        final before = await fixture.stat();

        final analysis = await const CashewSourceAdapter().analyzeFile(fixture);
        final after = await fixture.stat();

        expect(analysis.report.schemaVersion, version);
        expect(analysis.report.sourceUnchanged, isTrue);
        expect(analysis.report.hasBlockingIssues, isFalse);
        expect(
          _copyWithExplicitZeroBlockingDisposition(
            analysis.report,
          ).hasBlockingIssues,
          isFalse,
        );
        expect(analysis.report.everySourceRowDisposed, isTrue);
        expect(
          analysis.report.dateBounds,
          contains('transactions.date_created'),
        );
        expect(
          analysis.report.dateBounds,
          contains('transactions.original_date_due'),
        );
        expect(after.size, before.size);
        expect(after.modified, before.modified);
        expect(
          analysis.report.recordDispositions.values.fold<int>(
            0,
            (total, value) => total + value,
          ),
          analysis.report.sourceRowCount,
        );
      });
    }

    test('rejects an unknown future schema', () async {
      final fixture = await CashewFixtureBuilder(48).build(populate: false);
      addTearDown(() => fixture.parent.delete(recursive: true));
      final database = sqlite3.open(fixture.path);
      database.execute('PRAGMA user_version = 49');
      database.close();

      final analysis = await const CashewSourceAdapter().analyzeFile(fixture);

      expect(analysis.report.schemaVersion, 49);
      expect(
        analysis.report.issueCounts,
        contains(CashewIssueCodes.unknownSchema),
      );
    });

    test('rejects a structural mismatch for a known version', () async {
      final fixture = await CashewFixtureBuilder(48).build(populate: false);
      addTearDown(() => fixture.parent.delete(recursive: true));
      final database = sqlite3.open(fixture.path);
      database.execute('DROP TABLE transaction_to_tag_links');
      database.close();

      final analysis = await const CashewSourceAdapter().analyzeFile(fixture);

      expect(
        analysis.report.issueCounts,
        contains(CashewIssueCodes.schemaMismatch),
      );
    });

    test('rejects a non-SQLite file without exposing its contents', () async {
      final directory = await Directory.systemTemp.createTemp(
        'lootr-invalid-cashew-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final fixture = File('${directory.path}/invalid.sql');
      await fixture.writeAsString('synthetic non-database content');

      final analysis = await const CashewSourceAdapter().analyzeFile(fixture);

      expect(
        analysis.report.issueCounts,
        contains(CashewIssueCodes.invalidHeader),
      );
      expect(analysis.toString(), isNot(contains('synthetic non-database')));
    });
  });

  group('Cashew dry-run classification', () {
    test(
      'classifies transfers and currency partitions conservatively',
      () async {
        final fixture = await CashewFixtureBuilder(48).build();
        addTearDown(() => fixture.parent.delete(recursive: true));

        final analysis = await const CashewSourceAdapter().analyzeFile(fixture);
        final transfers = analysis.report.transfers;

        expect(transfers.resolvedPairs, 5);
        expect(transfers.sameCurrencyPairs, 4);
        expect(transfers.crossCurrencyPairs, 1);
        expect(transfers.reviewPairs, 3);
        expect(transfers.danglingReferences, 1);
        expect(transfers.balanceCorrections, 1);
        expect(analysis.report.reconciliation.accountPartitions, 3);
        expect(analysis.report.reconciliation.currencyPartitions, 2);
        expect(analysis.report.reconciliation.passed, isTrue);
        expect(
          analysis.report.issueCounts[CashewIssueCodes.transferSameAccount],
          2,
        );
        expect(
          analysis.report.issueCounts[CashewIssueCodes.transferUnequalAmounts],
          2,
        );
        expect(
          analysis.report.issueCounts[CashewIssueCodes
              .transferNonTransferCategory],
          2,
        );
        expect(
          analysis.report.issueCounts[CashewIssueCodes.tombstonedReference],
          1,
        );
      },
    );

    test(
      'classifies recurrence, objectives, budgets, rules, tags and URLs',
      () async {
        final fixture = await CashewFixtureBuilder(48).build();
        addTearDown(() => fixture.parent.delete(recursive: true));

        final analysis = await const CashewSourceAdapter().analyzeFile(fixture);
        final domains = analysis.report.domains;

        expect(domains.recurringSeries, 1);
        expect(domains.unpaidOccurrences, 2);
        expect(domains.skippedOccurrences, 1);
        expect(domains.objectives, 1);
        expect(domains.objectiveFinancialRows, 1);
        expect(domains.budgets, 1);
        expect(domains.explicitBudgetMemberships, 1);
        expect(domains.categorizationRules, 1);
        expect(domains.tags, 1);
        expect(domains.tagLinks, 1);
        expect(domains.attachmentUrlOccurrences, 1);
        final skipped = analysis.records.singleWhere(
          (record) =>
              record.privatePayload['transaction_pk'] == 'series::predict::2',
        );
        expect(skipped.privatePayload['canonical_occurrence_state'], 'skipped');
        expect(skipped.privatePayload['canonical_original_due_utc'], isNull);
      },
    );

    test(
      'redacted serialization contains no canonical private values',
      () async {
        final fixture = await CashewFixtureBuilder(48).build();
        addTearDown(() => fixture.parent.delete(recursive: true));

        final analysis = await const CashewSourceAdapter().analyzeFile(fixture);
        final serialized = jsonEncode(analysis.report.toRedactedJson());

        expect(serialized, isNot(contains('Synthetic')));
        expect(serialized, isNot(contains('ordinary')));
        expect(serialized, isNot(contains('drive.google.com')));
        expect(analysis.records.first.toString(), contains('<redacted>'));
        expect(analysis.relationships.first.toString(), contains('<redacted>'));
      },
    );

    test(
      'every valid source row and emitted relationship has a disposition',
      () async {
        final fixture = await CashewFixtureBuilder(48).build();
        addTearDown(() => fixture.parent.delete(recursive: true));

        final analysis = await const CashewSourceAdapter().analyzeFile(fixture);

        expect(analysis.report.everySourceRowDisposed, isTrue);
        expect(
          analysis.records,
          everyElement(
            isA<CanonicalCashewRecord>().having(
              (record) => record.disposition,
              'disposition',
              isNotNull,
            ),
          ),
        );
        expect(
          analysis.relationships,
          everyElement(
            isA<CanonicalCashewRelationship>().having(
              (relationship) => relationship.disposition,
              'disposition',
              isNotNull,
            ),
          ),
        );
      },
    );

    test('blocks invalid enum, JSON and sign/direction data', () async {
      final fixture = await CashewFixtureBuilder(48).build();
      addTearDown(() => fixture.parent.delete(recursive: true));
      final database = sqlite3.open(fixture.path);
      database.execute(
        "UPDATE transactions SET type = 99 WHERE transaction_pk = 'ordinary'",
      );
      database.execute("UPDATE app_settings SET settings_j_s_o_n = 'not-json'");
      database.execute(
        "UPDATE transactions SET amount = 12.34 WHERE transaction_pk = 'ordinary'",
      );
      database.close();

      final analysis = await const CashewSourceAdapter().analyzeFile(fixture);

      expect(
        analysis.report.issueCounts,
        contains(CashewIssueCodes.invalidEnum),
      );
      expect(
        analysis.report.issueCounts,
        contains(CashewIssueCodes.invalidJson),
      );
      expect(
        analysis.report.issueCounts,
        contains(CashewIssueCodes.signDirectionMismatch),
      );
      expect(
        analysis.report.recordDispositions,
        contains(CashewDisposition.invalidBlocking),
      );
    });

    test(
      'blocks invalid account precision and nullable tag link keys',
      () async {
        final fixture = await CashewFixtureBuilder(48).build();
        addTearDown(() => fixture.parent.delete(recursive: true));
        final database = sqlite3.open(fixture.path);
        database.execute(
          "UPDATE wallets SET decimals = 99 WHERE wallet_pk = 'w-2dp'",
        );
        database.execute(
          "INSERT INTO transaction_to_tag_links(transaction_pk,tag_pk) "
          "VALUES (NULL,'tag-1')",
        );
        database.close();

        final analysis = await const CashewSourceAdapter().analyzeFile(fixture);

        expect(
          analysis.report.issueCounts,
          contains(CashewIssueCodes.invalidPrecision),
        );
        expect(
          analysis.report.issueCounts,
          contains(CashewIssueCodes.invalidPrimaryKey),
        );
        expect(
          analysis.report.issueCounts,
          contains(CashewIssueCodes.tagLinkInvalid),
        );
      },
    );
  });
}

CashewDryRunReport _copyWithExplicitZeroBlockingDisposition(
  CashewDryRunReport source,
) {
  return CashewDryRunReport(
    sourceSha256: source.sourceSha256,
    schemaVersion: source.schemaVersion,
    tableCounts: source.tableCounts,
    dateBounds: source.dateBounds,
    enumDomains: source.enumDomains,
    recordDispositions: {
      ...source.recordDispositions,
      CashewDisposition.invalidBlocking: 0,
    },
    relationshipDispositions: source.relationshipDispositions,
    issueCounts: source.issueCounts,
    reconciliation: source.reconciliation,
    transfers: source.transfers,
    domains: source.domains,
    sourceUnchanged: source.sourceUnchanged,
  );
}

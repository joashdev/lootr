// sqlite3 and crypto are already present in the locked dependency graph through
// Drift. The migration slice intentionally does not change pubspec.yaml.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import 'cashew_analyzer.dart';
import 'cashew_models.dart';
import 'cashew_schema.dart';

final class CashewSourceAdapter {
  const CashewSourceAdapter();

  static const _sqliteHeader = <int>[
    0x53,
    0x51,
    0x4c,
    0x69,
    0x74,
    0x65,
    0x20,
    0x66,
    0x6f,
    0x72,
    0x6d,
    0x61,
    0x74,
    0x20,
    0x33,
    0x00,
  ];

  Future<CashewAnalysis> analyzeFile(File sourceFile) async {
    String beforeHash;
    try {
      beforeHash = await _sha256(sourceFile);
    } on Object {
      return _blocked(
        sourceSha256: '<unavailable>',
        code: CashewIssueCodes.unreadableSource,
        message: 'The selected source could not be read.',
      );
    }

    if (!await _hasSqliteHeader(sourceFile)) {
      return _blocked(
        sourceSha256: beforeHash,
        code: CashewIssueCodes.invalidHeader,
        message: 'The selected source is not a SQLite database.',
      );
    }

    Database? database;
    CashewSourceData? sourceData;
    CashewAnalysis? blocked;
    final preflightIssues = <CashewIssue>[];
    try {
      final uri = Uri.file(
        sourceFile.absolute.path,
      ).replace(queryParameters: const {'mode': 'ro', 'immutable': '1'});
      database = sqlite3.open(
        uri.toString(),
        mode: OpenMode.readOnly,
        uri: true,
      );
      database.execute('PRAGMA query_only = ON');
      final queryOnly = _pragmaScalar(database, 'PRAGMA query_only');
      if (queryOnly != 1) {
        blocked = _blocked(
          sourceSha256: beforeHash,
          code: CashewIssueCodes.unreadableSource,
          message: 'The source connection could not be made query-only.',
        );
      } else {
        final userVersion = _pragmaScalar(database, 'PRAGMA user_version');
        if (userVersion is! int || userVersion < 46 || userVersion > 48) {
          blocked = _blocked(
            sourceSha256: beforeHash,
            schemaVersion: userVersion is int ? userVersion : null,
            code: CashewIssueCodes.unknownSchema,
            message: 'This Cashew schema version is not supported.',
          );
        } else {
          final quickCheck = _singleText(database, 'PRAGMA quick_check');
          final integrityCheck = _singleText(
            database,
            'PRAGMA integrity_check',
          );
          if (quickCheck != 'ok' || integrityCheck != 'ok') {
            blocked = _blocked(
              sourceSha256: beforeHash,
              schemaVersion: userVersion,
              code: CashewIssueCodes.integrityCheck,
              message: 'The source database did not pass integrity checks.',
            );
          } else {
            final contract = CashewSchemaContract.forVersion(userVersion);
            final metadata = _readMetadata(database);
            final validation = contract.validate(
              observedTables: metadata.tables,
              observedForeignKeys: metadata.foreignKeys,
              tableDdl: metadata.ddl,
            );
            if (!validation.isValid) {
              blocked = _blocked(
                sourceSha256: beforeHash,
                schemaVersion: userVersion,
                code: CashewIssueCodes.schemaMismatch,
                message:
                    'The database structure does not match its Cashew schema version.',
              );
            } else {
              final rows = <String, List<Map<String, Object?>>>{};
              for (final table in contract.tables.keys) {
                final result = database.select(
                  'SELECT * FROM "${table.replaceAll('"', '""')}"',
                );
                rows[table] = [
                  for (final row in result)
                    {
                      for (final column in result.columnNames)
                        column: row[column],
                    },
                ];
              }
              sourceData = CashewSourceData(
                schemaVersion: userVersion,
                sourceSha256: beforeHash,
                rows: rows,
              );
            }
          }
        }
      }
    } on Object {
      blocked = _blocked(
        sourceSha256: beforeHash,
        code: CashewIssueCodes.unreadableSource,
        message: 'The selected source could not be inspected safely.',
      );
    } finally {
      database?.close();
    }

    String afterHash;
    try {
      afterHash = await _sha256(sourceFile);
    } on Object {
      afterHash = '<unavailable>';
    }
    final unchanged = beforeHash == afterHash;
    if (!unchanged) {
      preflightIssues.add(
        const CashewIssue(
          code: CashewIssueCodes.sourceChanged,
          severity: CashewIssueSeverity.blocking,
          message: 'The source fingerprint changed during inspection.',
        ),
      );
    }
    if (blocked != null) {
      if (unchanged) return blocked;
      return _blocked(
        sourceSha256: beforeHash,
        schemaVersion: blocked.report.schemaVersion,
        code: CashewIssueCodes.sourceChanged,
        message: 'The source fingerprint changed during inspection.',
        sourceUnchanged: false,
      );
    }

    return CashewAnalyzer().analyze(
      sourceData!,
      sourceUnchanged: unchanged,
      preflightIssues: preflightIssues,
    );
  }

  Future<bool> _hasSqliteHeader(File file) async {
    RandomAccessFile? handle;
    try {
      handle = await file.open(mode: FileMode.read);
      final bytes = await handle.read(_sqliteHeader.length);
      if (bytes.length != _sqliteHeader.length) return false;
      for (var i = 0; i < bytes.length; i++) {
        if (bytes[i] != _sqliteHeader[i]) return false;
      }
      return true;
    } on Object {
      return false;
    } finally {
      await handle?.close();
    }
  }

  Future<String> _sha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  Object? _pragmaScalar(Database database, String sql) {
    final rows = database.select(sql);
    if (rows.isEmpty || rows.first.values.isEmpty) return null;
    return rows.first.values.first;
  }

  String? _singleText(Database database, String sql) {
    final value = _pragmaScalar(database, sql);
    return value is String ? value : null;
  }

  _ObservedMetadata _readMetadata(Database database) {
    final tables = <String, List<CashewObservedColumn>>{};
    final ddl = <String, String?>{};
    final tableRows = database.select(
      "SELECT name, sql FROM sqlite_schema "
      "WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    for (final tableRow in tableRows) {
      final table = tableRow['name']! as String;
      ddl[table] = tableRow['sql'] as String?;
      final escaped = table.replaceAll('"', '""');
      tables[table] = [
        for (final row in database.select('PRAGMA table_info("$escaped")'))
          CashewObservedColumn(
            name: row['name']! as String,
            type: (row['type']! as String).toUpperCase(),
            notNull: row['notnull'] == 1,
            primaryKeyPosition: row['pk']! as int,
          ),
      ];
    }

    final foreignKeys = <CashewForeignKeySpec>[];
    for (final table in tables.keys) {
      final escaped = table.replaceAll('"', '""');
      for (final row in database.select(
        'PRAGMA foreign_key_list("$escaped")',
      )) {
        foreignKeys.add(
          CashewForeignKeySpec(
            table,
            row['from']! as String,
            row['table']! as String,
            row['to']! as String,
          ),
        );
      }
    }
    return _ObservedMetadata(
      tables: tables,
      ddl: ddl,
      foreignKeys: foreignKeys,
    );
  }

  CashewAnalysis _blocked({
    required String sourceSha256,
    required String code,
    required String message,
    int? schemaVersion,
    bool sourceUnchanged = true,
  }) {
    final issue = CashewIssue(
      code: code,
      severity: CashewIssueSeverity.blocking,
      message: message,
    );
    return CashewAnalysis(
      records: const [],
      relationships: const [],
      issues: [issue],
      report: CashewDryRunReport(
        sourceSha256: sourceSha256,
        schemaVersion: schemaVersion,
        tableCounts: const {},
        dateBounds: const {},
        enumDomains: const {},
        recordDispositions: const {},
        relationshipDispositions: const {},
        issueCounts: {code: 1},
        reconciliation: const CashewReconciliationSummary(
          accountPartitions: 0,
          currencyPartitions: 0,
          zeroDeltaAccountPartitions: 0,
          zeroDeltaCurrencyPartitions: 0,
          signDirectionMismatches: 0,
        ),
        objectiveEvents: const CashewObjectiveEventReconciliationSummary(
          goalPartitions: 0,
          debtPartitions: 0,
          goalEventRows: 0,
          debtPaymentEventRows: 0,
          zeroDeltaGoalPartitions: 0,
          zeroDeltaDebtPartitions: 0,
          reviewRequiredPartitions: 0,
          mismatchedPartitions: 0,
        ),
        transfers: const CashewTransferSummary(
          resolvedPairs: 0,
          sameCurrencyPairs: 0,
          crossCurrencyPairs: 0,
          reviewPairs: 0,
          danglingReferences: 0,
          balanceCorrections: 0,
        ),
        domains: const CashewDomainSummary(
          recurringSeries: 0,
          unpaidOccurrences: 0,
          skippedOccurrences: 0,
          objectives: 0,
          objectiveFinancialRows: 0,
          budgets: 0,
          explicitBudgetMemberships: 0,
          categorizationRules: 0,
          tags: 0,
          tagLinks: 0,
          attachmentUrlOccurrences: 0,
        ),
        sourceUnchanged: sourceUnchanged,
      ),
    );
  }
}

final class _ObservedMetadata {
  const _ObservedMetadata({
    required this.tables,
    required this.ddl,
    required this.foreignKeys,
  });

  final Map<String, List<CashewObservedColumn>> tables;
  final Map<String, String?> ddl;
  final List<CashewForeignKeySpec> foreignKeys;
}

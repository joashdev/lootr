import 'dart:convert';

import 'cashew_decimal.dart';
import 'cashew_models.dart';
import 'cashew_schema.dart';

final class CashewSourceData {
  CashewSourceData({
    required this.schemaVersion,
    required this.sourceSha256,
    required Map<String, List<Map<String, Object?>>> rows,
  }) : rows = Map<String, List<Map<String, Object?>>>.unmodifiable({
         for (final entry in rows.entries)
           entry.key: List<Map<String, Object?>>.unmodifiable(
             entry.value.map((row) => Map<String, Object?>.unmodifiable(row)),
           ),
       });

  final int schemaVersion;
  final String sourceSha256;
  final Map<String, List<Map<String, Object?>>> rows;
}

final class CashewAnalyzer {
  CashewAnalysis analyze(
    CashewSourceData source, {
    bool sourceUnchanged = true,
    Iterable<CashewIssue> preflightIssues = const [],
  }) {
    final state = _AnalysisState(source);
    state.issues.addAll(preflightIssues);
    state.stageRows();
    state.validateValues();
    state.classifyRelationships();
    state.classifyTransfers();
    state.classifyRecurrence();
    state.classifyAttachments();
    return state.finish(sourceUnchanged: sourceUnchanged);
  }
}

final class _MutableRecord {
  _MutableRecord({
    required this.table,
    required this.token,
    required this.kind,
    required this.row,
    required this.disposition,
  });

  final String table;
  final String token;
  final String kind;
  final Map<String, Object?> row;
  CashewDisposition disposition;
  final Set<String> issueCodes = {};

  void flag(
    String code,
    CashewDisposition next,
    List<CashewIssue> issues, {
    CashewIssueSeverity severity = CashewIssueSeverity.review,
    String message = 'Source data needs review.',
  }) {
    issueCodes.add(code);
    if (_priority(next) > _priority(disposition)) disposition = next;
    issues.add(
      CashewIssue(
        code: code,
        severity: severity,
        message: message,
        sourceToken: token,
      ),
    );
  }

  static int _priority(CashewDisposition value) => switch (value) {
    CashewDisposition.exactImport => 0,
    CashewDisposition.transformedImport => 1,
    CashewDisposition.ignoredSafe => 2,
    CashewDisposition.preservedOnly => 3,
    CashewDisposition.reviewRequired => 4,
    CashewDisposition.invalidBlocking => 5,
  };
}

final class _AnalysisState {
  _AnalysisState(this.source)
    : contract = CashewSchemaContract.forVersion(source.schemaVersion);

  final CashewSourceData source;
  final CashewSchemaContract contract;
  final List<_MutableRecord> records = [];
  final List<CanonicalCashewRelationship> relationships = [];
  final List<CashewIssue> issues = [];
  final Map<String, Map<Object, _MutableRecord>> index = {};
  final Map<String, Map<String, int>> enumDomains = {};
  final Map<String, CashewDateBounds> dateBounds = {};

  var resolvedPairs = 0;
  var sameCurrencyPairs = 0;
  var crossCurrencyPairs = 0;
  var transferReviewPairs = 0;
  var danglingTransfers = 0;
  var balanceCorrections = 0;
  var recurringSeries = 0;
  var unpaidOccurrences = 0;
  var skippedOccurrences = 0;
  var attachmentOccurrences = 0;
  var explicitBudgetMemberships = 0;

  static const _primaryKeys = {
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

  static const _kinds = {
    'app_settings': 'settings_archive',
    'associated_titles': 'categorization_rule',
    'budgets': 'budget',
    'categories': 'category',
    'category_budget_limits': 'budget_category_limit',
    'delete_logs': 'delete_log_provenance',
    'objectives': 'objective',
    'scanner_templates': 'scanner_automation',
    'tags': 'tag',
    'transaction_to_tag_links': 'transaction_tag_link',
    'transactions': 'transaction',
    'wallets': 'account',
  };

  static const _dateFields = {
    'app_settings': ['date_updated'],
    'associated_titles': ['date_created', 'date_time_modified'],
    'budgets': [
      'start_date',
      'end_date',
      'date_created',
      'date_time_modified',
      'shared_date_updated',
    ],
    'categories': ['date_created', 'date_time_modified'],
    'category_budget_limits': ['date_time_modified'],
    'delete_logs': ['date_time_modified'],
    'objectives': ['date_created', 'end_date', 'date_time_modified'],
    'scanner_templates': ['date_created', 'date_time_modified'],
    'tags': ['date_created', 'date_time_modified'],
    'transactions': [
      'date_created',
      'date_time_modified',
      'original_date_due',
      'end_date',
      'shared_date_updated',
    ],
    'wallets': ['date_created', 'date_time_modified'],
  };

  static const _enumFields = {
    'transactions.income': {0, 1},
    'transactions.paid': {0, 1},
    'transactions.skip_paid': {0, 1},
    'transactions.upcoming_transaction_notification': {0, 1},
    'transactions.created_another_future_transaction': {0, 1},
    'transactions.type': {0, 1, 2, 3, 4},
    'transactions.reoccurrence': {0, 1, 2, 3, 4},
    'transactions.method_added': {0, 1, 2, 3, 4},
    'transactions.shared_status': {0, 1, 2},
    'budgets.income': {0, 1},
    'budgets.archived': {0, 1},
    'budgets.added_transactions_only': {0, 1},
    'budgets.pinned': {0, 1},
    'budgets.is_absolute_spending_limit': {0, 1},
    'budgets.reoccurrence': {0, 1, 2, 3, 4},
    'budgets.shared_owner_member': {0, 1},
    'categories.income': {0, 1},
    'categories.method_added': {0, 1, 2, 3, 4},
    'objectives.type': {0, 1},
    'objectives.income': {0, 1},
    'objectives.pinned': {0, 1},
    'objectives.archived': {0, 1},
    'associated_titles.is_exact_match': {0, 1},
    'scanner_templates.ignore': {0, 1},
    'wallets.archived': {0, 1},
    'categories.archived': {0, 1},
    'associated_titles.archived': {0, 1},
    'tags.archived': {0, 1},
  };

  static const _jsonArrayFields = {
    'wallets': ['home_page_widget_display'],
    'transactions': ['budget_fks_exclude'],
    'budgets': [
      'wallet_fks',
      'category_fks',
      'category_fks_exclude',
      'budget_transaction_filters',
      'member_transaction_filters',
      'shared_members',
      'shared_all_members_ever',
    ],
  };

  void stageRows() {
    for (final table in contract.tables.keys) {
      final tableRows = source.rows[table] ?? const [];
      index[table] = {};
      for (var ordinal = 0; ordinal < tableRows.length; ordinal++) {
        final row = Map<String, Object?>.from(tableRows[ordinal]);
        final token = '$table:row:${ordinal + 1}';
        final record = _MutableRecord(
          table: table,
          token: token,
          kind: _kinds[table] ?? table,
          row: row,
          disposition: _initialDisposition(table),
        );
        records.add(record);

        final keys = _primaryKeys[table] ?? const [];
        final values = keys.map((key) => row[key]).toList();
        final invalid = values.any(
          (value) => value == null || (value is String && value.trim().isEmpty),
        );
        if (invalid) {
          record.flag(
            CashewIssueCodes.invalidPrimaryKey,
            CashewDisposition.invalidBlocking,
            issues,
            severity: CashewIssueSeverity.blocking,
            message: 'A source row has an invalid primary key.',
          );
        } else {
          final lookupKey = values.length == 1
              ? values.single!
              : values.join('\u0000');
          if (index[table]!.containsKey(lookupKey)) {
            record.flag(
              CashewIssueCodes.invalidPrimaryKey,
              CashewDisposition.invalidBlocking,
              issues,
              severity: CashewIssueSeverity.blocking,
              message: 'A source table contains a duplicate primary key.',
            );
          } else {
            index[table]![lookupKey] = record;
          }
        }
      }
    }
  }

  CashewDisposition _initialDisposition(String table) => switch (table) {
    'app_settings' ||
    'delete_logs' ||
    'scanner_templates' => CashewDisposition.preservedOnly,
    _ => CashewDisposition.transformedImport,
  };

  void validateValues() {
    _validateDates();
    _validateEnums();
    _validateJson();
    _validateAmounts();
  }

  void _validateDates() {
    for (final entry in _dateFields.entries) {
      final boundsByField = {for (final field in entry.value) field: <int>[]};
      for (final record in _recordsFor(entry.key)) {
        final canonicalDates = <String, DateTime?>{};
        for (final field in entry.value) {
          final value = record.row[field];
          if (value == null) {
            canonicalDates[field] = null;
            continue;
          }
          if (value is! int || value < -62167219200 || value > 4102444800) {
            record.flag(
              CashewIssueCodes.invalidDate,
              CashewDisposition.invalidBlocking,
              issues,
              severity: CashewIssueSeverity.blocking,
              message: 'A source date is not a plausible Unix-second value.',
            );
          } else {
            boundsByField[field]!.add(value);
            if (value < 0) {
              record.flag(
                CashewIssueCodes.legacyDateSentinel,
                CashewDisposition.transformedImport,
                issues,
                severity: CashewIssueSeverity.warning,
                message:
                    'A legacy pre-epoch date sentinel was preserved during decoding.',
              );
            }
            canonicalDates[field] =
                value < 0 ||
                    (field == 'original_date_due' && value == 1713403747)
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    value * 1000,
                    isUtc: true,
                  );
          }
        }
        record.row['canonical_dates_utc'] = canonicalDates;
      }
      for (final fieldEntry in boundsByField.entries) {
        final bounds = fieldEntry.value;
        if (bounds.isEmpty) continue;
        bounds.sort();
        dateBounds['${entry.key}.${fieldEntry.key}'] = CashewDateBounds(
          minimumUtc: DateTime.fromMillisecondsSinceEpoch(
            bounds.first * 1000,
            isUtc: true,
          ),
          maximumUtc: DateTime.fromMillisecondsSinceEpoch(
            bounds.last * 1000,
            isUtc: true,
          ),
        );
      }
    }
  }

  void _validateEnums() {
    for (final entry in _enumFields.entries) {
      final split = entry.key.split('.');
      final table = split[0];
      final field = split[1];
      if (!contract.tables.containsKey(table) ||
          !contract.tables[table]!.any((column) => column.name == field)) {
        continue;
      }
      final domain = <String, int>{};
      for (final record in _recordsFor(table)) {
        final value = record.row[field];
        final label = value?.toString() ?? 'NULL';
        domain[label] = (domain[label] ?? 0) + 1;
        if (value != null && (value is! int || !entry.value.contains(value))) {
          record.flag(
            CashewIssueCodes.invalidEnum,
            CashewDisposition.invalidBlocking,
            issues,
            severity: CashewIssueSeverity.blocking,
            message: 'A persisted enum contains an unknown ordinal.',
          );
        }
      }
      enumDomains[entry.key] = domain;
    }

    final deleteDomain = <String, int>{};
    for (final record in _recordsFor('delete_logs')) {
      final value = record.row['type'];
      final label = value?.toString() ?? 'NULL';
      deleteDomain[label] = (deleteDomain[label] ?? 0) + 1;
      if (value is! int || value < 0 || value > 8) {
        record.flag(
          CashewIssueCodes.invalidEnum,
          CashewDisposition.invalidBlocking,
          issues,
          severity: CashewIssueSeverity.blocking,
          message: 'A delete-log row has an unknown ordinal.',
        );
      } else if (value >= 6) {
        record.flag(
          CashewIssueCodes.ambiguousDeleteLog,
          CashewDisposition.preservedOnly,
          issues,
          severity: CashewIssueSeverity.warning,
          message:
              'A delete-log ordinal is version-ambiguous and was preserved.',
        );
      }
    }
    enumDomains['delete_logs.type'] = deleteDomain;
  }

  void _validateJson() {
    for (final record in _recordsFor('app_settings')) {
      final value = record.row['settings_j_s_o_n'];
      if (!_isJsonOfType(value, expectList: false)) {
        record.flag(
          CashewIssueCodes.invalidJson,
          CashewDisposition.invalidBlocking,
          issues,
          severity: CashewIssueSeverity.blocking,
          message: 'The source settings payload is not a JSON object.',
        );
      }
    }
    for (final entry in _jsonArrayFields.entries) {
      for (final record in _recordsFor(entry.key)) {
        for (final field in entry.value) {
          final value = record.row[field];
          if (value == null) continue;
          final decoded = _decodeJsonList(value);
          if (decoded == null) {
            record.flag(
              CashewIssueCodes.invalidJson,
              CashewDisposition.invalidBlocking,
              issues,
              severity: CashewIssueSeverity.blocking,
              message: 'A source list payload is not a valid JSON array.',
            );
            continue;
          }
          if (field == 'budget_transaction_filters' &&
              decoded.any((item) => item is! int || item < 0 || item > 6)) {
            record.flag(
              CashewIssueCodes.invalidEnum,
              CashewDisposition.invalidBlocking,
              issues,
              severity: CashewIssueSeverity.blocking,
              message: 'A persisted filter list contains an unknown ordinal.',
            );
          } else if (field == 'home_page_widget_display') {
            final maximum = source.schemaVersion >= 48 ? 6 : 4;
            if (decoded.any(
              (item) => item is! int || item < 0 || item > maximum,
            )) {
              record.flag(
                CashewIssueCodes.invalidEnum,
                CashewDisposition.invalidBlocking,
                issues,
                severity: CashewIssueSeverity.blocking,
                message:
                    'A persisted display list contains an unknown ordinal.',
              );
            }
          } else if (field != 'budget_transaction_filters' &&
              decoded.any((item) => item is! String && item is! num)) {
            record.flag(
              CashewIssueCodes.invalidJson,
              CashewDisposition.invalidBlocking,
              issues,
              severity: CashewIssueSeverity.blocking,
              message: 'A source relationship list contains invalid values.',
            );
          }
        }
      }
    }
  }

  bool _isJsonOfType(Object? value, {required bool expectList}) {
    if (value is! String) return false;
    try {
      final decoded = jsonDecode(value);
      return expectList ? decoded is List : decoded is Map<String, dynamic>;
    } on FormatException {
      return false;
    }
  }

  List<Object?>? _decodeJsonList(Object? value) {
    if (value is! String) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is List ? decoded.cast<Object?>() : null;
    } on FormatException {
      return null;
    }
  }

  void _validateAmounts() {
    for (final wallet in _recordsFor('wallets')) {
      final precision = wallet.row['decimals'];
      if (precision is! int || precision < 0 || precision > 18) {
        wallet.flag(
          CashewIssueCodes.invalidPrecision,
          CashewDisposition.invalidBlocking,
          issues,
          severity: CashewIssueSeverity.blocking,
          message: 'An account has an unsupported decimal precision.',
        );
      }
      final currency = wallet.row['currency'];
      if (currency is! String || currency.trim().isEmpty) {
        wallet.flag(
          CashewIssueCodes.missingCurrency,
          CashewDisposition.invalidBlocking,
          issues,
          severity: CashewIssueSeverity.blocking,
          message: 'An account is missing its currency identifier.',
        );
      }
    }
    for (final table in const [
      'transactions',
      'budgets',
      'objectives',
      'category_budget_limits',
    ]) {
      for (final record in _recordsFor(table)) {
        final value = record.row['amount'];
        try {
          final decimal = CashewDecimal.fromSqlite(value!);
          record.row['canonical_amount_decimal'] = decimal;
          if (table == 'transactions') {
            final wallet = index['wallets']?[record.row['wallet_fk']];
            final precision = wallet?.row['decimals'];
            if (precision is int && precision >= 0 && precision <= 18) {
              record.row['canonical_amount'] = CashewAmount(
                rawDecimal: decimal,
                walletPrecision: precision,
              );
            }
            if (decimal.isZero) {
              throw const FormatException('Zero source transaction');
            }
            final income = record.row['income'] == 1;
            if ((income && decimal.isNegative) ||
                (!income && !decimal.isNegative)) {
              record.flag(
                CashewIssueCodes.signDirectionMismatch,
                CashewDisposition.invalidBlocking,
                issues,
                severity: CashewIssueSeverity.blocking,
                message:
                    'A transaction sign disagrees with its direction flag.',
              );
            }
          }
        } on Object {
          record.flag(
            CashewIssueCodes.invalidAmount,
            CashewDisposition.invalidBlocking,
            issues,
            severity: CashewIssueSeverity.blocking,
            message: 'A source amount is not a finite decimal value.',
          );
        }
      }
    }
  }

  void classifyRelationships() {
    final tombstones = <int, Set<Object>>{};
    for (final record in _recordsFor('delete_logs')) {
      final type = record.row['type'];
      final entry = record.row['entry_pk'];
      if (type is int && entry != null) {
        tombstones.putIfAbsent(type, () => {}).add(entry);
        relationships.add(
          CanonicalCashewRelationship(
            kind: 'delete_log_provenance',
            fromToken: record.token,
            disposition: CashewDisposition.preservedOnly,
            issueCodes: type >= 6
                ? const [CashewIssueCodes.ambiguousDeleteLog]
                : const [],
          ),
        );
      }
    }

    _linkAll(
      'associated_titles',
      'category_fk',
      'categories',
      'categorization_rule_category',
      tombstones,
      tombstoneType: 1,
    );
    _linkAll(
      'categories',
      'main_category_pk',
      'categories',
      'category_parent',
      tombstones,
      tombstoneType: 1,
    );
    _linkAll(
      'budgets',
      'wallet_fk',
      'wallets',
      'budget_account',
      tombstones,
      tombstoneType: 0,
      tombstoneIssue: CashewIssueCodes.budgetDeletedAccount,
    );
    _linkAll(
      'category_budget_limits',
      'category_fk',
      'categories',
      'budget_limit_category',
      tombstones,
      tombstoneType: 1,
    );
    _linkAll(
      'category_budget_limits',
      'budget_fk',
      'budgets',
      'budget_limit_budget',
      tombstones,
      tombstoneType: 2,
    );
    _linkAll(
      'category_budget_limits',
      'wallet_fk',
      'wallets',
      'budget_limit_account',
      tombstones,
      tombstoneType: 0,
    );
    _linkAll(
      'objectives',
      'wallet_fk',
      'wallets',
      'objective_account',
      tombstones,
      tombstoneType: 0,
      tombstoneIssue: CashewIssueCodes.objectiveDeletedAccount,
    );
    _linkAll(
      'scanner_templates',
      'default_category_fk',
      'categories',
      'scanner_default_category',
      tombstones,
      tombstoneType: 1,
    );
    _linkAll(
      'scanner_templates',
      'wallet_fk',
      'wallets',
      'scanner_account',
      tombstones,
      tombstoneType: 0,
    );
    _linkAll(
      'transactions',
      'wallet_fk',
      'wallets',
      'transaction_account',
      tombstones,
      tombstoneType: 0,
    );
    _linkAll(
      'transactions',
      'category_fk',
      'categories',
      'transaction_category',
      tombstones,
      tombstoneType: 1,
    );
    _linkAll(
      'transactions',
      'sub_category_fk',
      'categories',
      'transaction_subcategory',
      tombstones,
      tombstoneType: 1,
    );
    _linkAll(
      'transactions',
      'objective_fk',
      'objectives',
      'goal_contribution',
      tombstones,
      tombstoneType: 7,
      ambiguousTombstone: true,
    );
    _linkAll(
      'transactions',
      'objective_loan_fk',
      'objectives',
      'loan_payment',
      tombstones,
      tombstoneType: 7,
      ambiguousTombstone: true,
    );
    _linkAll(
      'transactions',
      'shared_reference_budget_pk',
      'budgets',
      'explicit_budget_membership',
      tombstones,
      tombstoneType: 2,
    );
    explicitBudgetMemberships = relationships
        .where((relation) => relation.kind == 'explicit_budget_membership')
        .length;

    _linkJsonLists(
      table: 'budgets',
      field: 'wallet_fks',
      targetTable: 'wallets',
      kind: 'budget_account_membership',
      tombstones: tombstones,
      tombstoneType: 0,
    );
    _linkJsonLists(
      table: 'budgets',
      field: 'category_fks',
      targetTable: 'categories',
      kind: 'budget_category_membership',
      tombstones: tombstones,
      tombstoneType: 1,
    );
    _linkJsonLists(
      table: 'budgets',
      field: 'category_fks_exclude',
      targetTable: 'categories',
      kind: 'budget_category_exclusion',
      tombstones: tombstones,
      tombstoneType: 1,
    );
    _linkJsonLists(
      table: 'transactions',
      field: 'budget_fks_exclude',
      targetTable: 'budgets',
      kind: 'transaction_budget_exclusion',
      tombstones: tombstones,
      tombstoneType: 2,
    );

    if (source.schemaVersion >= 48) {
      for (final link in _recordsFor('transaction_to_tag_links')) {
        _linkOne(
          link,
          link.row['transaction_pk'],
          'transactions',
          'tag_link_transaction',
          tombstones,
          tombstoneType: 4,
          invalidCode: CashewIssueCodes.tagLinkInvalid,
        );
        _linkOne(
          link,
          link.row['tag_pk'],
          'tags',
          'tag_link_tag',
          tombstones,
          tombstoneType: 8,
          ambiguousTombstone: true,
          invalidCode: CashewIssueCodes.tagLinkInvalid,
        );
      }
    }
  }

  void _linkAll(
    String table,
    String field,
    String targetTable,
    String kind,
    Map<int, Set<Object>> tombstones, {
    required int tombstoneType,
    String? tombstoneIssue,
    bool ambiguousTombstone = false,
  }) {
    for (final record in _recordsFor(table)) {
      _linkOne(
        record,
        record.row[field],
        targetTable,
        kind,
        tombstones,
        tombstoneType: tombstoneType,
        tombstoneIssue: tombstoneIssue,
        ambiguousTombstone: ambiguousTombstone,
      );
    }
  }

  void _linkJsonLists({
    required String table,
    required String field,
    required String targetTable,
    required String kind,
    required Map<int, Set<Object>> tombstones,
    required int tombstoneType,
  }) {
    for (final record in _recordsFor(table)) {
      final raw = record.row[field];
      if (raw is! String) continue;
      Object? decoded;
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        continue;
      }
      if (decoded is! List) continue;
      for (final value in decoded) {
        _linkOne(
          record,
          value?.toString(),
          targetTable,
          kind,
          tombstones,
          tombstoneType: tombstoneType,
        );
      }
    }
  }

  void _linkOne(
    _MutableRecord from,
    Object? targetKey,
    String targetTable,
    String kind,
    Map<int, Set<Object>> tombstones, {
    required int tombstoneType,
    String? tombstoneIssue,
    bool ambiguousTombstone = false,
    String invalidCode = CashewIssueCodes.orphanReference,
  }) {
    if (targetKey == null) {
      if (invalidCode == CashewIssueCodes.tagLinkInvalid) {
        from.flag(
          invalidCode,
          CashewDisposition.invalidBlocking,
          issues,
          severity: CashewIssueSeverity.blocking,
          message: 'A transaction-tag link has a null endpoint.',
        );
        relationships.add(
          CanonicalCashewRelationship(
            kind: kind,
            fromToken: from.token,
            disposition: CashewDisposition.invalidBlocking,
            issueCodes: [invalidCode],
          ),
        );
      }
      return;
    }
    final target = index[targetTable]?[targetKey];
    if (target != null) {
      relationships.add(
        CanonicalCashewRelationship(
          kind: kind,
          fromToken: from.token,
          toToken: target.token,
          disposition: CashewDisposition.transformedImport,
        ),
      );
      return;
    }

    final hasStableTombstone =
        !ambiguousTombstone &&
        (tombstones[tombstoneType]?.contains(targetKey) ?? false);
    final code = hasStableTombstone
        ? (tombstoneIssue ?? CashewIssueCodes.tombstonedReference)
        : invalidCode;
    final disposition = hasStableTombstone
        ? CashewDisposition.reviewRequired
        : CashewDisposition.invalidBlocking;
    from.flag(
      code,
      disposition,
      issues,
      severity: hasStableTombstone
          ? CashewIssueSeverity.review
          : CashewIssueSeverity.blocking,
      message: hasStableTombstone
          ? 'A source relationship references a deleted parent and needs review.'
          : 'A source relationship references a missing parent.',
    );
    relationships.add(
      CanonicalCashewRelationship(
        kind: kind,
        fromToken: from.token,
        disposition: disposition,
        issueCodes: [code],
      ),
    );
  }

  void classifyTransfers() {
    final transactions = _recordsFor('transactions');
    final incoming = <Object>{};
    final processedPairs = <String>{};
    final tombstonedTransactions = <Object>{};
    for (final log in _recordsFor('delete_logs')) {
      if (log.row['type'] == 4 && log.row['entry_pk'] != null) {
        tombstonedTransactions.add(log.row['entry_pk']!);
      }
    }

    for (final transaction in transactions) {
      final pairKey = transaction.row['paired_transaction_fk'];
      if (pairKey == null) continue;
      incoming.add(pairKey);
      final pair = index['transactions']?[pairKey];
      if (pair == null) {
        danglingTransfers++;
        final tombstoned = tombstonedTransactions.contains(pairKey);
        final code = tombstoned
            ? CashewIssueCodes.tombstonedReference
            : CashewIssueCodes.transferDangling;
        final disposition = tombstoned
            ? CashewDisposition.reviewRequired
            : CashewDisposition.invalidBlocking;
        transaction.flag(
          code,
          disposition,
          issues,
          severity: tombstoned
              ? CashewIssueSeverity.review
              : CashewIssueSeverity.blocking,
          message: tombstoned
              ? 'A transfer fragment references a deleted source row.'
              : 'A transfer reference is dangling.',
        );
        relationships.add(
          CanonicalCashewRelationship(
            kind: 'paired_transaction_reference',
            fromToken: transaction.token,
            disposition: disposition,
            issueCodes: [code],
          ),
        );
        continue;
      }

      relationships.add(
        CanonicalCashewRelationship(
          kind: 'paired_transaction_reference',
          fromToken: transaction.token,
          toToken: pair.token,
          disposition: CashewDisposition.transformedImport,
        ),
      );
      final pairIdentity = _orderedPair(transaction.token, pair.token);
      if (!processedPairs.add(pairIdentity)) continue;
      resolvedPairs++;

      final sourceWallet = index['wallets']?[transaction.row['wallet_fk']];
      final targetWallet = index['wallets']?[pair.row['wallet_fk']];
      final codes = <String>[];
      final sourceCurrency = sourceWallet?.row['currency'];
      final targetCurrency = targetWallet?.row['currency'];
      final sameCurrency =
          sourceCurrency != null && sourceCurrency == targetCurrency;
      if (sameCurrency) {
        sameCurrencyPairs++;
      } else {
        crossCurrencyPairs++;
        issues.add(
          CashewIssue(
            code: CashewIssueCodes.transferCrossCurrency,
            severity: CashewIssueSeverity.info,
            message:
                'A cross-currency transfer will retain two currency amounts.',
            sourceToken: transaction.token,
          ),
        );
      }

      if (transaction.row['wallet_fk'] == pair.row['wallet_fk']) {
        codes.add(CashewIssueCodes.transferSameAccount);
      }
      if (transaction.row['income'] == pair.row['income']) {
        codes.add(CashewIssueCodes.transferDirection);
      }
      if (transaction.row['paid'] != pair.row['paid']) {
        codes.add(CashewIssueCodes.transferPaidState);
      }
      if (transaction.row['category_fk'] != '0' ||
          pair.row['category_fk'] != '0') {
        codes.add(CashewIssueCodes.transferNonTransferCategory);
      }
      if (sameCurrency &&
          !_amountsEqualAtWalletPrecision(
            transaction,
            pair,
            sourceWallet,
            targetWallet,
          )) {
        codes.add(CashewIssueCodes.transferUnequalAmounts);
      }

      final disposition = codes.isEmpty
          ? CashewDisposition.transformedImport
          : CashewDisposition.reviewRequired;
      if (codes.isNotEmpty) {
        transferReviewPairs++;
        for (final code in codes) {
          transaction.flag(
            code,
            CashewDisposition.reviewRequired,
            issues,
            message: 'A transfer pair needs review before publication.',
          );
          pair.flag(
            code,
            CashewDisposition.reviewRequired,
            issues,
            message: 'A transfer pair needs review before publication.',
          );
        }
      }
      relationships.add(
        CanonicalCashewRelationship(
          kind: sameCurrency
              ? 'same_currency_transfer'
              : 'cross_currency_transfer',
          fromToken: transaction.token,
          toToken: pair.token,
          disposition: disposition,
          issueCodes: codes,
        ),
      );
    }

    for (final transaction in transactions) {
      if (transaction.row['category_fk'] != '0' ||
          transaction.row['paid'] != 1 ||
          transaction.row['paired_transaction_fk'] != null ||
          incoming.contains(transaction.row['transaction_pk'])) {
        continue;
      }
      balanceCorrections++;
      transaction.flag(
        CashewIssueCodes.balanceCorrection,
        CashewDisposition.reviewRequired,
        issues,
        message: 'An unpaired balance correction needs opening-balance review.',
      );
    }
  }

  bool _amountsEqualAtWalletPrecision(
    _MutableRecord left,
    _MutableRecord right,
    _MutableRecord? leftWallet,
    _MutableRecord? rightWallet,
  ) {
    final leftAmount = left.row['canonical_amount_decimal'];
    final rightAmount = right.row['canonical_amount_decimal'];
    final leftPrecision = leftWallet?.row['decimals'];
    final rightPrecision = rightWallet?.row['decimals'];
    if (leftAmount is! CashewDecimal ||
        rightAmount is! CashewDecimal ||
        leftPrecision is! int ||
        rightPrecision is! int) {
      return false;
    }
    return leftAmount.absolute.quantized(leftPrecision) ==
        rightAmount.absolute.quantized(rightPrecision);
  }

  void classifyRecurrence() {
    final series = <String>{};
    final predictionPattern = RegExp(r'^(.*)::predict::(\d+)$');
    final predictedBases = <String>{};
    for (final transaction in _recordsFor('transactions')) {
      final sourceId = transaction.row['transaction_pk'];
      if (sourceId is String) {
        final prediction = predictionPattern.firstMatch(sourceId);
        if (prediction != null) predictedBases.add(prediction.group(1)!);
      }
    }
    for (final transaction in _recordsFor('transactions')) {
      final period = transaction.row['period_length'];
      final recurrence = transaction.row['reoccurrence'];
      if ((period == null) != (recurrence == null)) {
        transaction.flag(
          CashewIssueCodes.recurrencePartial,
          CashewDisposition.reviewRequired,
          issues,
          message: 'A recurring row has only part of its schedule metadata.',
        );
      }
      if (period != null && recurrence != null) {
        final sourceId = transaction.row['transaction_pk'];
        if (sourceId is String) {
          final prediction = predictionPattern.firstMatch(sourceId);
          if (sourceId.contains('::predict::') && prediction == null) {
            transaction.flag(
              CashewIssueCodes.recurrenceMalformedPrediction,
              CashewDisposition.reviewRequired,
              issues,
              message: 'A recurring prediction identifier is malformed.',
            );
          } else {
            final base = prediction?.group(1) ?? sourceId;
            transaction.row['canonical_series_source_key'] = base;
            transaction.row['canonical_occurrence_number'] = prediction == null
                ? null
                : int.parse(prediction.group(2)!);
            if (prediction != null || predictedBases.contains(base)) {
              series.add(base);
            }
            relationships.add(
              CanonicalCashewRelationship(
                kind: 'recurring_series_occurrence',
                fromToken: transaction.token,
                toToken: prediction == null
                    ? transaction.token
                    : index['transactions']?[base]?.token,
                disposition: CashewDisposition.transformedImport,
              ),
            );
          }
        }
      }
      transaction.row['canonical_occurrence_state'] =
          transaction.row['paid'] == 1
          ? 'paid'
          : (transaction.row['skip_paid'] == 1 ? 'skipped' : 'unpaid');
      final canonicalDates =
          transaction.row['canonical_dates_utc'] as Map<String, DateTime?>?;
      transaction.row['canonical_original_due_utc'] =
          canonicalDates?['original_date_due'];
      transaction.row['canonical_resolved_utc'] = transaction.row['paid'] == 1
          ? (canonicalDates?['date_created'])
          : null;
      if (transaction.row['paid'] == 0) {
        unpaidOccurrences++;
        if (transaction.row['skip_paid'] == 1) skippedOccurrences++;
      }
    }
    recurringSeries = series.length;
  }

  void classifyAttachments() {
    final marker = RegExp('drive\\.google\\.com', caseSensitive: false);
    for (final transaction in _recordsFor('transactions')) {
      final note = transaction.row['note'];
      if (note is! String) continue;
      final matches = marker.allMatches(note).length;
      for (var i = 0; i < matches; i++) {
        attachmentOccurrences++;
        relationships.add(
          CanonicalCashewRelationship(
            kind: 'attachment_url_reference',
            fromToken: transaction.token,
            disposition: CashewDisposition.preservedOnly,
            issueCodes: const [CashewIssueCodes.attachmentUrlPreserved],
          ),
        );
      }
    }
  }

  CashewAnalysis finish({required bool sourceUnchanged}) {
    final canonicalRecords = records
        .map(
          (record) => CanonicalCashewRecord(
            sourceTable: record.table,
            sourceToken: record.token,
            kind: record.kind,
            disposition: record.disposition,
            privatePayload: record.row,
            issueCodes: record.issueCodes,
          ),
        )
        .toList();
    final recordDispositions = _countDispositions(
      canonicalRecords.map((record) => record.disposition),
    );
    final relationshipDispositions = _countDispositions(
      relationships.map((relation) => relation.disposition),
    );
    final issueCounts = <String, int>{};
    for (final issue in issues) {
      issueCounts[issue.code] = (issueCounts[issue.code] ?? 0) + 1;
    }

    final report = CashewDryRunReport(
      sourceSha256: source.sourceSha256,
      schemaVersion: source.schemaVersion,
      tableCounts: {
        for (final entry in source.rows.entries) entry.key: entry.value.length,
      },
      dateBounds: dateBounds,
      enumDomains: enumDomains,
      recordDispositions: recordDispositions,
      relationshipDispositions: relationshipDispositions,
      issueCounts: issueCounts,
      reconciliation: _reconcile(),
      transfers: CashewTransferSummary(
        resolvedPairs: resolvedPairs,
        sameCurrencyPairs: sameCurrencyPairs,
        crossCurrencyPairs: crossCurrencyPairs,
        reviewPairs: transferReviewPairs,
        danglingReferences: danglingTransfers,
        balanceCorrections: balanceCorrections,
      ),
      domains: CashewDomainSummary(
        recurringSeries: recurringSeries,
        unpaidOccurrences: unpaidOccurrences,
        skippedOccurrences: skippedOccurrences,
        objectives: _recordsFor('objectives').length,
        objectiveFinancialRows: _recordsFor('transactions')
            .where(
              (record) =>
                  record.row['objective_fk'] != null ||
                  record.row['objective_loan_fk'] != null,
            )
            .length,
        budgets: _recordsFor('budgets').length,
        explicitBudgetMemberships: explicitBudgetMemberships,
        categorizationRules: _recordsFor('associated_titles').length,
        tags: _recordsFor('tags').length,
        tagLinks: _recordsFor('transaction_to_tag_links').length,
        attachmentUrlOccurrences: attachmentOccurrences,
      ),
      sourceUnchanged: sourceUnchanged,
    );
    return CashewAnalysis(
      records: canonicalRecords,
      relationships: relationships,
      issues: issues,
      report: report,
    );
  }

  CashewReconciliationSummary _reconcile() {
    final wallets = _recordsFor('wallets');
    final transactions = _recordsFor('transactions');
    var zeroAccountPartitions = 0;
    var signMismatches = 0;
    final currencySource = <Object, CashewDecimal>{};
    final currencyProjected = <Object, CashewDecimal>{};

    for (final wallet in wallets) {
      var sourceTotal = CashewDecimal.zero;
      var projectedTotal = CashewDecimal.zero;
      final walletKey = wallet.row['wallet_pk'];
      final precision = wallet.row['decimals'];
      for (final transaction in transactions) {
        if (transaction.row['wallet_fk'] != walletKey ||
            transaction.row['paid'] != 1) {
          continue;
        }
        final amount = transaction.row['canonical_amount_decimal'];
        if (amount is! CashewDecimal) continue;
        sourceTotal += amount;
        final income = transaction.row['income'] == 1;
        if ((income && amount.isNegative) || (!income && !amount.isNegative)) {
          signMismatches++;
        }
        projectedTotal += income ? amount.absolute : amount.absolute.negated;
      }
      if (precision is int &&
          sourceTotal.quantized(precision) ==
              projectedTotal.quantized(precision)) {
        zeroAccountPartitions++;
      }
      final currency = wallet.row['currency'] ?? '<missing>';
      currencySource[currency] =
          (currencySource[currency] ?? CashewDecimal.zero) + sourceTotal;
      currencyProjected[currency] =
          (currencyProjected[currency] ?? CashewDecimal.zero) + projectedTotal;
    }

    var zeroCurrencyPartitions = 0;
    for (final currency in currencySource.keys) {
      if (currencySource[currency] == currencyProjected[currency]) {
        zeroCurrencyPartitions++;
      }
    }
    return CashewReconciliationSummary(
      accountPartitions: wallets.length,
      currencyPartitions: currencySource.length,
      zeroDeltaAccountPartitions: zeroAccountPartitions,
      zeroDeltaCurrencyPartitions: zeroCurrencyPartitions,
      signDirectionMismatches: signMismatches,
    );
  }

  List<_MutableRecord> _recordsFor(String table) =>
      records.where((record) => record.table == table).toList();

  Map<CashewDisposition, int> _countDispositions(
    Iterable<CashewDisposition> values,
  ) {
    final counts = <CashewDisposition, int>{};
    for (final value in values) {
      counts[value] = (counts[value] ?? 0) + 1;
    }
    return counts;
  }

  String _orderedPair(String left, String right) =>
      left.compareTo(right) <= 0 ? '$left|$right' : '$right|$left';
}

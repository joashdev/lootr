import 'dart:collection';

final class CashewColumnSpec {
  const CashewColumnSpec(
    this.name,
    this.type, {
    required this.notNull,
    this.primaryKeyPosition = 0,
  });

  final String name;
  final String type;
  final bool notNull;
  final int primaryKeyPosition;
}

final class CashewForeignKeySpec {
  const CashewForeignKeySpec(
    this.table,
    this.column,
    this.parentTable,
    this.parentColumn,
  );

  final String table;
  final String column;
  final String parentTable;
  final String parentColumn;

  String get signature => '$table:$column>$parentTable:$parentColumn';
}

final class CashewObservedColumn {
  const CashewObservedColumn({
    required this.name,
    required this.type,
    required this.notNull,
    required this.primaryKeyPosition,
  });

  final String name;
  final String type;
  final bool notNull;
  final int primaryKeyPosition;
}

final class CashewSchemaValidation {
  const CashewSchemaValidation(this.problems);

  final List<String> problems;
  bool get isValid => problems.isEmpty;
}

final class CashewSchemaContract {
  CashewSchemaContract._({
    required this.version,
    required Map<String, List<CashewColumnSpec>> tables,
    required Iterable<CashewForeignKeySpec> foreignKeys,
  }) : tables = UnmodifiableMapView(tables),
       foreignKeys = List.unmodifiable(foreignKeys);

  factory CashewSchemaContract.forVersion(int version) {
    if (version != 46 && version != 47 && version != 48) {
      throw ArgumentError.value(version, 'version', 'Unsupported schema');
    }

    final tables = <String, List<CashewColumnSpec>>{
      'app_settings': _appSettings,
      'associated_titles': [
        ..._associatedTitles,
        if (version >= 48) _bool('archived'),
      ],
      'budgets': _budgets,
      'categories': [..._categories, if (version >= 47) _bool('archived')],
      'category_budget_limits': _categoryBudgetLimits,
      'delete_logs': _deleteLogs,
      'objectives': _objectives,
      'scanner_templates': [
        ..._scannerTemplates,
        if (version >= 48) _nullableText('default_title'),
      ],
      'transactions': _transactions,
      'wallets': [
        ..._wallets,
        if (version >= 47) _bool('archived'),
        if (version >= 48) _nullableText('emoji_icon_name'),
      ],
      if (version >= 48) 'tags': _tags,
      if (version >= 48) 'transaction_to_tag_links': _tagLinks,
    };

    return CashewSchemaContract._(
      version: version,
      tables: tables,
      foreignKeys: [..._baseForeignKeys, if (version >= 48) ..._tagForeignKeys],
    );
  }

  final int version;
  final Map<String, List<CashewColumnSpec>> tables;
  final List<CashewForeignKeySpec> foreignKeys;

  CashewSchemaValidation validate({
    required Map<String, List<CashewObservedColumn>> observedTables,
    required Iterable<CashewForeignKeySpec> observedForeignKeys,
    required Map<String, String?> tableDdl,
  }) {
    final problems = <String>[];
    final expectedNames = tables.keys.toSet();
    final observedNames = observedTables.keys.toSet();
    for (final missing in expectedNames.difference(observedNames)) {
      problems.add('missing_table:$missing');
    }
    for (final extra in observedNames.difference(expectedNames)) {
      problems.add('unexpected_table:$extra');
    }

    for (final entry in tables.entries) {
      final observed = observedTables[entry.key];
      if (observed == null) continue;
      final expectedByName = {
        for (final column in entry.value) column.name: column,
      };
      final observedByName = {
        for (final column in observed) column.name: column,
      };
      for (final missing in expectedByName.keys.toSet().difference(
        observedByName.keys.toSet(),
      )) {
        problems.add('missing_column:${entry.key}.$missing');
      }
      for (final extra in observedByName.keys.toSet().difference(
        expectedByName.keys.toSet(),
      )) {
        problems.add('unexpected_column:${entry.key}.$extra');
      }
      for (final expected in entry.value) {
        final actual = observedByName[expected.name];
        if (actual == null) continue;
        if (actual.type.toUpperCase() != expected.type ||
            actual.notNull != expected.notNull ||
            actual.primaryKeyPosition != expected.primaryKeyPosition) {
          problems.add('column_shape:${entry.key}.${expected.name}');
        }
      }
      final ddl = tableDdl[entry.key];
      if (ddl == null ||
          !ddl.trimLeft().toUpperCase().startsWith('CREATE TABLE')) {
        problems.add('missing_ddl:${entry.key}');
      }
    }

    final expectedForeignKeys = foreignKeys.map((key) => key.signature).toSet();
    final actualForeignKeys = observedForeignKeys
        .map((key) => key.signature)
        .toSet();
    for (final missing in expectedForeignKeys.difference(actualForeignKeys)) {
      problems.add('missing_foreign_key:$missing');
    }
    for (final extra in actualForeignKeys.difference(expectedForeignKeys)) {
      problems.add('unexpected_foreign_key:$extra');
    }
    return CashewSchemaValidation(List.unmodifiable(problems));
  }

  static CashewColumnSpec _text(String name, {bool primaryKey = false}) =>
      CashewColumnSpec(
        name,
        'TEXT',
        notNull: true,
        primaryKeyPosition: primaryKey ? 1 : 0,
      );
  static CashewColumnSpec _nullableText(String name) =>
      CashewColumnSpec(name, 'TEXT', notNull: false);
  static CashewColumnSpec _integer(String name, {bool primaryKey = false}) =>
      CashewColumnSpec(
        name,
        'INTEGER',
        notNull: true,
        primaryKeyPosition: primaryKey ? 1 : 0,
      );
  static CashewColumnSpec _nullableInteger(String name) =>
      CashewColumnSpec(name, 'INTEGER', notNull: false);
  static CashewColumnSpec _real(String name) =>
      CashewColumnSpec(name, 'REAL', notNull: true);
  static CashewColumnSpec _bool(String name) => _integer(name);

  static final _appSettings = [
    _integer('settings_pk', primaryKey: true),
    _text('settings_j_s_o_n'),
    _integer('date_updated'),
  ];

  static final _wallets = [
    _text('wallet_pk', primaryKey: true),
    _text('name'),
    _nullableText('colour'),
    _nullableText('icon_name'),
    _integer('date_created'),
    _nullableInteger('date_time_modified'),
    _integer('order'),
    _nullableText('currency'),
    _nullableText('currency_format'),
    _integer('decimals'),
    _nullableText('home_page_widget_display'),
  ];

  static final _transactions = [
    _text('transaction_pk', primaryKey: true),
    _nullableText('paired_transaction_fk'),
    _text('name'),
    _real('amount'),
    _text('note'),
    _text('category_fk'),
    _nullableText('sub_category_fk'),
    _text('wallet_fk'),
    _integer('date_created'),
    _nullableInteger('date_time_modified'),
    _nullableInteger('original_date_due'),
    _bool('income'),
    _nullableInteger('period_length'),
    _nullableInteger('reoccurrence'),
    _nullableInteger('end_date'),
    _nullableInteger('upcoming_transaction_notification'),
    _nullableInteger('type'),
    _bool('paid'),
    _nullableInteger('created_another_future_transaction'),
    _bool('skip_paid'),
    _nullableInteger('method_added'),
    _nullableText('transaction_owner_email'),
    _nullableText('transaction_original_owner_email'),
    _nullableText('shared_key'),
    _nullableText('shared_old_key'),
    _nullableInteger('shared_status'),
    _nullableInteger('shared_date_updated'),
    _nullableText('shared_reference_budget_pk'),
    _nullableText('objective_fk'),
    _nullableText('objective_loan_fk'),
    _nullableText('budget_fks_exclude'),
  ];

  static final _categories = [
    _text('category_pk', primaryKey: true),
    _text('name'),
    _nullableText('colour'),
    _nullableText('icon_name'),
    _nullableText('emoji_icon_name'),
    _integer('date_created'),
    _nullableInteger('date_time_modified'),
    _integer('order'),
    _bool('income'),
    _nullableInteger('method_added'),
    _nullableText('main_category_pk'),
  ];

  static final _categoryBudgetLimits = [
    _text('category_limit_pk', primaryKey: true),
    _text('category_fk'),
    _text('budget_fk'),
    _real('amount'),
    _nullableInteger('date_time_modified'),
    _text('wallet_fk'),
  ];

  static final _associatedTitles = [
    _text('associated_title_pk', primaryKey: true),
    _text('category_fk'),
    _text('title'),
    _integer('date_created'),
    _nullableInteger('date_time_modified'),
    _integer('order'),
    _bool('is_exact_match'),
  ];

  static final _budgets = [
    _text('budget_pk', primaryKey: true),
    _text('name'),
    _real('amount'),
    _nullableText('colour'),
    _integer('start_date'),
    _integer('end_date'),
    _nullableText('wallet_fks'),
    _nullableText('category_fks'),
    _nullableText('category_fks_exclude'),
    _bool('income'),
    _bool('archived'),
    _bool('added_transactions_only'),
    _integer('period_length'),
    _nullableInteger('reoccurrence'),
    _integer('date_created'),
    _nullableInteger('date_time_modified'),
    _bool('pinned'),
    _integer('order'),
    _text('wallet_fk'),
    _nullableText('budget_transaction_filters'),
    _nullableText('member_transaction_filters'),
    _nullableText('shared_key'),
    _nullableInteger('shared_owner_member'),
    _nullableInteger('shared_date_updated'),
    _nullableText('shared_members'),
    _nullableText('shared_all_members_ever'),
    _bool('is_absolute_spending_limit'),
  ];

  static final _deleteLogs = [
    _text('delete_log_pk', primaryKey: true),
    _text('entry_pk'),
    _integer('type'),
    _integer('date_time_modified'),
  ];

  static final _scannerTemplates = [
    _text('scanner_template_pk', primaryKey: true),
    _integer('date_created'),
    _nullableInteger('date_time_modified'),
    _text('template_name'),
    _text('contains'),
    _text('title_transaction_before'),
    _text('title_transaction_after'),
    _text('amount_transaction_before'),
    _text('amount_transaction_after'),
    _text('default_category_fk'),
    _text('wallet_fk'),
    _bool('ignore'),
  ];

  static final _objectives = [
    _text('objective_pk', primaryKey: true),
    _integer('type'),
    _text('name'),
    _real('amount'),
    _integer('order'),
    _nullableText('colour'),
    _integer('date_created'),
    _nullableInteger('end_date'),
    _nullableInteger('date_time_modified'),
    _nullableText('icon_name'),
    _nullableText('emoji_icon_name'),
    _bool('income'),
    _bool('pinned'),
    _bool('archived'),
    _text('wallet_fk'),
  ];

  static final _tags = [
    _integer('date_created'),
    _nullableInteger('date_time_modified'),
    _integer('order'),
    _bool('archived'),
    _text('name'),
    _nullableText('colour'),
    _nullableText('icon_name'),
    _nullableText('emoji_icon_name'),
    _text('tag_pk', primaryKey: true),
  ];

  static final _tagLinks = [
    const CashewColumnSpec(
      'transaction_pk',
      'TEXT',
      notNull: false,
      primaryKeyPosition: 1,
    ),
    const CashewColumnSpec(
      'tag_pk',
      'TEXT',
      notNull: false,
      primaryKeyPosition: 2,
    ),
  ];

  static const _baseForeignKeys = [
    CashewForeignKeySpec(
      'associated_titles',
      'category_fk',
      'categories',
      'category_pk',
    ),
    CashewForeignKeySpec('budgets', 'wallet_fk', 'wallets', 'wallet_pk'),
    CashewForeignKeySpec(
      'categories',
      'main_category_pk',
      'categories',
      'category_pk',
    ),
    CashewForeignKeySpec(
      'category_budget_limits',
      'category_fk',
      'categories',
      'category_pk',
    ),
    CashewForeignKeySpec(
      'category_budget_limits',
      'budget_fk',
      'budgets',
      'budget_pk',
    ),
    CashewForeignKeySpec(
      'category_budget_limits',
      'wallet_fk',
      'wallets',
      'wallet_pk',
    ),
    CashewForeignKeySpec('objectives', 'wallet_fk', 'wallets', 'wallet_pk'),
    CashewForeignKeySpec(
      'scanner_templates',
      'default_category_fk',
      'categories',
      'category_pk',
    ),
    CashewForeignKeySpec(
      'scanner_templates',
      'wallet_fk',
      'wallets',
      'wallet_pk',
    ),
    CashewForeignKeySpec(
      'transactions',
      'objective_loan_fk',
      'objectives',
      'objective_pk',
    ),
    CashewForeignKeySpec(
      'transactions',
      'objective_fk',
      'objectives',
      'objective_pk',
    ),
    CashewForeignKeySpec('transactions', 'wallet_fk', 'wallets', 'wallet_pk'),
    CashewForeignKeySpec(
      'transactions',
      'sub_category_fk',
      'categories',
      'category_pk',
    ),
    CashewForeignKeySpec(
      'transactions',
      'category_fk',
      'categories',
      'category_pk',
    ),
    CashewForeignKeySpec(
      'transactions',
      'paired_transaction_fk',
      'transactions',
      'transaction_pk',
    ),
  ];

  static const _tagForeignKeys = [
    CashewForeignKeySpec(
      'transaction_to_tag_links',
      'tag_pk',
      'tags',
      'tag_pk',
    ),
    CashewForeignKeySpec(
      'transaction_to_tag_links',
      'transaction_pk',
      'transactions',
      'transaction_pk',
    ),
  ];
}

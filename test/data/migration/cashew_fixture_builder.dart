// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

final class CashewFixtureBuilder {
  CashewFixtureBuilder(this.schemaVersion);

  final int schemaVersion;

  Future<File> build({bool populate = true}) async {
    if (schemaVersion < 46 || schemaVersion > 48) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion');
    }
    final directory = await Directory.systemTemp.createTemp(
      'lootr-cashew-fixture-',
    );
    final file = File('${directory.path}/cashew-fixture.sqlite');
    final database = sqlite3.open(file.path);
    try {
      database.execute('PRAGMA user_version = $schemaVersion');
      for (final ddl in _ddl) {
        database.execute(ddl);
      }
      if (populate) _populate(database);
    } finally {
      database.close();
    }
    return file;
  }

  List<String> get _ddl => [
    '''
CREATE TABLE app_settings (
  settings_pk INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  settings_j_s_o_n TEXT NOT NULL,
  date_updated INTEGER NOT NULL
)''',
    '''
CREATE TABLE wallets (
  wallet_pk TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  colour TEXT NULL,
  icon_name TEXT NULL,
  date_created INTEGER NOT NULL,
  date_time_modified INTEGER NULL DEFAULT 1713403747,
  "order" INTEGER NOT NULL,
  currency TEXT NULL,
  currency_format TEXT NULL,
  decimals INTEGER NOT NULL DEFAULT 2,
  home_page_widget_display TEXT NULL DEFAULT NULL
  ${schemaVersion >= 47 ? ', archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1))' : ''}
  ${schemaVersion >= 48 ? ', emoji_icon_name TEXT NULL' : ''}
)''',
    '''
CREATE TABLE categories (
  category_pk TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  colour TEXT NULL,
  icon_name TEXT NULL,
  emoji_icon_name TEXT NULL,
  date_created INTEGER NOT NULL,
  date_time_modified INTEGER NULL DEFAULT 1713403747,
  "order" INTEGER NOT NULL,
  income INTEGER NOT NULL DEFAULT 0 CHECK (income IN (0, 1)),
  method_added INTEGER NULL,
  main_category_pk TEXT NULL DEFAULT NULL REFERENCES categories(category_pk)
  ${schemaVersion >= 47 ? ', archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1))' : ''}
)''',
    '''
CREATE TABLE objectives (
  objective_pk TEXT NOT NULL PRIMARY KEY,
  type INTEGER NOT NULL DEFAULT 0,
  name TEXT NOT NULL,
  amount REAL NOT NULL,
  "order" INTEGER NOT NULL,
  colour TEXT NULL,
  date_created INTEGER NOT NULL,
  end_date INTEGER NULL,
  date_time_modified INTEGER NULL DEFAULT 1713403747,
  icon_name TEXT NULL,
  emoji_icon_name TEXT NULL,
  income INTEGER NOT NULL DEFAULT 0 CHECK (income IN (0, 1)),
  pinned INTEGER NOT NULL DEFAULT 1 CHECK (pinned IN (0, 1)),
  archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1)),
  wallet_fk TEXT NOT NULL DEFAULT '0' REFERENCES wallets(wallet_pk)
)''',
    '''
CREATE TABLE budgets (
  budget_pk TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  amount REAL NOT NULL,
  colour TEXT NULL,
  start_date INTEGER NOT NULL,
  end_date INTEGER NOT NULL,
  wallet_fks TEXT NULL,
  category_fks TEXT NULL,
  category_fks_exclude TEXT NULL,
  income INTEGER NOT NULL DEFAULT 0 CHECK (income IN (0, 1)),
  archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1)),
  added_transactions_only INTEGER NOT NULL DEFAULT 0 CHECK (added_transactions_only IN (0, 1)),
  period_length INTEGER NOT NULL,
  reoccurrence INTEGER NULL,
  date_created INTEGER NOT NULL,
  date_time_modified INTEGER NULL DEFAULT 1713403747,
  pinned INTEGER NOT NULL DEFAULT 0 CHECK (pinned IN (0, 1)),
  "order" INTEGER NOT NULL,
  wallet_fk TEXT NOT NULL DEFAULT '0' REFERENCES wallets(wallet_pk),
  budget_transaction_filters TEXT NULL DEFAULT NULL,
  member_transaction_filters TEXT NULL DEFAULT NULL,
  shared_key TEXT NULL,
  shared_owner_member INTEGER NULL,
  shared_date_updated INTEGER NULL,
  shared_members TEXT NULL,
  shared_all_members_ever TEXT NULL,
  is_absolute_spending_limit INTEGER NOT NULL DEFAULT 0 CHECK (is_absolute_spending_limit IN (0, 1))
)''',
    '''
CREATE TABLE transactions (
  transaction_pk TEXT NOT NULL PRIMARY KEY,
  paired_transaction_fk TEXT NULL DEFAULT NULL REFERENCES transactions(transaction_pk),
  name TEXT NOT NULL,
  amount REAL NOT NULL,
  note TEXT NOT NULL,
  category_fk TEXT NOT NULL REFERENCES categories(category_pk),
  sub_category_fk TEXT NULL DEFAULT NULL REFERENCES categories(category_pk),
  wallet_fk TEXT NOT NULL DEFAULT '0' REFERENCES wallets(wallet_pk),
  date_created INTEGER NOT NULL,
  date_time_modified INTEGER NULL DEFAULT 1713403747,
  original_date_due INTEGER NULL DEFAULT 1713403747,
  income INTEGER NOT NULL DEFAULT 0 CHECK (income IN (0, 1)),
  period_length INTEGER NULL,
  reoccurrence INTEGER NULL,
  end_date INTEGER NULL,
  upcoming_transaction_notification INTEGER NULL DEFAULT 1 CHECK (upcoming_transaction_notification IN (0, 1)),
  type INTEGER NULL,
  paid INTEGER NOT NULL DEFAULT 0 CHECK (paid IN (0, 1)),
  created_another_future_transaction INTEGER NULL DEFAULT 0 CHECK (created_another_future_transaction IN (0, 1)),
  skip_paid INTEGER NOT NULL DEFAULT 0 CHECK (skip_paid IN (0, 1)),
  method_added INTEGER NULL,
  transaction_owner_email TEXT NULL,
  transaction_original_owner_email TEXT NULL,
  shared_key TEXT NULL,
  shared_old_key TEXT NULL,
  shared_status INTEGER NULL,
  shared_date_updated INTEGER NULL,
  shared_reference_budget_pk TEXT NULL,
  objective_fk TEXT NULL REFERENCES objectives(objective_pk),
  objective_loan_fk TEXT NULL REFERENCES objectives(objective_pk),
  budget_fks_exclude TEXT NULL
)''',
    '''
CREATE TABLE category_budget_limits (
  category_limit_pk TEXT NOT NULL PRIMARY KEY,
  category_fk TEXT NOT NULL REFERENCES categories(category_pk),
  budget_fk TEXT NOT NULL REFERENCES budgets(budget_pk),
  amount REAL NOT NULL,
  date_time_modified INTEGER NULL DEFAULT 1713403747,
  wallet_fk TEXT NOT NULL DEFAULT '0' REFERENCES wallets(wallet_pk)
)''',
    '''
CREATE TABLE associated_titles (
  associated_title_pk TEXT NOT NULL PRIMARY KEY,
  category_fk TEXT NOT NULL REFERENCES categories(category_pk),
  title TEXT NOT NULL,
  date_created INTEGER NOT NULL,
  date_time_modified INTEGER NULL DEFAULT 1713403747,
  "order" INTEGER NOT NULL,
  is_exact_match INTEGER NOT NULL DEFAULT 0 CHECK (is_exact_match IN (0, 1))
  ${schemaVersion >= 48 ? ', archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1))' : ''}
)''',
    '''
CREATE TABLE scanner_templates (
  scanner_template_pk TEXT NOT NULL PRIMARY KEY,
  date_created INTEGER NOT NULL,
  date_time_modified INTEGER NULL DEFAULT 1713403747,
  template_name TEXT NOT NULL,
  contains TEXT NOT NULL,
  title_transaction_before TEXT NOT NULL,
  title_transaction_after TEXT NOT NULL,
  amount_transaction_before TEXT NOT NULL,
  amount_transaction_after TEXT NOT NULL,
  default_category_fk TEXT NOT NULL REFERENCES categories(category_pk),
  wallet_fk TEXT NOT NULL DEFAULT '0' REFERENCES wallets(wallet_pk),
  ignore INTEGER NOT NULL DEFAULT 0 CHECK (ignore IN (0, 1))
  ${schemaVersion >= 48 ? ', default_title TEXT NULL DEFAULT NULL' : ''}
)''',
    '''
CREATE TABLE delete_logs (
  delete_log_pk TEXT NOT NULL PRIMARY KEY,
  entry_pk TEXT NOT NULL,
  type INTEGER NOT NULL,
  date_time_modified INTEGER NOT NULL DEFAULT 1713403747
)''',
    if (schemaVersion >= 48)
      '''
CREATE TABLE tags (
  date_created INTEGER NOT NULL,
  date_time_modified INTEGER NULL,
  "order" INTEGER NOT NULL,
  archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1)),
  name TEXT NOT NULL,
  colour TEXT NULL,
  icon_name TEXT NULL,
  emoji_icon_name TEXT NULL,
  tag_pk TEXT NOT NULL PRIMARY KEY
)''',
    if (schemaVersion >= 48)
      '''
CREATE TABLE transaction_to_tag_links (
  transaction_pk TEXT NULL REFERENCES transactions(transaction_pk),
  tag_pk TEXT NULL REFERENCES tags(tag_pk),
  PRIMARY KEY (transaction_pk, tag_pk)
)''',
  ];

  void _populate(Database database) {
    const now = 1767225600;
    database.execute(
      "INSERT INTO app_settings(settings_j_s_o_n,date_updated) VALUES ('{}',$now)",
    );
    for (final wallet in const [
      ['w-2dp', 'Synthetic account A', 'XAA', 2],
      ['w-4dp', 'Synthetic account B', 'XAA', 4],
      ['w-12dp', 'Synthetic account C', 'XBB', 12],
    ]) {
      database.execute(
        '''
INSERT INTO wallets(
  wallet_pk,name,colour,icon_name,date_created,date_time_modified,"order",
  currency,currency_format,decimals,home_page_widget_display
  ${schemaVersion >= 47 ? ',archived' : ''}
  ${schemaVersion >= 48 ? ',emoji_icon_name' : ''}
) VALUES (?,?,?,?,?,?,?,?,?,?,?
  ${schemaVersion >= 47 ? ',?' : ''}
  ${schemaVersion >= 48 ? ',?' : ''}
)''',
        [
          wallet[0],
          wallet[1],
          null,
          null,
          now,
          now,
          0,
          wallet[2],
          null,
          wallet[3],
          '[]',
          if (schemaVersion >= 47) 0,
          if (schemaVersion >= 48) null,
        ],
      );
    }

    for (final category in const [
      ['0', 'Synthetic correction', 0],
      ['expense', 'Synthetic expense', 0],
      ['income', 'Synthetic income', 1],
    ]) {
      database.execute(
        '''
INSERT INTO categories(
  category_pk,name,colour,icon_name,emoji_icon_name,date_created,
  date_time_modified,"order",income,method_added,main_category_pk
  ${schemaVersion >= 47 ? ',archived' : ''}
) VALUES (?,?,?,?,?,?,?,?,?,?,?
  ${schemaVersion >= 47 ? ',?' : ''}
)''',
        [
          category[0],
          category[1],
          null,
          null,
          null,
          now,
          category[0] == '0' ? -62167161832 : now,
          0,
          category[2],
          null,
          null,
          if (schemaVersion >= 47) 0,
        ],
      );
    }

    database.execute(
      '''
INSERT INTO objectives(
  objective_pk,type,name,amount,"order",colour,date_created,end_date,
  date_time_modified,icon_name,emoji_icon_name,income,pinned,archived,wallet_fk
) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
      [
        'goal-1',
        0,
        'Synthetic objective',
        100.0,
        0,
        null,
        now,
        null,
        now,
        null,
        null,
        0,
        1,
        0,
        'w-2dp',
      ],
    );
    database.execute(
      '''
INSERT INTO budgets(
  budget_pk,name,amount,colour,start_date,end_date,wallet_fks,category_fks,
  category_fks_exclude,income,archived,added_transactions_only,period_length,
  reoccurrence,date_created,date_time_modified,pinned,"order",wallet_fk,
  budget_transaction_filters,member_transaction_filters,shared_key,
  shared_owner_member,shared_date_updated,shared_members,
  shared_all_members_ever,is_absolute_spending_limit
) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
      [
        'budget-1',
        'Synthetic budget',
        50.0,
        null,
        now,
        now + 2592000,
        null,
        null,
        null,
        0,
        0,
        1,
        1,
        3,
        now,
        now,
        1,
        0,
        'w-2dp',
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        0,
      ],
    );

    _insertTransaction(
      database,
      id: 'ordinary',
      amount: -12.34,
      category: 'expense',
      wallet: 'w-2dp',
      note: 'Synthetic note',
      sharedBudget: 'budget-1',
      objective: 'goal-1',
    );
    _insertTransaction(
      database,
      id: 'pair-a',
      pair: 'pair-b',
      amount: -5.0,
      category: '0',
      wallet: 'w-2dp',
    );
    _insertTransaction(
      database,
      id: 'pair-b',
      amount: 5.0,
      income: 1,
      category: '0',
      wallet: 'w-4dp',
    );
    _insertTransaction(
      database,
      id: 'cross-a',
      pair: 'cross-b',
      amount: -1.0,
      category: '0',
      wallet: 'w-2dp',
    );
    _insertTransaction(
      database,
      id: 'cross-b',
      amount: 0.5,
      income: 1,
      category: '0',
      wallet: 'w-12dp',
    );
    _insertTransaction(
      database,
      id: 'same-a',
      pair: 'same-b',
      amount: -2.0,
      category: '0',
      wallet: 'w-2dp',
    );
    _insertTransaction(
      database,
      id: 'same-b',
      amount: 2.0,
      income: 1,
      category: '0',
      wallet: 'w-2dp',
    );
    _insertTransaction(
      database,
      id: 'unequal-a',
      pair: 'unequal-b',
      amount: -3.0,
      category: '0',
      wallet: 'w-2dp',
    );
    _insertTransaction(
      database,
      id: 'unequal-b',
      amount: 3.01,
      income: 1,
      category: '0',
      wallet: 'w-4dp',
    );
    _insertTransaction(
      database,
      id: 'noncategory-a',
      pair: 'noncategory-b',
      amount: -4.0,
      category: 'expense',
      wallet: 'w-2dp',
    );
    _insertTransaction(
      database,
      id: 'noncategory-b',
      amount: 4.0,
      income: 1,
      category: 'income',
      wallet: 'w-4dp',
    );
    _insertTransaction(
      database,
      id: 'dangling',
      pair: 'deleted-transaction',
      amount: -1.0,
      category: '0',
      wallet: 'w-2dp',
    );
    _insertTransaction(
      database,
      id: 'correction',
      amount: 1.25,
      income: 1,
      category: '0',
      wallet: 'w-2dp',
    );
    _insertTransaction(
      database,
      id: 'series',
      amount: -0.0001,
      category: 'expense',
      wallet: 'w-4dp',
      type: 2,
      period: 1,
      recurrence: 3,
    );
    _insertTransaction(
      database,
      id: 'series::predict::1',
      amount: -0.0001,
      category: 'expense',
      wallet: 'w-4dp',
      type: 2,
      period: 1,
      recurrence: 3,
      paid: 0,
    );
    _insertTransaction(
      database,
      id: 'series::predict::2',
      amount: -0.0001,
      category: 'expense',
      wallet: 'w-4dp',
      type: 2,
      period: 1,
      recurrence: 3,
      paid: 0,
      skipped: 1,
    );
    _insertTransaction(
      database,
      id: 'attachment',
      amount: -1.0,
      category: 'expense',
      wallet: 'w-2dp',
      note: 'Synthetic reference https://drive.google.com/synthetic-only',
    );

    database.execute(
      '''
INSERT INTO associated_titles(
  associated_title_pk,category_fk,title,date_created,date_time_modified,"order",
  is_exact_match ${schemaVersion >= 48 ? ',archived' : ''}
) VALUES (?,?,?,?,?,?,? ${schemaVersion >= 48 ? ',?' : ''})''',
      [
        'rule-1',
        'expense',
        'Synthetic rule',
        now,
        now,
        0,
        0,
        if (schemaVersion >= 48) 0,
      ],
    );
    database.execute(
      '''
INSERT INTO delete_logs(delete_log_pk,entry_pk,type,date_time_modified)
VALUES (?,?,?,?)''',
      ['delete-1', 'deleted-transaction', 4, now],
    );

    if (schemaVersion >= 48) {
      database.execute(
        '''
INSERT INTO tags(
  date_created,date_time_modified,"order",archived,name,colour,icon_name,
  emoji_icon_name,tag_pk
) VALUES (?,?,?,?,?,?,?,?,?)''',
        [now, now, 0, 0, 'Synthetic tag', null, null, null, 'tag-1'],
      );
      database.execute(
        '''
INSERT INTO transaction_to_tag_links(transaction_pk,tag_pk) VALUES (?,?)''',
        ['ordinary', 'tag-1'],
      );
    }
  }

  void _insertTransaction(
    Database database, {
    required String id,
    String? pair,
    required double amount,
    int income = 0,
    required String category,
    required String wallet,
    String note = '',
    String? sharedBudget,
    String? objective,
    int? type,
    int? period,
    int? recurrence,
    int paid = 1,
    int skipped = 0,
  }) {
    const now = 1767225600;
    database.execute(
      '''
INSERT INTO transactions(
  transaction_pk,paired_transaction_fk,name,amount,note,category_fk,
  sub_category_fk,wallet_fk,date_created,date_time_modified,original_date_due,
  income,period_length,reoccurrence,end_date,upcoming_transaction_notification,
  type,paid,created_another_future_transaction,skip_paid,method_added,
  transaction_owner_email,transaction_original_owner_email,shared_key,
  shared_old_key,shared_status,shared_date_updated,shared_reference_budget_pk,
  objective_fk,objective_loan_fk,budget_fks_exclude
) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
      [
        id,
        pair,
        'Synthetic transaction',
        amount,
        note,
        category,
        null,
        wallet,
        now,
        now,
        1713403747,
        income,
        period,
        recurrence,
        null,
        1,
        type,
        paid,
        0,
        skipped,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        sharedBudget,
        objective,
        null,
        null,
      ],
    );
  }
}
